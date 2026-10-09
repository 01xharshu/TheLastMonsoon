"""Disposable village construction, cooking and carried-light verification."""
from pathlib import Path
import argparse
import signal
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--headless', action='store_true')
    parser.add_argument('--world', action='store_true')
    parser.add_argument('--review-seconds', type=int, default=0)
    args = parser.parse_args()
    def interrupted(_signum, _frame):
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, interrupted)
    with tempfile.TemporaryDirectory(prefix='tlm-village-households-') as tmp:
        print('Disposable review directory: ' + tmp, flush=True)
        command = ['/Applications/Godot.app/Contents/MacOS/Godot', '--path', str(ROOT),
                   '--script', 'res://tools/world/run_village_household_fixture.gd']
        if args.headless:
            command.append('--headless')
        else:
            command.extend(['--windowed', '--resolution', '1280x720', '--rendering-driver', 'metal'])
        command.extend(['--', '--output=' + tmp])
        if args.world:
            command.append('--world')
        process = None
        try:
            with open(Path(tmp) / 'run.log', 'w') as log:
                process = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
                try:
                    result = process.wait(timeout=240)
                except subprocess.TimeoutExpired:
                    process.terminate()
                    process.wait(timeout=10)
                    result = 1
            text = (Path(tmp) / 'run.log').read_text()
            print(text, flush=True)
            passed = result == 0 and 'VILLAGE HOUSEHOLD VARIETY PASS' in text and 'SCRIPT ERROR' not in text and 'ERROR:' not in text
            if args.review_seconds:
                print('Review images temporarily available.', flush=True)
                time.sleep(min(45, args.review_seconds))
            return 0 if passed else 1
        finally:
            if process is not None and process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()


if __name__ == '__main__':
    raise SystemExit(main())
