"""Run reusable forest checks without retaining logs, captures or reports.
Usage: python3 tools/environment/run_forest_checks.py [--render]
"""
from pathlib import Path
import argparse, os, shutil, subprocess, tempfile
ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser();parser.add_argument('--render',action='store_true');args=parser.parse_args()
godot=shutil.which('godot') or '/Applications/Godot.app/Contents/MacOS/Godot'
with tempfile.TemporaryDirectory(prefix='tlm-forest-check-') as out:
    env=os.environ.copy();env['FOREST_REVIEW_DIR']=out
    scripts=[('validate_foundation',True,60),('validate_world_patch',True,120)]
    if args.render:scripts += [('validate_foliage_motion',False,60),('capture_benchmark',False,90),('capture_world_patch',False,150)]
    for name, headless, timeout in scripts:
        cmd=[godot,'--path',str(ROOT)]
        if headless:cmd.append('--headless')
        cmd+=['--script',f'res://environment/forest/review/{name}.gd']
        try:r=subprocess.run(cmd,env=env,capture_output=True,text=True,timeout=timeout)
        except subprocess.TimeoutExpired as exc:
            print(name,'TIMEOUT');print(str(exc.stderr or '')[-2500:]);raise SystemExit(1)
        output=r.stdout+r.stderr
        failed=r.returncode!=0 or 'SCRIPT ERROR' in output or '\nERROR:' in output
        if name.startswith('validate_') and 'PASS' not in output:failed=True
        print(name,'FAIL' if failed else 'PASS',flush=True)
        for line in output.splitlines():
            if any(word in line for word in ['FOREST_','DEFAULT_CHUNKS','LOD ','ERROR','WARNING']):print(line,flush=True)
        if failed:raise SystemExit(1)
    print('Temporary outputs removed on exit; inspect the scenes in-game for art approval.')
