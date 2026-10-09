"""Native Godot contact check; cleans disposable output and own children on exit."""
import subprocess,tempfile,signal,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def stop(signum,frame):raise SystemExit(128+signum)
signal.signal(signal.SIGTERM,stop)
def run(command,timeout):
 process=subprocess.Popen(command)
 try:return process.wait(timeout=timeout)
 finally:
  if process.poll() is None:
   process.terminate()
   try:process.wait(timeout=5)
   except subprocess.TimeoutExpired:process.kill();process.wait()
with tempfile.TemporaryDirectory(prefix='tlm-village-contact-') as folder:
 code=run(['/Applications/Godot.app/Contents/MacOS/Godot','--headless','--path',str(ROOT),'--script','res://tools/characters/export_village_test_surfaces.gd','--',folder,*sys.argv[1:]],120)
 if code:raise SystemExit(code)
 raise SystemExit(run(['/Applications/Blender.app/Contents/MacOS/Blender','--background','--python-exit-code','1','--python',str(ROOT/'tools/characters/audit_village_test_surfaces.py'),'--',folder],180))
