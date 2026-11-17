"""Disposable complete-body export, actual occupation graph and contact gate.

--fit-shirt tests a bounded temporary shirt refit after native replay parity.
Generated GLB/JSON and private userdata are always removed on exit.
"""
import argparse
import os
import shutil
import subprocess
import tempfile
import time
import threading
from pathlib import Path
from private_godot_project import private_project

ROOT=Path(__file__).resolve().parents[2]
BLENDER='/Applications/Blender.app/Contents/MacOS/Blender'
GODOT='/Applications/Godot.app/Contents/MacOS/Godot'
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--fit-shirt',action='store_true')
parser.add_argument('--review',action='store_true',help='Native temporary views after geometry gates; review_done file ends hold')
parser.add_argument('--diagnostic-review',action='store_true',help='Review rejected input before fitting; grants no acceptance')
parser.add_argument('--cut-vest',action='store_true',help='Evaluate a disposable sleeveless construction trial')
parser.add_argument('--transport-seat',action='store_true',help='Test transport of fitted lower layers to actual seat IK')
parser.add_argument('--retain-editable',action='store_true',help='Keep the editable candidate after fitting, even if motion review is pending')
parser.add_argument('--reverse-walk',type=Path,help='Test a reverse stride key on a retained editable candidate')
parser.add_argument('--fit-motion',action='store_true',help='Fit sit, rise and reverse stride using --reverse-walk candidate input')
parser.add_argument('--all-samples',action='store_true',help='Audit every captured pose, including between the focal samples')
parser.add_argument('--moving-walk',action='store_true',help='Activate real planted-foot gait with root travel')
parser.add_argument('--repair-frames',nargs='+',help='Refine listed native frames after fitting the basic motion keys')
parser.add_argument('--seat-height',type=float,help='Match a specific workplace seat height in meters')
parser.add_argument('--refit-seat',type=Path,help='Transport a settled native candidate to a different workplace height')
parser.add_argument('--candidate',type=Path,help='Validate and review an existing editable candidate without refitting')
parser.add_argument('--seat-body-only',action='store_true',help='Compare body contacts at reference and workplace seats')
parser.add_argument('--seat-forward',type=float,help='Test a different forward ankle target at the selected seat')
parser.add_argument('--seat-half-width',type=float,help='Test a different lateral ankle target at the selected seat')
parser.add_argument('--seat-yaw',type=float,help='Footprint rotation in degrees')
args=parser.parse_args()
seat_options = {
 'TLM_OCCUPATION_SEAT_FORWARD':args.seat_forward,
 'TLM_OCCUPATION_SEAT_HALF_WIDTH':args.seat_half_width,
}
for key,value in seat_options.items():
 if value is not None:
  if not .10<=value<=.75:parser.error('Seat ankle targets must be between 0.10 and 0.75 meters')
  os.environ[key]=str(value)
seat_options['TLM_OCCUPATION_SEAT_YAW']=args.seat_yaw
if args.seat_yaw is not None:os.environ['TLM_OCCUPATION_SEAT_YAW']=str(args.seat_yaw)
if args.seat_body_only and not args.refit_seat:
 parser.error('--seat-body-only requires --refit-seat')
if args.candidate and any((args.refit_seat,args.reverse_walk,args.cut_vest,args.fit_shirt,args.transport_seat,args.fit_motion)):
 parser.error('--candidate is for validation only')
if args.refit_seat and (args.seat_height is None or args.cut_vest or args.reverse_walk or args.fit_shirt or args.transport_seat):
 parser.error('--refit-seat takes --seat-height and a retained candidate, without other fitting modes')
if args.seat_height is not None:
 if not .20 <= args.seat_height <= .60:
  parser.error('Seat height must be between 0.20 and 0.60 meters')
 os.environ['TLM_OCCUPATION_SEAT_HEIGHT']=str(args.seat_height)
if args.repair_frames and not args.fit_motion:
 parser.error('--repair-frames requires --fit-motion')
if args.moving_walk:
 os.environ['TLM_OCCUPATION_MOVING_WALK']='1'
if args.fit_motion and not args.reverse_walk:
 parser.error('--fit-motion requires a retained source with --reverse-walk')
if args.reverse_walk and (args.cut_vest or args.fit_shirt or args.transport_seat):
 parser.error('Use --reverse-walk by itself against an editable candidate')
if args.retain_editable and args.seat_height is not None:
 parser.error('Keep workplace-height trials disposable until they pass')
if args.retain_editable and not (args.fit_motion or (args.cut_vest and args.fit_shirt and args.transport_seat)):
 parser.error('--retain-editable requires the complete sleeveless fitting pipeline')

def wait_renderer():
 deadline=time.monotonic()+600;notice=0
 while True:
  lines=subprocess.check_output(['ps','-axo','command='],text=True).splitlines()
  busy=any(x.startswith(BLENDER) or (x.startswith(GODOT) and '--headless' not in x and '--editor' not in x) for x in lines)
  if not busy:return
  if time.monotonic()>deadline:raise RuntimeError('Renderer queue remained occupied; no other process interrupted')
  if time.monotonic()>notice:print('OCCUPATION_WAIT other renderer active',flush=True);notice=time.monotonic()+45
  time.sleep(2)

def run(command):
 output=[]
 with subprocess.Popen(command,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,bufsize=1) as process:
  watchdog=threading.Timer(600,process.kill);watchdog.start()
  try:
   for line in process.stdout:
    output.append(line)
    if any(tag in line for tag in ('OCCUPATION_', 'RuntimeError', 'Error:', 'SCRIPT ERROR', 'Traceback')):
     print(line.rstrip(),flush=True)
   result=process.wait(timeout=10)
  except BaseException:
   process.kill();process.wait();raise
  finally:watchdog.cancel()
 if result:raise RuntimeError('Occupation check failed: '+str(command)+'; '+''.join([line for line in output if 'OCCUPATION_' in line or line.startswith('RuntimeError:')][-7:]).replace('\n',' '))

def blender(script,*arguments):
 wait_renderer()
 run([BLENDER,'--background','--python-exit-code','1','--python','tools/characters/'+script,'--',*map(str,arguments)])

status='FAIL';detail='interrupted'
try:
 with tempfile.TemporaryDirectory(prefix='tlm-occupation-native-') as directory:
  folder=Path(directory);glb=folder/'candidate.glb'
  if args.candidate:
   blender('export_occupation_workwear.py','--source',args.candidate,'--output',glb)
  elif args.refit_seat:
   seat_source=folder/'seat_source.blend'
   shutil.copyfile(args.refit_seat,seat_source)
   blender('export_occupation_workwear.py','--source',seat_source,'--output',glb)
  elif args.reverse_walk:
   reverse=folder/'reverse.blend'
   blender('add_occupation_reverse_walk.py',args.reverse_walk,reverse)
   blender('export_occupation_workwear.py','--source',reverse,'--output',glb)
  elif args.cut_vest:
   cut=folder/'vest.blend'
   blender('cut_occupation_vest_trial.py',cut)
   blender('export_occupation_workwear.py','--source',cut,'--output',glb)
  else:
   blender('export_occupation_workwear.py','--output',glb)
  with private_project(ROOT,folder) as project:
   def sample(path,output):
    run([GODOT,'--headless','--path',str(project),'--script','res://tools/characters/export_occupation_native_surfaces.gd','--',str(path),str(output)])
   sample(glb,folder)
   if args.refit_seat:
    reference=folder/'reference';reference.mkdir()
    os.environ['TLM_OCCUPATION_SEAT_HEIGHT']='0.45'
    for key in seat_options:os.environ.pop(key,None)
    try:sample(glb,reference)
    finally:
     os.environ['TLM_OCCUPATION_SEAT_HEIGHT']=str(args.seat_height)
     for key,value in seat_options.items():
      if value is not None:os.environ[key]=str(value)
   if args.seat_body_only:
    blender('audit_occupation_seat_body.py',seat_source,reference/'repair_16.json',folder/'repair_16.json')
    raise SystemExit(0)
   if args.diagnostic_review:
    wait_renderer()
    run([GODOT,'--rendering-driver','metal','--path',str(project),'--script','res://tools/characters/capture_occupation_workwear.gd','--',str(glb),str(folder)])
    print('OCCUPATION_DIAGNOSTIC_DIRECTORY',folder,flush=True)
    deadline=time.monotonic()+180
    while not (folder/'review_done').exists() and time.monotonic()<deadline:time.sleep(1)
   blender('verify_occupation_native_replay.py',folder)
   review_asset=glb
   candidate_source=cut if args.cut_vest else None
   if args.fit_shirt:
    fitted=folder/'native_shirt.blend'
    blender('fit_occupation_native_shirt.py',folder,fitted,*([candidate_source] if candidate_source else []))
    blender('audit_occupation_workwear_study.py',fitted)
    candidate_source=fitted
   if args.transport_seat:
    transported=folder/'transported.blend'
    blender('transport_occupation_seated.py',folder/'repair_16.json',transported,*([candidate_source] if candidate_source else []))
    candidate_source=transported
   if args.refit_seat:
    candidate_source=folder/'workplace.blend'
    blender('transport_occupation_seated.py',folder/'repair_16.json',candidate_source,seat_source,reference/'repair_16.json')
   if args.fit_motion:
    candidate_source=folder/'motion.blend'
    blender('fit_occupation_motion_keys.py',reverse,folder,candidate_source)
   if args.fit_shirt or args.transport_seat or args.fit_motion or args.refit_seat:
    review_asset=folder/'refitted.glb'
    blender('export_occupation_workwear.py','--source',candidate_source,'--output',review_asset)
    output=folder/'refitted';output.mkdir();sample(review_asset,output)
   else:output=folder
   if args.repair_frames:
    refined=folder/'refined.blend'
    blender('fit_occupation_motion_keys.py',candidate_source,output,refined,*args.repair_frames)
    candidate_source=refined
    review_asset=folder/'refined.glb'
    blender('export_occupation_workwear.py','--source',candidate_source,'--output',review_asset)
    output=folder/'refined';output.mkdir();sample(review_asset,output)
   if args.retain_editable:
    blender('audit_occupation_native_surfaces.py',output,*([] if args.fit_motion else ['--steady-only']))
    name='artisan_motion_workwear.blend' if args.fit_motion else 'artisan_sleeveless_workwear.blend'
    destination=ROOT/'WorkingAssets/NPCs/occupation_wardrobe/artisan'/name
    with tempfile.NamedTemporaryFile(dir=destination.parent, prefix='.artisan-candidate-', delete=False) as staged:
     staged_path=Path(staged.name)
    try:
     shutil.copyfile(candidate_source,staged_path)
     staged_path.replace(destination)
    finally:
     staged_path.unlink(missing_ok=True)
    print('OCCUPATION_EDITABLE_CANDIDATE',destination,flush=True)
   if args.review:
    wait_renderer()
    run([GODOT,'--rendering-driver','metal','--path',str(project),'--script','res://tools/characters/capture_occupation_workwear.gd','--',str(review_asset),str(output)])
    print('OCCUPATION_REVIEW_DIRECTORY',output,flush=True)
    deadline=time.monotonic()+180
    while not (output/'review_done').exists() and time.monotonic()<deadline:time.sleep(1)
   blender('audit_occupation_native_surfaces.py',output,*(['--all-samples'] if args.all_samples else []))
  status='PASS';detail='native export/replay/contact gate passed; full rendered motion still pending'
except SystemExit as exit_request:
 if exit_request.code==0 and args.seat_body_only:
  status='PASS';detail='seat body diagnostic sampled, garment acceptance still pending'
 raise
except BaseException as error:
 detail=str(error)
 raise
finally:
 with (ROOT/'CODEX_HANDOFF.md').open('a') as ledger:
  ledger.write('\n'+time.strftime('%Y-%m-%dT%H:%M:%S%z')+' — Occupation native runner '+status+': '+detail+'. Temporary outputs/private userdata cleaned. Scope IN_PROGRESS.\n')
