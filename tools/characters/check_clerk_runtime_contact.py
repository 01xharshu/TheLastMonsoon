"""Check actual Godot-imported cloth triangles; dispose all geometry on exit."""
import subprocess,tempfile,sys,os
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
env=os.environ.copy()
if '--candidate' in sys.argv:env['TLM_SEAT_REVIEW_GLB']=str(Path(sys.argv[sys.argv.index('--candidate')+1]).resolve())
with tempfile.TemporaryDirectory(prefix='tlm-clerk-native-contact-') as folder:
 subprocess.run(['/Applications/Godot.app/Contents/MacOS/Godot','--headless','--path',str(ROOT),'--script','res://tools/characters/export_clerk_seat_surfaces.gd','--',folder],check=True,env=env)
 subprocess.run(['/Applications/Blender.app/Contents/MacOS/Blender','--background','--python-exit-code','1','--python',str(ROOT/'tools/characters/audit_clerk_native_contact.py'),'--',folder],check=True,env=env)
