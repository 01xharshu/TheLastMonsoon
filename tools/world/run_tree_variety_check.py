"""Native tree variety/contact review, isolated saves and disposable captures/logs."""
from pathlib import Path
import argparse,os,shutil,subprocess,tempfile,time,threading,signal
from run_performance_checks import other_native_jobs
ROOT=Path(__file__).resolve().parents[2]
GODOT='/Applications/Godot.app/Contents/MacOS/Godot'
def main():
 for sig in (signal.SIGINT,signal.SIGTERM):signal.signal(sig,lambda *_: (_ for _ in ()).throw(KeyboardInterrupt()))
 parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--review',action='store_true');parser.add_argument('--world',action='store_true');args=parser.parse_args()
 deadline=time.monotonic()+240
 announced=False
 while other_native_jobs():
  if not announced:print('Waiting for the other native renderer; no other job will be stopped.',flush=True);announced=True
  if time.monotonic()>deadline:return 2
  time.sleep(2)
 with tempfile.TemporaryDirectory(prefix='tlm-tree-variety-') as folder:
  directory=Path(folder);project=directory/'project';project.mkdir();userdata=Path.home()/'Library/Application Support'/directory.name
  try:
   for entry in ROOT.iterdir():
    if entry.name not in ('.git','project.godot'):(project/entry.name).symlink_to(entry,target_is_directory=entry.is_dir())
   text=(ROOT/'project.godot').read_text().replace('[application]','[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="'+directory.name+'"',1);(project/'project.godot').write_text(text)
   env=os.environ.copy()
   if args.review or args.world:env['TLM_TREE_REVIEW']=folder;print('TREE REVIEW DIR',folder,flush=True)
   if args.world:env['TLM_TREE_CAPTURE_REFERENCE']='1'
   log=directory/'engine.log'
   process=subprocess.Popen([GODOT,'--path',str(project),'--rendering-driver','metal','--resolution','1280x720','--log-file',str(log),'--script','res://tools/world/validate_tree_variety_world.gd' if args.world else 'res://tools/world/validate_tree_variety.gd'],env=env)
   overlap=threading.Event();stop=threading.Event()
   def watch():
    while not stop.wait(2):
     if other_native_jobs(process.pid):
      if not args.world:overlap.set();process.terminate();return
      print("Pausing owned world review for another renderer; timing windows will restart.",flush=True)
      epoch=directory/'native_epoch';epoch.write_text(str(time.monotonic_ns()))
      process.send_signal(signal.SIGSTOP)
      while not stop.wait(2) and other_native_jobs(process.pid):pass
      epoch.write_text(str(time.monotonic_ns()));process.send_signal(signal.SIGCONT)
      print("Resuming owned world review after renderer became free.",flush=True)
   watcher=threading.Thread(target=watch,daemon=True);watcher.start()
   try:code=process.wait(timeout=600)
   finally:
    stop.set()
    if process.poll() is None:process.send_signal(signal.SIGCONT);process.terminate();process.wait(timeout=20)
    watcher.join(timeout=3)
   if overlap.is_set():print("Discarded overlapping native run; owned renderer stopped.",flush=True);return 2
   content=log.read_text();failed=any(word in content for word in ('SCRIPT ERROR:','SHADER ERROR:','ERROR:'))
   return code or int(failed or 'TREE VARIETY: PASS' not in content)
  finally:shutil.rmtree(userdata,ignore_errors=True)
if __name__=='__main__':raise SystemExit(main())
