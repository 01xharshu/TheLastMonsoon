"""Export fuller studies to disposable GLBs and inspect actual street actors.

No production files or saves are replaced. Captures and assets are removed
when each native review ends, including failures. Numerical results do not
grant final clothing or motion approval.
"""
import argparse
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
BLENDER = '/Applications/Blender.app/Contents/MacOS/Blender'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--identity', action='append', choices=[f'female_{n:02}' for n in range(1, 7)])
parser.add_argument('--review-seconds', type=int, default=0)
parser.add_argument('--source',type=Path,help='Review one explicit editable study with exactly one --identity')
parser.add_argument('--foundation-only', action='store_true')
parser.add_argument('--fit-waist', action='store_true')
parser.add_argument('--upper-contact', action='store_true')
parser.add_argument('--realtime-walk',action='store_true')
parser.add_argument('--secondary-study',action='store_true',help='Use the separate authored secondary rig for each selected identity')
parser.add_argument('--fit-native-foundation',action='store_true',help='Update isolated foundation from actual native poses; re-export/recheck afterward')
parser.add_argument("--fit-run-tail", action="store_true", help="Fit the back tail on an explicit isolated source using actual run poses")
parser.add_argument("--fit-reactions", action="store_true", help="Fit the selected garment against captured hit/slap/fall/down poses")
parser.add_argument("--run-fit-garment", default="Street sari back tail", choices=["Street sari back tail", "Opaque fitted bra and thong foundation", "Street coherent cotton blouse and pallu", "Street sari front pallu", "Wrapped sari lower drape", "Sari lower border"])
args = parser.parse_args()
if args.fit_reactions and (not args.source or not args.upper_contact):
    parser.error("--fit-reactions requires --source and --upper-contact")
if args.fit_run_tail and (not args.source or not args.realtime_walk or not args.upper_contact or os.getenv("TLM_STREET_RUN") != "1"):
    parser.error("--fit-run-tail requires --source, --realtime-walk, --upper-contact and TLM_STREET_RUN=1")
if args.source and args.secondary_study:parser.error('--source and --secondary-study are mutually exclusive')
if args.source and (not args.source.is_file() or not args.identity or len(args.identity)!=1):
    parser.error('--source requires an existing study and exactly one --identity')
for identity in args.identity or [f'female_{n:02}' for n in range(1, 7)]:
    folder = ROOT / 'WorkingAssets/NPCs/indian_body_candidates' / identity
    tailored = folder / 'tailored_fuller_study.blend'
    shared = folder / 'tailored_fuller_cloth_study.blend'
    armhole = folder / 'tailored_armhole_study.blend'
    source = armhole if armhole.is_file() else (shared if shared.is_file() else (tailored if tailored.is_file() else folder / 'fuller_body_study.blend'))
    if args.secondary_study:source=folder/'secondary_motion_study.blend'
    if args.source:source=args.source.expanduser().resolve()
    if not source.is_file():
        raise SystemExit('Build the separate fuller source first: ' + str(source))
    with tempfile.TemporaryDirectory(prefix='tlm_fuller_export_') as temporary:
        asset = Path(temporary) / (identity + '.glb')
        result = subprocess.run([BLENDER, '--background', '-noaudio', '--python-exit-code', '1',
            '--python', str(ROOT / 'tools/characters/export_indian_body_candidate.py'), '--',
            '--identity', identity, '--source', str(source), '--output', str(asset)],
            capture_output=True, text=True, timeout=120)
        output = result.stdout + result.stderr
        if result.returncode or not asset.is_file():
            print(output[-6000:], flush=True)
            raise SystemExit(result.returncode or 1)
        print('\n'.join(line for line in output.splitlines() if 'INDIAN_CANDIDATE_EXPORT' in line), flush=True)
        env = dict(os.environ, TLM_CANDIDATE_FIT_WAIST='1' if args.fit_waist else '0',
                   TLM_FOUNDATION_ONLY='1' if args.foundation_only else '0',
                   TLM_CANDIDATE_UPPER_CONTACT='1' if args.upper_contact else '0',
                   TLM_CANDIDATE_REALTIME_WALK='1' if args.realtime_walk else '0',
                   TLM_CANDIDATE_REACTIONS='1' if args.fit_reactions else os.getenv('TLM_CANDIDATE_REACTIONS','0'))
        subprocess.run([sys.executable, '-u', str(ROOT / 'tools/characters/check_indian_body_candidate.py'),
            '--identity', identity, '--asset', str(asset), '--review-seconds', str(args.review_seconds)] +
            (['--fit-foundation-source',str(source)] if args.fit_native_foundation or args.fit_run_tail or args.fit_reactions else []) +
            (['--fit-garment', args.run_fit_garment] if args.fit_run_tail or args.fit_reactions else []),
            env=env, check=True)
