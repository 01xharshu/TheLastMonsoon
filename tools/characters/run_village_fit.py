"""Run existing village fits with progress and owned-process cleanup."""
import argparse,concurrent.futures,signal,subprocess,threading
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser()
parser.add_argument('roles',nargs='+',choices=['village_farmer','village_woman','village_fruit_seller','village_weaver_assistant'])
parser.add_argument('--export-only',action='store_true')
parser.add_argument('--body-contact-only',action='store_true')
args=parser.parse_args();children=[];lock=threading.Lock()
def cleanup():
 with lock:
  for child in children:
   if child.poll() is None:child.terminate()
  for child in children:
   try:child.wait(timeout=5)
   except subprocess.TimeoutExpired:child.kill();child.wait()
def stop(signum,frame):cleanup();raise SystemExit(128+signum)
signal.signal(signal.SIGTERM,stop)
signal.signal(signal.SIGINT,stop)
def fit(role):
 command=['/Applications/Blender.app/Contents/MacOS/Blender','--background','--python-exit-code','1','--python',str(ROOT/'tools/characters/refine_village_interpolation.py'),'--',role]
 if args.export_only:command.append('--export-only')
 if args.body_contact_only:command.append('--body-contact-only')
 child=subprocess.Popen(command,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True)
 with lock:children.append(child)
 for line in child.stdout:
  if any(word in line for word in ['INTERPOLATION_FIT','Traceback','Error:']):print(role,line.strip(),flush=True)
 code=child.wait();print('VILLAGE_FIT_EXIT',role,code,flush=True);return code
try:
 with concurrent.futures.ThreadPoolExecutor(max_workers=min(4,len(args.roles))) as pool:
  codes=list(pool.map(fit,args.roles))
 raise SystemExit(0 if all(code==0 for code in codes) else 1)
finally:cleanup()
