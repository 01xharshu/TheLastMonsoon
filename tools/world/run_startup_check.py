"""Exercise real Play/Load with temporary saves/logs and bounded process cleanup."""
import argparse, json, os, signal, subprocess, tempfile, threading, time
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
def interrupted(signum, _frame):
    raise SystemExit(128 + signum)
def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--headless', action='store_true')
    parser.add_argument('--slot', type=int, choices=[0, 1], default=0)
    args = parser.parse_args()
    for sig in (signal.SIGINT, signal.SIGTERM): signal.signal(sig, interrupted)
    with tempfile.TemporaryDirectory(prefix='tlm-startup-') as folder:
        directory = Path(folder)
        (directory / 'slot_1.json').write_text(json.dumps({'version':1,'position':[-230,20,180],'saved_at':1}))
        env = os.environ.copy()
        env['TLM_STARTUP_TEMP'] = folder
        command = ['/Applications/Godot.app/Contents/MacOS/Godot', *(['--headless'] if args.headless else []), '--path', str(ROOT), '--log-file', str(directory / 'engine.log'), '--script', 'res://tools/world/validate_world_startup.gd', '--', '--slot=' + str(args.slot)]
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        timer = threading.Timer(180, process.kill)
        timer.start()
        errors = 0
        start = time.monotonic()
        try:
            for line in process.stdout:
                if line.startswith(('ERROR:', 'SCRIPT ERROR:', 'SHADER ERROR:', 'WARNING:')): errors += 1
                if line.startswith(('WORLD STARTUP', 'ERROR:', 'SCRIPT ERROR:', 'SHADER ERROR:', 'WARNING:')): print(line, end='', flush=True)
                if line.startswith('SCRIPT ERROR:') and ('Parse Error' in line or 'Compile Error' in line): process.terminate()
                if 'uninitialized RID' in line or 'wrong RID' in line: process.terminate()
            result = process.wait()
            print('Startup process seconds:', round(time.monotonic() - start, 2), 'errors/warnings:', errors, flush=True)
        finally:
            timer.cancel()
            if process.poll() is None:
                process.terminate()
                try: process.wait(timeout=5)
                except subprocess.TimeoutExpired: process.kill(); process.wait()
        return result or int(errors > 0)
if __name__ == '__main__': raise SystemExit(main())
