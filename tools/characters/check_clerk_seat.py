"""Check the isolated clerk seat study; dispose all test output on exit."""
import json,os,subprocess,sys,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def main():
 with tempfile.TemporaryDirectory(prefix='tlm-clerk-check-') as folder:
  subprocess.run([sys.executable,str(ROOT/'tools/characters/audit_clerk_seat_body.py')],check=True)
  report=Path(folder)/'cloth.json'
  command=['/Applications/Blender.app/Contents/MacOS/Blender','--background','--python-exit-code','1','--python',str(ROOT/'tools/characters/audit_purpose_cloth_contact.py'),'--','record_clerk','--source',str(ROOT/'WorkingAssets/NPCs/record_clerk/desk_study/record_clerk_seat.blend'),'--clip','seat_entry','--substeps','2','--output',str(report)]
  result=subprocess.run(command,cwd=ROOT,capture_output=True,text=True)
  if not report.exists():raise RuntimeError(result.stderr+result.stdout[-2000:])
  data=json.loads(report.read_text())
  for name,item in data['actors']['record_clerk'].items():
   print(name+': '+str(round(item['max_penetration_m']*1000,3))+' mm maximum, '+str(item['penetrating_samples'])+' penetrating samples',flush=True)
  env=os.environ.copy();env['TLM_REVIEW_DIR']=folder;env['TLM_REVIEW_REALTIME']='1'
  subprocess.run(['/Applications/Godot.app/Contents/MacOS/Godot','--path',str(ROOT),'--rendering-driver','metal','--script','res://tools/characters/capture_clerk_seat_study.gd'],env=env,check=True)
  print('Seat clothing sample check: '+('PASS' if data['passed'] else 'FAIL')+'; outputs discarded. Full motion/live approval remains separate.')
  return 0 if data['passed'] else 1
if __name__=='__main__':sys.exit(main())
