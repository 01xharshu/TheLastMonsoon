"""Run reusable contact checks with disposable output; optional local inspection."""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('--inspect', action='store_true')
parser.add_argument('--headless', action='store_true')
parser.add_argument('--police', action='store_true', help='Review the police custody sequence instead')
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='arjun_contact_') as output:
    print(f'Temporary review: {output}', flush=True)
    env = dict(os.environ, TLM_TEST_OUTPUT=output)
    command = ['/Applications/Godot.app/Contents/MacOS/Godot', '--path', str(root), '--log-file', str(Path(output)/'engine.log')]
    if args.headless:
        command.append('--headless')
    command += ['--script', 'tools/world/validate_police_custody.gd' if args.police else 'tools/world/validate_mango_reach.gd']
    result = subprocess.run(command, env=env, capture_output=True, text=True)
    print(result.stdout, end='')
    print(result.stderr, end='')
    if args.inspect and not args.headless:
        input('Review temporary images, then press Enter to delete them: ')
    code = result.returncode
raise SystemExit(code)
