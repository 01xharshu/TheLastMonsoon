"""Run reusable climb checks; all output is disposable, including on interruption."""
from pathlib import Path
import argparse
import signal
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--world', action='store_true')
    parser.add_argument('--trees', action='store_true')
    parser.add_argument('--animation', action='store_true')
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
            if not args.native and not args.trees:
                command.append('--headless')
            command += ['--path', str(ROOT), '--log-file', str(Path(folder) / 'godot.log')]
            if args.animation:
                command += ['--script', 'tools/characters/validate_arjun_motion_tree.gd']
            elif args.trees:
                command += ['--script', 'tools/world/validate_tree_solidity.gd']
            elif args.world:
                command += ['--script', 'tools/world/validate_roof_escape.gd']
            else:
                command.append('tools/characters/validate_arjun_leap_climb.tscn')
            command += ['--', '--output-dir='+folder]
            if args.native and not (args.world or args.trees or args.animation):
                command.append('--capture')
            command += extra
            print('Disposable review directory:', folder, flush=True)
            try:
                child = subprocess.Popen(command, cwd=ROOT)
                deadline = time.monotonic() + args.timeout
                engine_log = Path(folder) / "godot.log"
                read_position = 0
                error_tail = ""
                while True:
                    if engine_log.exists():
                        with engine_log.open(errors="replace") as stream:
                            stream.seek(read_position)
                            output = error_tail + stream.read()
                            read_position = stream.tell()
                        if "SCRIPT ERROR:" in output or "\nERROR:" in output or output.startswith("ERROR:"):
                            print("Review failed: engine reported an error.", flush=True)
                            return 1
                        error_tail = output[-128:]
                    result = child.poll()
                    if result is not None:
                        return result
                    if time.monotonic() >= deadline:
                        print("Review timed out; disposable output is being removed.", flush=True)
                        return 124
                    try:
                        child.wait(timeout=.25)
                    except subprocess.TimeoutExpired:
                        pass
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
