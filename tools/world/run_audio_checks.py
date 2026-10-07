"""Run sound/wind regressions with disposable output. Optional --native-route.

No logs, recordings, frames or reports survive success, failure or interruption.
"""
from pathlib import Path
import argparse
import os
import signal
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def run(binary, folder, script, marker, native=False):
    args = [binary, '--path', str(ROOT), '--log-file', str(folder / 'godot.log')]
    args += ['--windowed', '--resolution', '1280x720', '--max-fps', '30'] if native else ['--headless']
    args += ['--script', 'res://tools/world/' + script]
    env = dict(os.environ, TLM_AUDIO_TEST_OUTPUT=str(folder))
    process = subprocess.Popen(args, env=env, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, text=True, start_new_session=True)
    try:
        output, _ = process.communicate(timeout=180)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGKILL)
        output, _ = process.communicate()
        print(marker + ": TIMEOUT after 180 seconds", flush=True)
        for line in output.splitlines():
            if line.startswith(("PASS ", "FAIL ", "SCRIPT ERROR:", "ERROR:")):
                print(line, flush=True)
        return False
    except BaseException:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait()
        raise
    diagnostics = [line for line in output.splitlines()
                   if line.startswith(('SCRIPT ERROR:', 'ERROR:', 'FAIL ', 'WARNING:'))]
    for line in output.splitlines():
        if line.startswith(('PASS ', 'FAIL ', marker, 'AUDIO ROUTE ')):
            print(line, flush=True)
    for line in diagnostics:
        print(line, flush=True)
    return process.returncode == 0 and marker + ': PASS' in output and not diagnostics


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='/Applications/Godot.app/Contents/MacOS/Godot')
    parser.add_argument('--native-route', action='store_true')
    parser.add_argument('--quick', action='store_true', help='Skip the full-world environment route')
    args = parser.parse_args()
    passed = True
    try:
        with tempfile.TemporaryDirectory(prefix='tlm-audio-check-') as tmp:
            folder = Path(tmp)
            checks = [
                ('validate_audio_wind_isolated.gd', 'ISOLATED AUDIO WIND'),
                ('validate_footstep_audio.gd', 'FOOTSTEP AUDIO'),
                ('validate_audio_environment_isolated.gd', 'ISOLATED ENVIRONMENT AUDIO'),
                ('validate_environment_audio.gd', 'ENVIRONMENT AUDIO'),
            ]
            if args.quick:
                checks = checks[:3]
            for script, marker in checks:
                passed = run(args.godot, folder, script, marker) and passed
            if args.native_route:
                passed = run(args.godot, folder, 'capture_audio_world_route.gd',
                             'NATIVE AUDIO WORLD ROUTE', native=True) and passed
    finally:
        print('Temporary test output deleted.', flush=True)
    print('AUDIO/WIND CHECKS: ' + ('PASS' if passed else 'FAIL'), flush=True)
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
