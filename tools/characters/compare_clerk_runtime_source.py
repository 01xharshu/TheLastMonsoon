"""Compare native/source surfaces with automatic disposable-geometry cleanup."""
import subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix='tlm-clerk-surface-compare-') as folder:
 subprocess.run(['/Applications/Godot.app/Contents/MacOS/Godot','--headless','--path',str(ROOT),'--script','res://tools/characters/export_clerk_seat_surfaces.gd','--',folder],check=True)
 subprocess.run(['/Applications/Blender.app/Contents/MacOS/Blender','--background','--python-exit-code','1','--python',str(ROOT/'tools/characters/compare_clerk_seat_surfaces.py'),'--',folder],check=True)
