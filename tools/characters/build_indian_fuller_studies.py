"""Build separate fuller adult female sources, preserving existing studies.

Run with system Python. Existing outputs are skipped for resumability; this
never changes production GLBs or grants clothing/motion approval.
"""
import argparse
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--blender', default='/Applications/Blender.app/Contents/MacOS/Blender')
parser.add_argument('--timeout', type=int, default=300)
args = parser.parse_args()
for number in range(1, 7):
    identity = f'female_{number:02}'
    folder = ROOT / 'WorkingAssets/NPCs/indian_body_candidates' / identity
    tailored = folder / 'tailored_deep_vneck_study.blend'
    source = tailored if tailored.is_file() else folder / 'candidate.blend'
    output = folder / ('tailored_fuller_study.blend' if tailored.is_file() else 'fuller_body_study.blend')
    if output.exists():
        print('EXISTING_UNAPPROVED_STUDY', identity, output, flush=True)
        continue
    command = [args.blender, '--background', '-noaudio', '--python-exit-code', '1',
               '--python', str(ROOT / 'tools/characters/build_indian_fuller_body_study.py'),
               '--', '--identity', identity, '--source', str(source), '--output', str(output)]
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=args.timeout)
    except subprocess.TimeoutExpired:
        raise SystemExit(f'Blender timed out for {identity}; no approval or successful build claimed')
    lines = (result.stdout + result.stderr).splitlines()
    print('\n'.join(line for line in lines if any(mark in line for mark in
          ('FULLER_BODY_STUDY', 'Error', 'Traceback'))), flush=True)
    if result.returncode:
        print('\n'.join(lines[-20:]), flush=True)
        raise SystemExit(result.returncode)
