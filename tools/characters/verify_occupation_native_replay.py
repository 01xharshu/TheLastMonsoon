"""Verify actual Godot joint replay against unchanged Blender body geometry."""
import json,os,sys,tempfile
from pathlib import Path
import bpy
from mathutils import Vector,Matrix
from mathutils.kdtree import KDTree
from math import pi
sys.path.insert(0,str(Path(__file__).resolve().parent))
from occupation_native_pose import apply
root=Path(__file__).resolve().parents[2]
folder=Path(sys.argv[sys.argv.index('--')+1]).resolve()
assert folder.is_relative_to(Path(tempfile.gettempdir()).resolve())
bpy.ops.wm.open_mainfile(filepath=str(root/'WorkingAssets/NPCs/occupation_wardrobe/artisan/artisan_workwear.blend'))
body=bpy.data.objects['artisan_complete_MakeHuman_body'];rig=body.find_armature()
conversion=Matrix.Rotation(pi/2,4,'X')
failed=False
tolerance = .00015 if os.environ.get('TLM_OCCUPATION_MOVING_WALK') == '1' else .0001
for path in sorted(folder.glob('*.json')):
 if not path.stem.endswith(('_03','_08','_16')):continue
 data=json.loads(path.read_text());label=path.stem;apply(rig,data)
 entry=next(m for m in data['meshes'] if 'complete_MakeHuman_body' in m['name'])
 for key in body.data.shape_keys.key_blocks:key.value=entry['morphs'].get(key.name,0)
 bpy.context.view_layer.update()
 ev=body.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
 points=[ev.matrix_world@v.co for v in mesh.vertices]
 native=[conversion@Vector(p) for p in entry['vertices']]
 tree=KDTree(len(points))
 for i,p in enumerate(points):tree.insert(p,i)
 tree.balance();error=max(tree.find(conversion@Vector(p))[2] for p in entry['vertices'])
 print('OCCUPATION_REPLAY_BODY_MM',label,error*1000,flush=True)
 ev.to_mesh_clear()
 # Diagnostic pass collects all poses before enforcing parity.
 # Replay tolerance accounts for import quantization and stays below the native probe gate.
 if error>tolerance:
  failed=True
  print('OCCUPATION_REPLAY_REJECTED',label,flush=True)

if failed:raise RuntimeError('Native bone replay disagrees; do not fit against it')
