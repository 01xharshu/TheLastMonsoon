"""Check clean imports and startup in a disposable copy; retain no test output.
Usage: python3 tools/maintenance/check_game.py [--godot /path/to/godot]
"""
from pathlib import Path
import argparse
import ast
import collections
import os
import shutil
import signal
import subprocess
import tempfile
import sys
import time

ROOT = Path(__file__).resolve().parents[2]


def stop_process(process):
    if process.poll() is not None:
        return
    if sys.platform == 'win32':
        subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    else:
        os.killpg(process.pid, signal.SIGKILL)


def run_check(binary, project, directory, label, args, timeout, native=False, compatibility=False):
    started = time.monotonic()
    display = ['--resolution', '1280x720', '--position', '40,60'] if native else ['--headless']
    if native and compatibility:
        display += ['--rendering-method', 'gl_compatibility', '--rendering-driver', 'opengl3']
    elif native and sys.platform == 'darwin':
        display += ['--rendering-driver', 'metal']
    # Match normal native game output. Verbose Metal logging additionally emits
    # lossless RGB8 compatibility conversions; actual errors/leaks still report.
    effective_args = [arg for arg in args if arg != '--verbose'] if native else args
    command = [binary, *display, '--path', str(project), '--log-file', str(directory / (label + '.log')), *effective_args]
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                               start_new_session=sys.platform != 'win32',
                               creationflags=subprocess.CREATE_NEW_PROCESS_GROUP if sys.platform == 'win32' else 0)
    timed_out = False
    try:
        output, _ = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        timed_out = True
        stop_process(process)
        output, _ = process.communicate()
    except BaseException:
        stop_process(process)
        process.wait()
        raise
    lines = output.splitlines()
    diagnostics = collections.Counter(line.strip() for line in lines if line.startswith(('ERROR:', 'SCRIPT ERROR:', 'SHADER ERROR:', 'WARNING:')))
    print(label, 'TIMEOUT' if timed_out else f'exit={process.returncode}', f'seconds={time.monotonic() - started:.1f}', flush=True)
    for message, count in diagnostics.items():
        print(f'  {count} × {message}', flush=True)
        index = next(i for i, line in enumerate(lines) if line.strip() == message)
        print('\n'.join(lines[index + 1:index + 6]), flush=True)
    if process.returncode not in (0, None) and not diagnostics:
        print('\n'.join(lines[-20:]), flush=True)
    for line in lines:
        if line.startswith(('SURYAGARH READY', 'SAFE TANGENTS', 'Leaked instance:', 'GAME SMOKE', 'SMOKE scene', 'HUMAN CACHE', 'COACHMAN CLEARANCE', 'PASS mobile', 'MAIN SKY', 'CITY_POPULATION_RESULT', 'DEV INQUIRY:', 'ARJUN MOTION', 'GAME ERROR ROUTE', 'LIVE WEAPON', 'STARTUP INTEGRATION', 'CODE AUDIT')):
            print(line, flush=True)
    return not timed_out and process.returncode == 0 and not diagnostics


def user_data_directory(name):
    if sys.platform == 'darwin':
        return Path.home() / 'Library/Application Support' / name
    if sys.platform == 'win32':
        return Path(os.environ['APPDATA']) / name
    return Path(os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local/share'))) / name


def copy_stable_file(source, destination):
    # Exporters and other chats may still be writing GLBs, textures or scripts.
    # Reject a torn file instead of treating its importer crash as a game defect.
    for attempt in range(3):
        before = os.stat(source)
        shutil.copy2(source, destination)
        after = os.stat(source)
        if (before.st_size, before.st_mtime_ns) == (after.st_size, after.st_mtime_ns):
            return destination
    raise RuntimeError('Source changed while copying: ' + str(source))


def check_python_syntax():
    checked = 0
    failed = False
    for folder, directories, files in os.walk(ROOT):
        directories[:] = [name for name in directories if name not in
                          {'.git', '.godot', 'node_modules', '.next', '__pycache__', '.venv'}]
        for name in files:
            if not name.endswith('.py'):
                continue
            source = Path(folder) / name
            checked += 1
            try:
                ast.parse(source.read_text(encoding='utf-8'), filename=str(source))
            except (SyntaxError, UnicodeError) as error:
                failed = True
                print('PYTHON ERROR', source.relative_to(ROOT), error, flush=True)
    print('PYTHON', 'FAIL' if failed else 'PASS', f'files={checked}', flush=True)
    return not failed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=shutil.which('godot') or shutil.which('godot4') or
                        ('/Applications/Godot.app/Contents/MacOS/Godot' if sys.platform == 'darwin' else 'godot'))
    parser.add_argument('--pack-only', action='store_true', help='Run import and isolated pack checks after source smoke has already passed.')
    parser.add_argument('--packed', action='store_true', help='Also check the exported resource pack without access to source files.')
    parser.add_argument('--native', action='store_true', help='Also render the menu and world with Metal; no captures are made.')
    parser.add_argument('--integration', action='store_true', help='Also check recent input, animation, story, sky, population and normal-intro integration.')
    parser.add_argument('--compatibility', action='store_true', help='Use OpenGL compatibility for native checks; does not certify Metal/Vulkan.')
    args = parser.parse_args()
    if not check_python_syntax():
        return 1
    if args.pack_only: args.packed = True
    passed = True
    with tempfile.TemporaryDirectory(prefix='tlm-game-check-') as tmp:
        directory = Path(tmp)
        project = directory / 'project'
        shutil.copytree(ROOT, project, copy_function=copy_stable_file,
                        ignore=shutil.ignore_patterns('.git', '.godot', 'WorkingAssets', '__pycache__', 'node_modules', '.next'))
        config = project / 'project.godot'
        config.write_text(config.read_text().replace('[application]', '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir="' + directory.name + '"'))
        print('Disposable project prepared; importing', flush=True)
        checks = [
            ('IMPORT', ['--import'], 240),
            ('CODE', ['--script', 'res://tools/maintenance/validate_code.gd'], 120),
            ('TANGENTS', ['--script', 'res://tools/assets/validate_safe_tangents.gd'], 90),
            ('HUMANS', ['--script', 'res://tools/characters/validate_human_scene_cache.gd'], 45),
            ('CLEARANCE', ['--script', 'res://tools/horses/validate_coachman_nearest.gd'], 45),
            ('MENU', ['--verbose', '--fixed-fps', '60', '--script', 'res://tools/maintenance/smoke_game.gd'], 45),
            ('WORLD', ['--verbose', '--fixed-fps', '60', '--script', 'res://tools/maintenance/smoke_game.gd', '--', '--world'], 240),
        ]
        native_labels = {'CODE', 'MENU', 'WORLD', 'MAIN_SKY', 'CITY_POPULATION', 'INTRO_ROUTE'}
        if args.integration:
            for label, script, timeout in [
                ('MOBILE', 'tools/world/validate_mobile_touch.gd', 45),
                ('MOTION_TREE', 'tools/characters/validate_arjun_motion_tree.gd', 90),
                ('DEV_INQUIRY', 'tools/world/validate_dev_inquiry.gd', 180),
                ('MAIN_SKY', 'tools/world/validate_main_sky_integration.gd', 180),
                ('CITY_POPULATION', 'tools/world/validate_city_route_population.gd', 240),
                ('INTRO_ROUTE', 'tools/world/validate_game_error_route.gd', 300),
            ]:
                # Heavy headless scenes cannot sustain 60 wall-clock frames here.
                # A 20 Hz process step still advances the normal physics ticks;
                # avoid spending the timeout simulating only part of the intro.
                fixed_fps = '20' if not args.native and label in {'CITY_POPULATION', 'INTRO_ROUTE'} else '60'
                checks.append((label, ['--fixed-fps', fixed_fps, '--script', 'res://' + script], timeout))
        if args.pack_only:
            checks = checks[:1]
        try:
            for label, command, timeout in checks:
                ok = run_check(args.godot, project, directory, label, command, timeout,
                               native=args.native and label in native_labels, compatibility=args.compatibility)
                passed = passed and ok
                if label == 'IMPORT' and not ok:
                    break
            if passed and args.packed:
                preset = project / 'export_presets.cfg'
                platform = {'darwin': 'macOS', 'win32': 'Windows Desktop'}.get(sys.platform, 'Linux')
                preset.write_text('[preset.0]\nname="Disposable check"\nplatform="' + platform + '"\nrunnable=true\nexport_filter="all_resources"\ninclude_filter=""\nexclude_filter="WorkingAssets/*,docs/*"\nexport_path=""\nscript_export_mode=1\n[preset.0.options]\napplication/bundle_identifier="org.thelastmonsoon.disposable"\n')
                pack = directory / 'game.pck'
                ok = run_check(args.godot, project, directory, 'EXPORT', ['--export-pack', 'Disposable check', str(pack)], 120)
                passed = passed and ok
                if ok:
                    isolated = directory / 'packed_run'
                    isolated.mkdir()
                    ok = run_check(args.godot, isolated, directory, 'PACKED_WORLD', ['--main-pack', str(pack), '--fixed-fps', '60', '--script', 'res://tools/maintenance/smoke_game.gd', '--', '--world'], 240)
                    passed = passed and ok
        finally:
            data_directory = user_data_directory(directory.name)
            assert data_directory.name.startswith('tlm-game-check-')
            shutil.rmtree(data_directory, ignore_errors=True)
    print('All temporary projects, caches, user data and logs deleted.', flush=True)
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
