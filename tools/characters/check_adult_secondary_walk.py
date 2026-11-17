"""Review the gated adult river walk from both sides; discard all captures."""
import argparse
import json
import os
import subprocess
import tempfile
import time
from pathlib import Path

from private_godot_project import private_project

ROOT = Path(__file__).resolve().parents[2]
ENGINE = '/Applications/Godot.app/Contents/MacOS/Godot'
parser = argparse.ArgumentParser()
parser.add_argument('--review-seconds', type=int, default=0)
parser.add_argument('--profile', choices=['smaller', 'original', 'fuller'], default='original')
parser.add_argument('--foundation-only', action='store_true', help='Inspect body and opaque foundation without outer garments')
args = parser.parse_args()
with tempfile.TemporaryDirectory(prefix='tlm_secondary_walk_') as folder, private_project(ROOT, Path(folder)) as project:
    env = os.environ.copy()
    env.update(TLM_SECONDARY_WALK_OUTPUT=folder, TLM_RIVER_SECONDARY='1', TLM_RIVER_PROFILE=args.profile)
    env['TLM_SECONDARY_FOUNDATION_ONLY'] = '1' if args.foundation_only else '0'
    env.pop('TLM_RIVER_RELAXED', None)
    command = [ENGINE, '--path', str(project), '--rendering-driver', 'metal',
               '--resolution', '900x900', '--log-file', str(Path(folder) / 'engine.log'),
               '--script', 'res://tools/characters/capture_adult_secondary_walk.gd']
    result = subprocess.run(command, cwd=ROOT, env=env, text=True, capture_output=True, timeout=120)
    output = result.stdout + result.stderr
    lines = [line for line in output.splitlines() if line.startswith('ADULT_SECONDARY_WALK ')]
    errors = result.returncode != 0 or 'SCRIPT ERROR:' in output or '\nERROR:' in output
    if len(lines) != 1:
        errors = True
    else:
        print(lines[0], flush=True)
        errors |= not json.loads(lines[0].split(' ', 1)[1]).get('passed', False)
    if not all((Path(folder) / f'{side}_{i:02}.png').is_file() for side in ('front', 'back') for i in range(4)):
        errors = True
    if errors:
        print(output[-5000:], flush=True)
        raise SystemExit(1)
    if args.review_seconds:
        print('TEMP REVIEW ' + folder, flush=True)
        time.sleep(min(60, args.review_seconds))
