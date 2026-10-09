"""Rebuild male mixed-pose cloth fits using disposable native samples."""
import subprocess,tempfile,signal
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
active=None
def stop(signum,frame):raise SystemExit(128+signum)
signal.signal(signal.SIGTERM,stop)
signal.signal(signal.SIGINT,stop)
def run(command,timeout):
 global active
 active=subprocess.Popen(command,cwd=ROOT)
 try:
  code=active.wait(timeout=timeout)
  if code:raise SystemExit(code)
 finally:
  if active.poll() is None:
   active.terminate()
   try:active.wait(timeout=5)
   except subprocess.TimeoutExpired:active.kill();active.wait()
with tempfile.TemporaryDirectory(prefix='tlm-village-transition-') as folder:
 run(['/Applications/Godot.app/Contents/MacOS/Godot','--headless','--path',str(ROOT),'--script','res://tools/characters/export_village_test_surfaces.gd','--',folder,'village_farmer','village_weaver_assistant'],120)
 run(['/Applications/Blender.app/Contents/MacOS/Blender','--background','--python-exit-code','1','--python',str(ROOT/'tools/characters/refine_village_transitions.py'),'--',folder],1800)
