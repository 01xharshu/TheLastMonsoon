"""Disposable actual-world roadside tree clearance and native review."""
from pathlib import Path
import argparse, os, shutil, signal, subprocess, tempfile, threading, time
from run_performance_checks import other_native_jobs

def competing(own_pid=None):
    # An idle editor is not a gameplay measurement job.
    jobs = other_native_jobs(own_pid)
    active = []
    for pid in jobs:
        command = subprocess.run(["ps", "-p", str(pid), "-o", "command="], capture_output=True, text=True).stdout
        if "--editor" not in command: active.append(pid)
    return active
ROOT = Path(__file__).resolve().parents[2]
GODOT = '/Applications/Godot.app/Contents/MacOS/Godot'
def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native', action='store_true')
    parser.add_argument('--review', action='store_true')
    args = parser.parse_args()
    if args.review and not args.native: parser.error('--review requires --native')
    with tempfile.TemporaryDirectory(prefix='tlm-roadside-') as folder:
        directory = Path(folder); project = directory/'project'; project.mkdir()
        userdata = Path.home()/'Library/Application Support'/directory.name
        try:
            for entry in ROOT.iterdir():
                if entry.name not in ('.git', 'project.godot'):
                    (project/entry.name).symlink_to(entry, target_is_directory=entry.is_dir())
            (project/'project.godot').write_text((ROOT/'project.godot').read_text().replace('[application]', '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="'+directory.name+'"', 1))
            env = os.environ.copy()
            if args.review: env['TLM_ROADSIDE_REVIEW'] = folder
            env['TLM_ROADSIDE_EPOCH'] = str(directory/'epoch')
            log = directory/'engine.log'
            with log.open('w') as stream:
                process = subprocess.Popen([GODOT]+(['--rendering-driver','metal','--resolution','1280x720'] if args.native else ['--headless'])+['--path',str(project),'--script','res://tools/world/validate_roadside_trees.gd'], stdout=stream, stderr=subprocess.STDOUT, env=env)
                stop = threading.Event()
                def watch():
                    while not stop.wait(1):
                        if args.native and competing(process.pid) and process.poll() is None:
                            print("Pausing owned roadside renderer for another native job", flush=True)
                            process.send_signal(signal.SIGSTOP)
                            while not stop.wait(1) and competing(process.pid): pass
                            (directory/"epoch").write_text(str(time.monotonic_ns()))
                            if process.poll() is None: process.send_signal(signal.SIGCONT)
                watcher = threading.Thread(target=watch, daemon=True); watcher.start()
                try:
                    start = time.monotonic(); shown = False
                    while process.poll() is None:
                        content = log.read_text()
                        if 'ROADSIDE REVIEW READY' in content and not shown:
                            print('ROADSIDE REVIEW DIR', folder, flush=True); shown = True
                        if time.monotonic()-start > 540 or 'SCRIPT ERROR:' in content:
                            process.terminate(); break
                        time.sleep(.5)
                    process.wait(timeout=15)
                finally:
                    stop.set(); watcher.join(timeout=3)
                    if process.poll() is None:
                        process.send_signal(signal.SIGCONT); process.kill(); process.wait()
            content = log.read_text()
            print('\n'.join(line for line in content.splitlines() if any(word in line for word in ['ROADSIDE','ERROR',' at:','backtrace','[0]','[1]'])), flush=True)
            return process.returncode or int('ERROR:' in content or 'ROADSIDE TREES: PASS' not in content)
        finally: shutil.rmtree(userdata, ignore_errors=True)
if __name__ == '__main__': raise SystemExit(main())
