"""Bounded native-pose shirt fitting in a disposable copy of the artisan source.

Requires verified native joint replay. Never changes body vertices or weights.
All changes are sampled and re-exported before production consideration.
"""
import json,sys,tempfile
from pathlib import Path
import bpy
from mathutils import Vector,Matrix
sys.path.insert(0,str(Path(__file__).resolve().parent))
from occupation_native_pose import apply
from occupation_layered_fit import split,surface,pose
from occupation_foundation_cloth import seated_foundation
from river_coherent_cloth import fit_key
from river_upper_self_fit import self_hits
from occupation_cloth_relax import relax
from occupation_fit_constraints import ClothConstraints
root=Path(__file__).resolve().parents[2]
args=sys.argv[sys.argv.index('--')+1:]
folder=Path(args[0]).resolve();output=Path(args[1]).resolve()
assert folder.is_relative_to(Path(tempfile.gettempdir()).resolve())
assert output.is_relative_to(Path(tempfile.gettempdir()).resolve()) and not output.exists()
is_vest = len(args) == 3
source_path = Path(args[2]).resolve() if is_vest else root/'WorkingAssets/NPCs/occupation_wardrobe/artisan/artisan_workwear.blend'
if is_vest and not source_path.is_relative_to(Path(tempfile.gettempdir()).resolve()):
 raise ValueError('Sleeveless fitting requires a disposable source')
bpy.ops.wm.open_mainfile(filepath=str(source_path))
combined=bpy.data.objects['Workwear transfer study'];body=bpy.data.objects['artisan_complete_MakeHuman_body'];rig=body.find_armature()
ids=list(range(int(combined['occupation_upper_vertex_count'])))
shirt=split(combined,ids,'Native shirt fitting',rig)
for key in combined.data.shape_keys.key_blocks:
 target=shirt.data.shape_keys.key_blocks.get(key.name) or shirt.shape_key_add(name=key.name)
 for new,old in enumerate(ids):target.data[new].co=key.data[old].co
original=[point.co.copy() for point in shirt.data.shape_keys.reference_key.data]
paths=[folder/(label+'_16.json') for label in ('idle','walk','repair')]
if is_vest:
 paths += [folder/(label+'.json') for label in ('shape_16','read_16','write_16','walk_03','repair_03','rise_03')]
for iteration in range(1):
 for path in paths:
  data=json.loads(path.read_text());apply(rig,data)
  entry=next(m for m in data['meshes'] if 'cotton shirt' in m['name'])
  keys=shirt.data.shape_keys.key_blocks
  for key in keys:key.value=entry['morphs'].get(key.name,0)
  bpy.context.view_layer.update()
  # Bake the currently active fabric blend into a temporary editable key.
  current=[]
  for index,base in enumerate(keys[0].data):
   point=base.co.copy()
   for key in list(keys)[1:]:point+=(key.data[index].co-base.co)*key.value
   current.append(point)
  values=[key.value for key in keys]
  for key in keys:key.value=0
  work=shirt.shape_key_add(name='Native temporary fit');work.value=1
  for vertex,point in zip(work.data,current):vertex.co=point
  bpy.context.view_layer.update()
  volume,_=surface(body,volume=True)
  volume.strict=False  # Fitting only; reopened acceptance retains strict winding.
  print('OCCUPATION_NATIVE_SHIRT_STAGE',path.stem,'body_fit_start',flush=True)
  _, start_points, faces = surface(shirt, with_faces=True)
  print('OCCUPATION_NATIVE_SHIRT_INITIAL_SELF', path.stem, self_hits(start_points, faces), flush=True)
  def simulation_pose(armature, label):
   if label == 'idle':pose(armature, 'idle')
   else:apply(armature, data)
  if not is_vest:
   seated_foundation(rig, body, shirt, work, simulation_pose, shirt=True)
   _, cloth_points = surface(shirt)
   print('OCCUPATION_NATIVE_SHIRT_SIM_SELF', path.stem, self_hits(cloth_points, faces), flush=True)
  fit_key(rig,shirt,volume,work,reset_key=False,minimum_clearance_m=.003,jacobi=True)
  shirt.data.update();shirt.update_tag(refresh={'DATA'});bpy.context.view_layer.update()
  print('OCCUPATION_NATIVE_SHIRT_STAGE',path.stem,'self_fit_start',flush=True)
  _,posed,faces=surface(shirt,with_faces=True)
  print('OCCUPATION_NATIVE_SHIRT_SELF',path.stem,self_hits(posed,faces),flush=True)
  constraints=ClothConstraints(faces,volume)
  relax(rig,shirt,volume,work,candidate_clear=constraints.body_clear)
  deltas=[vertex.co-current[i] for i,vertex in enumerate(work.data)]
  shirt.shape_key_remove(work)
  for key,value in zip(keys,values):
   for vertex,delta in zip(key.data,deltas):vertex.co+=delta
   key.value=value
  worst=max(range(len(original)), key=lambda i:(keys[0].data[i].co-original[i]).length)
  maximum=(keys[0].data[worst].co-original[worst]).length
  print('OCCUPATION_NATIVE_SHIRT_FIT',iteration,path.stem,'maximum_mm',maximum*1000,'bind_position',tuple(original[worst]),flush=True)
  if maximum>.035:raise RuntimeError('Native shirt fitting exceeds35mm; no candidate saved')
for key in combined.data.shape_keys.key_blocks:
 for new,old in enumerate(ids):key.data[old].co=shirt.data.shape_keys.key_blocks[key.name].data[new].co
for obj in (combined,bpy.data.objects['Street opaque foundation']):
 for key in obj.data.shape_keys.key_blocks:key.value=0
bpy.data.objects.remove(shirt,do_unlink=True)
for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
bpy.context.view_layer.update();bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(output))
print('OCCUPATION_NATIVE_SHIRT_CANDIDATE_SAVED',flush=True)
