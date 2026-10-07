"""Run reusable cattle checks with temporary outputs and unconditional cleanup."""
import argparse, json, os, signal, subprocess, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
GODOT='/Applications/Godot.app/Contents/MacOS/Godot'
BLENDER='/Applications/Blender.app/Contents/MacOS/Blender'
TASKS={
 'build':[BLENDER,'--background','--python','tools/animals/build_household_cow.py'],
 'import':[GODOT,'--headless','--path',str(ROOT),'--editor','--import'],
 'source':[GODOT,'--headless','--path',str(ROOT),'--script','res://tools/animals/validate_cow_source.gd'],
 'contact':[GODOT,'--headless','--path',str(ROOT),'--fixed-fps','60','--script','res://tools/animals/validate_cow_motion.gd'],
 'draft_cow':[GODOT,'--headless','--path',str(ROOT),'--script','res://tools/animals/validate_draft_cow.gd'],
 'draft':[GODOT,'--headless','--path',str(ROOT),'--fixed-fps','60','--script','res://tools/world/validate_bullock_mud.gd'],
 'review':[GODOT,'--path',str(ROOT),'--rendering-method','mobile','--script','res://tools/animals/review_cow_oct06.gd'],
 'world_review':[GODOT,'--path',str(ROOT),'--rendering-method','mobile','--script','res://tools/animals/capture_cattle_world.gd'],
}
def interrupted(signum,frame):raise KeyboardInterrupt

def main():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('tasks',nargs='+',choices=TASKS)
 parser.add_argument('--timeout',type=int,default=120)
 args=parser.parse_args();signal.signal(signal.SIGTERM,interrupted)
 result=0
 try:
  with tempfile.TemporaryDirectory(prefix='tlm-cattle-') as folder:
   env=dict(os.environ,TLM_TEST_OUTPUT_DIR=folder)
   for task in args.tasks:
    child=subprocess.Popen(TASKS[task],cwd=ROOT,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
    try:output,_=child.communicate(timeout=args.timeout)
    except BaseException:
     child.terminate()
     try:child.wait(timeout=5)
     except subprocess.TimeoutExpired:child.kill();child.wait()
     raise
    errors=[line for line in output.splitlines() if line.startswith(('SCRIPT ERROR:','ERROR:','FAIL '))]
    uv_diagnostics=task=='import' and errors and all(line=='ERROR: UVs are required to generate tangents.' for line in errors)
    ok=child.returncode==0 and (not errors or uv_diagnostics)
    print(task.upper(), 'COMPLETED WITH UV DIAGNOSTICS; VERIFY SOURCE' if uv_diagnostics else ('PASS' if ok else 'FAIL'),flush=True)
    for line in output.splitlines():
     if line.startswith('COW MOTION: '):
      data=json.loads(line.removeprefix('COW MOTION: '))
      print('states:',','.join(data['states']),'muzzle max mm:',round(max(v['error'] for v in data['muzzle_contacts'].values())*1000,2))
     elif line.startswith(('DRAFT_YOKE_GAP_M','BULLOCK MUD','COW OCT','COW WORLD MOTION:','COW SOURCE','BREATH GEOMETRY')):print(line)
    if not ok:
     print('\n'.join(errors[:5]));result=1;break
 except subprocess.TimeoutExpired:print('FAIL: check timed out; child stopped and temporary output removed');result=1
 except KeyboardInterrupt:print('Interrupted; child stopped and temporary output removed');result=130
 finally:
  subprocess.run(['python3','tools/maintenance/clean_test_artifacts.py','--apply'],cwd=ROOT,check=False,stdout=subprocess.DEVNULL)
 return result
if __name__=='__main__':raise SystemExit(main())
