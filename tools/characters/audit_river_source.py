"""Inspect fitted source contact over the unchanged MPFB body; writes no test files."""
import bpy,json,sys,hashlib,struct
from pathlib import Path
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/characters'))
from purpose_cloth_volume import inside_surface,VolumeSurface
from river_cloth_correctives import apply_river_pose
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'WorkingAssets/NPCs/river_woman/river_woman_motion.blend'))
rig=bpy.data.objects['village_woman_rig'];body=bpy.data.objects['village_woman_MakeHuman_body']
data=json.loads((ROOT/'WorkingAssets/NPCs/river_woman/poses.json').read_text())
c=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)));inv=c.inverted()
correction={n:(c@Matrix(rest)@inv).inverted()@rig.data.bones[n].matrix_local for n,rest in data['rest'].items() if n in rig.data.bones}
rig.animation_data_clear();rig.data.pose_position='REST'
bpy.context.view_layer.update();ev=body.evaluated_get(bpy.context.evaluated_depsgraph_get());rest_mesh=ev.to_mesh();rest_mesh.calc_loop_triangles()
body_triangles=[tuple(triangle.vertices) for triangle in rest_mesh.loop_triangles];ev.to_mesh_clear()
rig.data.pose_position='POSE'
names=['Fitted cotton upper base','Wrapped sari lower drape','Sari lower border','Woven sari pallu over blouse','Opaque fitted bra and thong foundation']
def body_identity(obj):
 digest=hashlib.sha256()
 for vertex in obj.data.vertices:digest.update(struct.pack('<3f',*vertex.co))
 return (digest.hexdigest(),[(key.name,key.value) for key in obj.data.shape_keys.key_blocks],len(obj.data.polygons))
identity=body_identity(body)
violations=0
selected={pose["key"] for pose in data["poses"] if ("slope" not in pose and any(abs(pose["time"]-time)<.001 for time in [17.2,29.0,43.0,52.25])) or pose["key"] in {"River walk 0 00","River walk 2 04","River walk 4 16"}}
for pose in data["poses"]:
 if pose["key"] not in selected:continue
 apply_river_pose(rig,pose['bones'],c,correction)
 for name in names:
  obj=bpy.data.objects[name]
  for key in obj.data.shape_keys.key_blocks:key.value=1.0 if key.name==pose['key'] else 0.0
 bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();ev=body.evaluated_get(dg);mesh=ev.to_mesh()
 print("RIVER_POSE_MATRIX_ERROR",max(max(abs(v) for row in (bone.matrix-(c@Matrix(pose["bones"][bone.name])@inv@correction[bone.name])) for v in row) for bone in rig.pose.bones if bone.name in pose["bones"]),flush=True)
 tree=VolumeSurface.FromPolygons([ev.matrix_world@v.co for v in mesh.vertices],body_triangles,all_triangles=True);ev.to_mesh_clear()
 result={}
 for name in names:
  obj=bpy.data.objects[name];ev=obj.evaluated_get(dg);mesh=ev.to_mesh();points=[ev.matrix_world@v.co for v in mesh.vertices]
  points += [sum((points[i] for i in p.vertices),Vector())/len(p.vertices) for p in mesh.polygons]
  bad=0;worst=0
  for point in points:
   near,normal,_,dist=tree.find_nearest(point)
   if dist>.002 and inside_surface(tree,point):bad+=1;worst=max(worst,dist)
  result[name]=[bad,round(worst*1000,3)];violations+=bad
  ev.to_mesh_clear()
 print('RIVER_SOURCE_CONTACT',pose['key'],json.dumps(result),flush=True)

if any(modifier.show_viewport for modifier in body.modifiers if modifier.type=='MASK' and modifier.name!='Hide helpers'):
 raise RuntimeError('Clothing mask enabled on full human body')
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'WorkingAssets/NPCs/village_woman/village_woman_motion_candidate.blend'))
if body_identity(bpy.data.objects['village_woman_MakeHuman_body'])!=identity:
 raise RuntimeError('River body changed from authoritative MPFB donor')
print('RIVER_BODY_IDENTITY PASS',flush=True)
raise SystemExit(1 if violations else 0)
