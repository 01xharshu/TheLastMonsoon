"""Native Arjun play check with disposable views, logs and isolated save data.
Creates links to the live project; source/cache edits by other chats remain live.
Run with --review to inspect temporary views before touching review_done.
"""
from pathlib import Path
import argparse
import os
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[2]
GODOT = '/Applications/Godot.app/Contents/MacOS/Godot'


def native_jobs():
    lines = subprocess.run(['pgrep', '-fl', 'Godot'], capture_output=True, text=True).stdout.splitlines()
    return [line for line in lines if ' /Applications/Godot.app/Contents/MacOS/Godot ' in line and '--headless' not in line]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--review', action='store_true')
    parser.add_argument('--village-only', action='store_true')
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix='tlm-native-play-') as directory:
        output = Path(directory)
        project = output / 'project'
        project.mkdir()
        for source in ROOT.iterdir():
            if source.name not in ('.git', 'project.godot', 'WorkingAssets'):
                (project / source.name).symlink_to(source, target_is_directory=source.is_dir())
        config = (ROOT / 'project.godot').read_text().replace('[application]', '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="' + output.name + '"')
        (project / 'project.godot').write_text(config)
        process = None
        try:
            print('PLAY_TEMP', directory, flush=True)
            deadline = time.monotonic() + 600
            announced = False
            while native_jobs():
                if not announced:
                    print('Waiting for existing native renderer; no other process will be stopped.', flush=True)
                    announced = True
                if time.monotonic() > deadline:
                    raise RuntimeError('Native renderer remained occupied')
                time.sleep(5)
            command = [GODOT, '--path', str(project), '--windowed', '--resolution', '960x540', '--rendering-driver', 'metal', '--max-fps', '60', '--log-file', str(output / 'engine.log'), '--script', 'res://tools/world/validate_native_world_walk.gd']
            if args.village_only:
                command += ['--', '--village-only']
            process = subprocess.Popen(command, env=dict(os.environ, TLM_TEST_OUTPUT_DIR=directory), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            try:
                result, _ = process.communicate(timeout=240)
            except subprocess.TimeoutExpired:
                process.kill()
                result, _ = process.communicate()
                print('PLAY TIMEOUT', flush=True)
            print(result[-14000:], flush=True)
            print('PLAY_EXIT', process.returncode, flush=True)
            if args.review:
                print('REVIEW_READY', directory, flush=True)
                deadline = time.monotonic() + 120
                while time.monotonic() < deadline and not (output / 'review_done').exists():
                    time.sleep(.5)
            return process.returncode
        finally:
            if process and process.poll() is None:
                process.kill()
                process.wait()
            shutil.rmtree(Path.home() / 'Library/Application Support' / output.name, ignore_errors=True)
            print('Temporary play views, logs and save data removed on exit.', flush=True)


if __name__ == '__main__':
    raise SystemExit(main())
