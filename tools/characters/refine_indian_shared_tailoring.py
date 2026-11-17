"""Build and verify separate tailored fuller studies serially, without promotion.

Existing studies require --refine-existing. Every Blender job is bounded and
its diagnostics stay in memory. No test media or reports are retained.
"""
import argparse
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
BLENDER = '/Applications/Blender.app/Contents/MacOS/Blender'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--identity', action='append', required=True,
                    choices=[f'female_{n:02}' for n in (1, 2, 3, 5, 6)])
parser.add_argument('--refine-existing', action='store_true')
args = parser.parse_args()

def run(tool, identity, source=None, extra=(), check=True):
    command = [BLENDER, '--background', '-noaudio', '--python-exit-code', '1',
               '--python', str(ROOT / 'tools/characters' / tool), '--', '--identity', identity]
    if source:
        command += ['--source', str(source)]
    command += list(extra)
    result = subprocess.run(command, capture_output=True, text=True, timeout=180)
    output = result.stdout + result.stderr
    print(identity, tool, 'exit', result.returncode, flush=True)
    print('\n'.join(line for line in output.splitlines() if any(mark in line for mark in
          ('SHARED_TAILORING_', 'MOTION_LAYER_', 'SELF_CLOTH_REPAIR', 'INDIAN_TAIL_FIT',
           'STREET_SOURCE_CONTACT', 'RuntimeError', 'Error:'))), flush=True)
    if check and result.returncode:
        print(output[-4000:], flush=True)
        raise SystemExit('Failed ' + identity + ': ' + tool)
    return result.returncode == 0

for identity in args.identity:
    source = ROOT / 'WorkingAssets/NPCs/indian_body_candidates' / identity / 'tailored_fuller_cloth_study.blend'
    created = not source.exists()
    if source.exists():
        if not args.refine_existing:
            raise SystemExit('Existing study requires explicit --refine-existing: ' + str(source))
    else:
        run('build_indian_shared_tailoring_study.py', identity, extra=['--output', str(source)])
    run('fit_indian_candidate_motion_body.py', identity, source, ['--garment', 'Opaque fitted bra and thong foundation'])
    for garment in ['Street coherent cotton blouse and pallu', 'Street sari front pallu']:
        run('repair_indian_candidate_self_cloth.py', identity, source, ['--garment', garment])
    if created:
        run('fit_indian_candidate_tail.py', identity, source, ['--gap', '.006'])
    run('fit_indian_candidate_motion_body.py', identity, source, ['--garment', 'Street sari back tail'])
    pairs = [('Street coherent cotton blouse and pallu', 'Opaque fitted bra and thong foundation'),
             ('Street sari front pallu', 'Street coherent cotton blouse and pallu'),
             ('Street sari back tail', 'Street coherent cotton blouse and pallu'),
             ('Street sari back tail', 'Street sari front pallu')]
    for attempt in range(3):
        for outer, inner in pairs:
            run('fit_indian_candidate_motion_layers.py', identity, source,
                ['--outer', outer, '--inner', inner, '--gap', '.006'])
        for garment in ['Street coherent cotton blouse and pallu', 'Street sari front pallu', 'Street sari back tail']:
            run('repair_indian_candidate_self_cloth.py', identity, source, ['--garment', garment])
        passed = run('audit_indian_candidate_layers.py', identity, source, check=False)
        for garment in ['Street coherent cotton blouse and pallu', 'Street sari front pallu', 'Street sari back tail']:
            passed = run('audit_indian_candidate_self_cloth.py', identity, source,
                         ['--garment', garment], check=False) and passed
        if passed:
            break
    else:
        raise SystemExit('Coupled garment fit did not converge: ' + identity)
    for layer in ['foundation', 'upper']:
        run('audit_indian_body_candidate.py', identity, source, ['--layer', layer])
    print('TAILORED_SOURCE_SAMPLED_PASS', identity, 'not visual, full-motion or live approval', flush=True)
