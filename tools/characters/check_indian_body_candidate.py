"""Run a native review in a temporary minimal project; never retain captures."""
import argparse, os, re, shutil, subprocess, tempfile, time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
GODOT='/Applications/Godot.app/Contents/MacOS/Godot'
p=argparse.ArgumentParser();p.add_argument('--review-seconds',type=int,default=0);p.add_argument('--lineup',action='store_true');p.add_argument('--identity',default='female_05');p.add_argument('--asset',type=Path);p.add_argument('--fit-foundation-source',type=Path);p.add_argument("--fit-garment",default="Opaque fitted bra and thong foundation");args=p.parse_args()
if args.asset and (args.lineup or not args.asset.is_file()):p.error('--asset requires an existing GLB and a single identity')
with tempfile.TemporaryDirectory(prefix='tlm_indian_candidate_') as folder:
 temp=Path(folder);project=temp/'project';project.mkdir();userdata=Path.home()/'Library/Application Support'/temp.name
 try:
  (project/'project.godot').write_text('[application]\nconfig/name="TLM candidate"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="'+temp.name+'"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
  capture='capture_indian_candidate_lineup.gd' if args.lineup else 'capture_indian_body_candidate.gd'
  candidates=list((ROOT/'characters/npcs/indian_body_candidates').glob('*.glb')) if args.lineup else [ROOT/'characters/npcs/indian_body_candidates'/(args.identity+'.glb')]
  queue=['tools/characters/'+capture]+[str(p.relative_to(ROOT)) for p in candidates];seen=set()
  while queue:
   name=queue.pop()
   if name in seen:continue
   seen.add(name);src=args.asset.resolve() if args.asset and name=='characters/npcs/indian_body_candidates/'+args.identity+'.glb' else ROOT/name
   if not src.is_file():continue
   target=project/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,target)
   if src.suffix in ('.gd','.gdshader','.tscn','.tres'):
    for dep in re.findall(r'res://([^"\s]+)',src.read_text(errors='ignore')):
     if (ROOT/dep).is_file():queue.append(dep)
  env=dict(os.environ,TLM_CANDIDATE_OUTPUT=folder,TLM_CANDIDATE_ID=args.identity)
  for command in ([GODOT,'--headless','--path',str(project),'--editor','--import'],[GODOT,'--path',str(project),'--rendering-driver','metal','--resolution','900x900','--script','res://tools/characters/'+capture]):
   result=subprocess.run(command,env=env,text=True,capture_output=True,timeout=120);output=result.stdout+result.stderr
   errors=result.returncode!=0 or any(mark in output for mark in ('SCRIPT ERROR:','SHADER ERROR:','\nERROR:'))
   print('\n'.join(line for line in output.splitlines() if 'INDIAN_CANDIDATE_REACTIONS' in line or 'INDIAN_RUN_CONTACT' in line or 'INDIAN_SECONDARY_SAFETY' in line or 'INDIAN_CANDIDATE_REALTIME' in line or 'INDIAN_CANDIDATE_LINEUP' in line or 'CANDIDATE_NEAREST_SKIN' in line or 'INDIAN_CANDIDATE_NATIVE' in line or 'ERROR' in line or 'WARNING' in line),flush=True)
   if errors:print(output[-5000:],flush=True);raise SystemExit(1)
  if args.lineup:
   if not (temp/'male_04.png').exists():raise SystemExit('Lineup incomplete')
   if args.review_seconds:print('TEMP REVIEW '+folder,flush=True);time.sleep(min(60,args.review_seconds))
   raise SystemExit(0)
  if not (temp/'front.png').exists():raise SystemExit('No native capture')
  if args.fit_foundation_source:
   fit=subprocess.run(['/Applications/Blender.app/Contents/MacOS/Blender','--background','-noaudio','--python-exit-code','1','--python',str(ROOT/'tools/characters/fit_indian_native_foundation.py'),'--','--identity',args.identity,'--source',str(args.fit_foundation_source),'--poses-dir',folder,'--garment',args.fit_garment],text=True,capture_output=True,timeout=300)
   print('\n'.join(line for line in (fit.stdout+fit.stderr).splitlines() if any(mark in line for mark in ('NATIVE_','RuntimeError','Error:'))),flush=True)
   if fit.returncode:print((fit.stdout+fit.stderr)[-4000:],flush=True)
   raise SystemExit(fit.returncode)
  audit=subprocess.run(['/Applications/Blender.app/Contents/MacOS/Blender','--background','--python-exit-code','1','--python',str(ROOT/'tools/characters/audit_river_native_contact.py'),'--',folder],text=True,capture_output=True,timeout=300 if env.get('TLM_CANDIDATE_REALTIME_WALK')=='1' else 120)
  audit_output=audit.stdout+audit.stderr
  print('\n'.join(line for line in audit_output.splitlines() if 'NATIVE_CONTACT' in line or 'Traceback' in line or 'Error:' in line),flush=True)
  if audit.returncode:
   if args.review_seconds:print('TEMP FAILURE REVIEW '+folder,flush=True);time.sleep(min(60,args.review_seconds))
   raise SystemExit('Runtime body and sari contact check failed')
  if env.get('TLM_CANDIDATE_REALTIME_WALK')=='1' and env.get('TLM_STREET_SECONDARY')=='1':
   coherence=subprocess.run(['/Applications/Blender.app/Contents/MacOS/Blender','--background','-noaudio','--python-exit-code','1','--python',str(ROOT/'tools/characters/audit_indian_secondary_coherence.py'),'--',folder],text=True,capture_output=True,timeout=120)
   print('\n'.join(line for line in (coherence.stdout+coherence.stderr).splitlines() if 'INDIAN_SECONDARY_COHERENCE' in line or 'RuntimeError' in line),flush=True)
   if coherence.returncode:raise SystemExit('Body/foundation secondary coherence failed')
  if args.review_seconds:print('TEMP REVIEW '+folder,flush=True);time.sleep(min(60,args.review_seconds))
 finally:shutil.rmtree(userdata,ignore_errors=True)
