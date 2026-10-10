"""Fit source endpoint corrections against actual native intermediate poses.

The input is disposable native geometry. The complete MPFB body is unchanged.
Every intermediate correction moves all contributing source keys by the same
bind-space displacement, so their weighted mixture receives that displacement.
"""
import bpy,json,sys
from pathlib import Path
from mathutils import Matrix,Vector
from mathutils.kdtree import KDTree
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/characters'))
from river_cloth_correctives import apply_river_pose
from river_coherent_cloth import fit_key
from purpose_cloth_volume import VolumeSurface
from river_asset_export import export_river_asset
folder=Path(sys.argv[sys.argv.index('--')+1])
records=[json.loads(path.read_text()) for path in sorted(folder.glob('river_*.json'))]
if not records:raise RuntimeError('Native intermediate poses required')
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'WorkingAssets/NPCs/river_woman/river_woman_motion.blend'))
bpy.context.preferences.filepaths.save_version=0
rig=bpy.data.objects['village_woman_rig'];body=bpy.data.objects['village_woman_MakeHuman_body']
data=json.loads((ROOT/'WorkingAssets/NPCs/river_woman/poses.json').read_text())
c=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)));inv=c.inverted()
corrections={name:(c@Matrix(rest)@inv).inverted()@rig.data.bones[name].matrix_local for name,rest in data['rest'].items() if name in rig.data.bones}
rig.animation_data_clear();rig.data.pose_position='POSE'
objects={name:bpy.data.objects[name] for name in ['Fitted cotton upper base','Wrapped sari lower drape','Sari lower border','Woven sari pallu over blouse','Opaque fitted bra and thong foundation']}
for obj in objects.values():
 if obj.data.shape_keys is None:continue
 for key in obj.data.shape_keys.key_blocks:key.value=0
# Validate the coordinate conversion before changing any retained source.
first=records[0];apply_river_pose(rig,first['bones'],c,corrections)
transform=rig.matrix_world@c@Matrix(first['skeleton_transform']).inverted()
points=[transform@Vector(point) for entry in first['body'] for point in entry['vertices']]
kd=KDTree(len(points))
for index,point in enumerate(points):kd.insert(point,index)
kd.balance();ev=body.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
error=max(kd.find(ev.matrix_world@vertex.co)[2] for vertex in mesh.vertices);ev.to_mesh_clear()
print('RIVER_NATIVE_ALIGNMENT_M',error,flush=True)
if error>.0001:raise RuntimeError('Source/native pose spaces do not agree')
if '--align-only' in sys.argv:raise SystemExit(0)
for sweep in range(6 if '--foundation-only' in sys.argv or '--finish-upper' in sys.argv else 3):
 changed=0;worst=0.0
 for record in records if sweep%2==0 else reversed(records):
  apply_river_pose(rig,record['bones'],c,corrections)
  transform=rig.matrix_world@c@Matrix(record['skeleton_transform']).inverted()
  points=[];faces=[]
  for entry in record['body']:
   offset=len(points);points.extend(transform@Vector(point) for point in entry['vertices'])
   ids=entry['indices'];reverse=entry.get('winding_sign',1)<0
   faces.extend(tuple(offset+i for i in (reversed(ids[j:j+3]) if reverse else ids[j:j+3])) for j in range(0,len(ids),3))
  tree=VolumeSurface.FromPolygons(points,faces,all_triangles=True,strict='--finish-upper' in sys.argv)
  for entry in record['garments']:
   if '--foundation-only' in sys.argv and entry['name']!='Opaque fitted bra and thong foundation':continue
   obj=objects[entry['name']]
   if obj.data.shape_keys is None or not entry['active_keys']:continue
   basis=obj.data.shape_keys.key_blocks['Basis']
   active=[(obj.data.shape_keys.key_blocks[name],weight) for name,weight in entry['active_keys']]
   if abs(sum(weight for _,weight in active)-1.0)>.0001:raise RuntimeError('Unexpected native morph weight sum')
   before=[vertex.co.copy()+sum(((key.data[index].co-vertex.co)*weight for key,weight in active),Vector()) for index,vertex in enumerate(basis.data)]
   temporary=obj.shape_key_add(name='Temporary native interpolation surface',from_mix=False)
   try:
    for vertex,point in zip(temporary.data,before):vertex.co=point
    temporary.value=1
    shift=fit_key(rig,obj,tree,temporary,reset_key=False)
    temporary.value=0
    if shift>.001:
     changed+=1;worst=max(worst,shift)
     for index,(vertex,point) in enumerate(zip(temporary.data,before)):
      delta=vertex.co-point
      if delta.length>.000001:
       for key,_ in active:key.data[index].co+=delta
   finally:obj.shape_key_remove(temporary)
 print('RIVER_INTERPOLATION_SWEEP',sweep,'changed_surfaces',changed,'max_shift_m',worst,flush=True)
for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
rig.data.pose_position='REST'
export_river_asset(ROOT,rig,body,len(objects['Opaque fitted bra and thong foundation'].data.polygons))
