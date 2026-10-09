"""Check clean imports and startup in a disposable copy; retain no test output.
Usage: python3 tools/maintenance/check_game.py [--godot /path/to/godot]
"""
from pathlib import Path
import argparse
import collections
import os
import shutil
import signal
import subprocess
import tempfile
import sys
import time

ROOT = Path(__file__).resolve().parents[2]


def run_check(binary, project, directory, label, args, timeout, native=False):
    started = time.monotonic()
    display = ['--rendering-driver', 'metal', '--resolution', '1280x720', '--position', '40,60'] if native else ['--headless']
    # Match normal native game output. Verbose Metal logging additionally emits
    # lossless RGB8 compatibility conversions; actual errors/leaks still report.
    effective_args = [arg for arg in args if arg != '--verbose'] if native else args
    command = [binary, *display, '--path', str(project), '--log-file', str(directory / (label + '.log')), *effective_args]
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, start_new_session=True)
    timed_out = False
    try:
        output, _ = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        timed_out = True
        os.killpg(process.pid, signal.SIGKILL)
        output, _ = process.communicate()
    except BaseException:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait()
        raise
    lines = output.splitlines()
    diagnostics = collections.Counter(line.strip() for line in lines if line.startswith(('ERROR:', 'SCRIPT ERROR:', 'SHADER ERROR:', 'WARNING:')))
    print(label, 'TIMEOUT' if timed_out else f'exit={process.returncode}', f'seconds={time.monotonic() - started:.1f}', flush=True)
    for message, count in diagnostics.items():
        print(f'  {count} × {message}', flush=True)
        index = next(i for i, line in enumerate(lines) if line.strip() == message)
        print('\n'.join(lines[index + 1:index + 6]), flush=True)
    for line in lines:
        if line.startswith(('SURYAGARH READY', 'SAFE TANGENTS', 'Leaked instance:', 'GAME SMOKE', 'SMOKE scene', 'HUMAN CACHE', 'COACHMAN CLEARANCE')):
            print(line, flush=True)
    return not timed_out and process.returncode == 0 and not diagnostics


def user_data_directory(name):
    if sys.platform == 'darwin':
        return Path.home() / 'Library/Application Support' / name
    if sys.platform == 'win32':
        return Path(os.environ['APPDATA']) / name
    return Path(os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local/share'))) / name


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=shutil.which('godot') or '/Applications/Godot.app/Contents/MacOS/Godot')
    parser.add_argument('--pack-only', action='store_true', help='Run import and isolated pack checks after source smoke has already passed.')
    parser.add_argument('--packed', action='store_true', help='Also check the exported resource pack without access to source files.')
    parser.add_argument('--native', action='store_true', help='Also render the menu and world with Metal; no captures are made.')
    args = parser.parse_args()
    if args.pack_only: args.packed = True
    passed = True
    with tempfile.TemporaryDirectory(prefix='tlm-game-check-') as tmp:
        directory = Path(tmp)
        project = directory / 'project'
        shutil.copytree(ROOT, project, ignore=shutil.ignore_patterns('.git', '.godot', 'WorkingAssets', '__pycache__', 'node_modules'))
        config = project / 'project.godot'
        config.write_text(config.read_text().replace('[application]', '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir="' + directory.name + '"'))
        print('Disposable project prepared; importing', flush=True)
        checks = [
            ('IMPORT', ['--import'], 240),
            ('TANGENTS', ['--script', 'res://tools/assets/validate_safe_tangents.gd'], 90),
            ('HUMANS', ['--script', 'res://tools/characters/validate_human_scene_cache.gd'], 45),
            ('CLEARANCE', ['--script', 'res://tools/horses/validate_coachman_nearest.gd'], 45),
            ('MENU', ['--verbose', '--fixed-fps', '60', '--script', 'res://tools/maintenance/smoke_game.gd'], 45),
            ('WORLD', ['--verbose', '--fixed-fps', '60', '--script', 'res://tools/maintenance/smoke_game.gd', '--', '--world'], 240),
        ]
        if args.pack_only:
            checks = checks[:1]
        try:
            for label, command, timeout in checks:
                ok = run_check(args.godot, project, directory, label, command, timeout, native=args.native and label in {'MENU', 'WORLD'})
                passed = passed and ok
                if label == 'IMPORT' and not ok:
                    break
            if passed and args.packed:
                preset = project / 'export_presets.cfg'
                preset.write_text('[preset.0]\nname="Disposable check"\nplatform="macOS"\nrunnable=true\nexport_filter="all_resources"\ninclude_filter=""\nexclude_filter="WorkingAssets/*,docs/*"\nexport_path=""\nscript_export_mode=1\n[preset.0.options]\napplication/bundle_identifier="org.thelastmonsoon.disposable"\n')
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
