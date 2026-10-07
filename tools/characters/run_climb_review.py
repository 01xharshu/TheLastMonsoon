"""Run reusable climb checks; all output is disposable, including on interruption."""
from pathlib import Path
import argparse
import signal
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--world', action='store_true')
    parser.add_argument('--native', action='store_true')
    parser.add_argument('--timeout', type=float, default=240, help='Maximum review duration in seconds')
    parser.add_argument('--godot', default='/Applications/Godot.app/Contents/MacOS/Godot')
    args, extra = parser.parse_known_args()
    child = None
    def interrupt(_signal, _frame):
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, interrupt)
    try:
        with tempfile.TemporaryDirectory(prefix='tlm-climb-review-') as folder:
            command = [args.godot]
            if not args.native:
                command.append('--headless')
            command += ['--path', str(ROOT)]
            if args.world:
                command += ['--script', 'tools/world/validate_roof_escape.gd']
            else:
                command.append('tools/characters/validate_arjun_leap_climb.tscn')
            command += ['--', '--output-dir='+folder]
            if args.native and not args.world:
                command.append('--capture')
            command += extra
            print('Disposable review directory:', folder, flush=True)
            try:
                child = subprocess.Popen(command, cwd=ROOT)
                try:
                    return child.wait(timeout=args.timeout)
                except subprocess.TimeoutExpired:
                    print("Review timed out; disposable output is being removed.", flush=True)
                    return 124
            finally:
                if child is not None and child.poll() is None:
                    child.terminate()
                    try:
                        child.wait(timeout=8)
                    except subprocess.TimeoutExpired:
                        child.kill()
                        child.wait()
    except KeyboardInterrupt:
        return 130

if __name__ == '__main__':
    raise SystemExit(main())
