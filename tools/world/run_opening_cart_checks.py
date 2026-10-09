"""Run live opening cart checks; always delete disposable review output."""
import argparse
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--headless', action='store_true')
    parser.add_argument('--review-seconds', type=int, default=0)
    args = parser.parse_args()
    passed = False
    try:
        with tempfile.TemporaryDirectory(prefix='tlm-opening-cart-') as tmp:
            command = ['/Applications/Godot.app/Contents/MacOS/Godot', '--path', str(ROOT)]
            command += ['--headless'] if args.headless else ['--windowed', '--resolution', '1280x720', '--max-fps', '60']
            command += ['--script', 'res://tools/world/validate_opening_cart_passage.gd']
            process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                       text=True, start_new_session=True,
                                       env=dict(os.environ, TLM_CART_OUTPUT=tmp))
            try:
                output, _ = process.communicate(timeout=260)
                for line in output.splitlines():
                    if any(word in line for word in ['ERROR', 'WARNING', 'OPENING CART']):
                        print(line, flush=True)
                passed = process.returncode == 0 and 'OPENING CART PASSAGE: PASS' in output and 'ERROR' not in output
                if not args.headless and args.review_seconds:
                    print('REVIEW DIRECTORY: '+tmp, flush=True)
                    time.sleep(max(0, min(60, args.review_seconds)))
            finally:
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
    finally:
        print('Disposable cart frames and logs deleted.', flush=True)
    print('CART CHECKS: '+('PASS' if passed else 'FAIL'), flush=True)
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
