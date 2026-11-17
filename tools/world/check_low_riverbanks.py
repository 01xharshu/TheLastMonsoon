"""Run the low riverbank checks with isolated user data and disposable captures."""
import argparse, os, subprocess, sys, tempfile, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/characters'))
from private_godot_project import private_project
GODOT='/Applications/Godot.app/Contents/MacOS/Godot'
def main():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--render',action='store_true',help='Render both riverbank views with Metal')
 parser.add_argument('--review-seconds',type=int,default=0,help='Briefly retain temporary native frames for review')
 args=parser.parse_args()
 with tempfile.TemporaryDirectory(prefix='tlm-lowbank-check-') as folder, private_project(ROOT,Path(folder)) as project:
  env=dict(os.environ,TLM_RIVER_TEST_OUTPUT=folder)
  scripts=['validate_low_riverbanks.gd','validate_river_dynamics.gd']
  if args.render:scripts.append('capture_low_riverbanks.gd')
  for script in scripts:
   command=[GODOT,'--rendering-driver','metal'] if script.startswith('capture_') else [GODOT,'--headless']
   command+=['--path',str(project),'--log-file',str(Path(folder)/(script+'.log')),'--script','res://tools/world/'+script]
   result=subprocess.run(command,env=env,cwd=ROOT,text=True,capture_output=True,timeout=180)
   output=result.stdout+result.stderr
   for line in output.splitlines():
    if line.startswith(('LOW_BANK_VALIDATION','LOW_BANK_CAPTURE','PASS ','FAIL ')):print(line,flush=True)
   if result.returncode or 'ERROR:' in output or 'SCRIPT ERROR:' in output:
    print('\n'.join(output.splitlines()[-16:]));return 1
   if script.startswith('capture_') and args.review_seconds:
    print('TEMP REVIEW '+folder,flush=True);time.sleep(min(60,args.review_seconds))
 return 0
if __name__=='__main__':raise SystemExit(main())
