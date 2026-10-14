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

def private_directory(path):
    """Break only a temporary directory link before installing a reference file."""
    if path.is_symlink():
        source = path.resolve()
        path.unlink()
        path.mkdir()
        for child in source.iterdir():
            (path / child.name).symlink_to(child, target_is_directory=child.is_dir())


def native_jobs():
    lines = subprocess.run(['pgrep', '-fl', 'Godot'], capture_output=True, text=True).stdout.splitlines()
    return [line for line in lines if ' /Applications/Godot.app/Contents/MacOS/Godot ' in line and '--headless' not in line]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--review', action='store_true')
    parser.add_argument('--village-only', action='store_true')
    parser.add_argument('--actions-only', action='store_true')
    parser.add_argument('--detail-review', action='store_true')
    parser.add_argument('--construction-review', action='store_true')
    parser.add_argument('--reference-details', action='store_true', help='Compare prior committed environment code in the disposable project only.')
    parser.add_argument('--headless', action='store_true', help='Structural detail review only; no visual approval.')
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
        if args.reference_details:
            for relative in ['world/suryagarh/route_and_market_detail.gd', 'world/suryagarh/settlements/bhairavpur_village.gd', 'world/suryagarh/settlements/civil_lines.gd', 'world/suryagarh/shaders/market_cloth.gdshader']:
                target = project / relative
                for parent in reversed(target.parents):
                    if parent != project and project in parent.parents:
                        private_directory(parent)
                reference = subprocess.run(['git', 'show', 'HEAD:' + relative], cwd=ROOT, capture_output=True, check=True).stdout
                target.unlink()
                target.write_bytes(reference)
        process = None
        try:
            print('PLAY_TEMP', directory, flush=True)
            deadline = time.monotonic() + 600
            announced = False
            while not args.headless and native_jobs():
                if not announced:
                    print('Waiting for existing native renderer; no other process will be stopped.', flush=True)
                    announced = True
                if time.monotonic() > deadline:
                    raise RuntimeError('Native renderer remained occupied')
                time.sleep(5)
            command = [GODOT, '--path', str(project), '--windowed', '--resolution', '960x540', '--rendering-driver', 'metal', '--max-fps', '60', '--log-file', str(output / 'engine.log'), '--script', 'res://tools/world/validate_native_world_walk.gd']
            if args.detail_review:
                command[-1] = 'res://tools/world/review_route_market_detail.gd'
            if args.construction_review:
                command[-1] = 'res://tools/world/review_market_construction.gd'
            if args.headless:
                if not args.detail_review:
                    raise ValueError('--headless requires --detail-review')
                command = [GODOT, '--headless', '--path', str(project), '--log-file', str(output / 'engine.log'), '--script', command[-1]]
            if args.village_only:
                command += ['--', '--village-only']
            if args.actions_only:
                command += ['--', '--actions-only']
            if args.reference_details:
                command += ['--', '--reference-details']
            process = subprocess.Popen(command, env=dict(os.environ, TLM_TEST_OUTPUT_DIR=directory), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            try:
                result, _ = process.communicate(timeout=240)
            except subprocess.TimeoutExpired:
                process.kill()
                result, _ = process.communicate()
                print('PLAY TIMEOUT', flush=True)
            print(result[-14000:], flush=True)
            print('PLAY_EXIT', process.returncode, flush=True)
            engine_errors = 'ERROR:' in result
            if engine_errors:
                print('PLAY_ENGINE_ERRORS: runtime check is not clean.', flush=True)
            if args.review:
                print('REVIEW_READY', directory, flush=True)
                deadline = time.monotonic() + 120
                while time.monotonic() < deadline and not (output / 'review_done').exists():
                    time.sleep(.5)
            return process.returncode or (1 if engine_errors else 0)
        finally:
            if process and process.poll() is None:
                process.kill()
                process.wait()
            shutil.rmtree(Path.home() / 'Library/Application Support' / output.name, ignore_errors=True)
            print('Temporary play views, logs and save data removed on exit.', flush=True)


if __name__ == '__main__':
    raise SystemExit(main())
