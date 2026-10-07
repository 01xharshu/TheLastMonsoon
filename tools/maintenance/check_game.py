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
import time

ROOT = Path(__file__).resolve().parents[2]


def run_check(binary, project, directory, label, args, timeout):
    started = time.monotonic()
    command = [binary, '--headless', '--path', str(project), '--log-file', str(directory / (label + '.log')), *args]
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
    diagnostics = collections.Counter(line.strip() for line in lines if line.startswith(('ERROR:', 'SCRIPT ERROR:', 'WARNING:')))
    print(label, 'TIMEOUT' if timed_out else f'exit={process.returncode}', f'seconds={time.monotonic() - started:.1f}', flush=True)
    for message, count in diagnostics.items():
        print(f'  {count} × {message}', flush=True)
        index = next(i for i, line in enumerate(lines) if line.strip() == message)
        print('\n'.join(lines[index + 1:index + 6]), flush=True)
    for line in lines:
        if line.startswith(('SURYAGARH READY', 'SAFE TANGENTS', 'Leaked instance:', 'GAME SMOKE', 'SMOKE scene', 'HUMAN CACHE')):
            print(line, flush=True)
    return not timed_out and process.returncode == 0 and not diagnostics


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=shutil.which('godot') or '/Applications/Godot.app/Contents/MacOS/Godot')
    args = parser.parse_args()
    passed = True
    with tempfile.TemporaryDirectory(prefix='tlm-game-check-') as tmp:
        directory = Path(tmp)
        project = directory / 'project'
        shutil.copytree(ROOT, project, ignore=shutil.ignore_patterns('.git', '.godot', 'WorkingAssets', '__pycache__', 'node_modules'))
        config = project / 'project.godot'
        config.write_text(config.read_text().replace('[application]', '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir="' + tmp + '/userdata"'))
        print('Disposable project prepared; importing', flush=True)
        checks = [
            ('IMPORT', ['--import'], 240),
            ('TANGENTS', ['--script', 'res://tools/assets/validate_safe_tangents.gd'], 90),
            ('HUMANS', ['--script', 'res://tools/characters/validate_human_scene_cache.gd'], 45),
            ('MENU', ['--verbose', '--fixed-fps', '60', '--script', 'res://tools/maintenance/smoke_game.gd'], 45),
            ('WORLD', ['--verbose', '--fixed-fps', '60', '--script', 'res://tools/maintenance/smoke_game.gd', '--', '--world'], 240),
        ]
        for label, command, timeout in checks:
            ok = run_check(args.godot, project, directory, label, command, timeout)
            passed = passed and ok
            if label == 'IMPORT' and not ok:
                break
    print('All temporary projects, caches, user data and logs deleted.', flush=True)
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
