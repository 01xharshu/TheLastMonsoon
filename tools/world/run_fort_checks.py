"""Run reusable fort checks with disposable output and bounded child processes."""
from pathlib import Path
import argparse
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--main-world', action='store_true', help='Also check the resident landscape and access trail')
args = parser.parse_args()
scripts = ['bake_fort_navigation.gd', 'validate_fort_features.gd', 'validate_fort_playability.gd', 'validate_fort_encounter.gd']
if args.main_world:
    scripts.append('validate_fort_in_world.gd')
with tempfile.TemporaryDirectory(prefix='tlm-fort-checks-') as folder:
    for script in scripts:
        result = subprocess.run([
            '/Applications/Godot.app/Contents/MacOS/Godot', '--headless', '--path', str(ROOT),
            '--log-file', str(Path(folder) / 'engine.log'), '--script', 'res://tools/world/' + script,
        ], cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
        print(result.stdout, flush=True)
        if result.returncode or 'SCRIPT ERROR' in result.stdout or 'FORT FAIL' in result.stdout:
            raise SystemExit(result.returncode or 1)
