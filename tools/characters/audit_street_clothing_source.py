"""Source volume audit of actual complete MPFB body under street clothing."""
import bpy,sys,json
from pathlib import Path
from mathutils import Quaternion,Vector,Matrix
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/characters'))
from purpose_cloth_volume import VolumeSurface,inside_surface
slug=sys.argv[sys.argv.index('--identity')+1] if '--identity' in sys.argv else 'female_02'
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'WorkingAssets/NPCs/indian_street_variants'/slug/f'{slug}.blend'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.animation_data_clear();rig.data.pose_position='POSE'
body=next(o for o in bpy.data.objects if o.type=='MESH' and 'MakeHuman_body' in o.name)
clothes=[bpy.data.objects['Street coherent cotton blouse and pallu']]
if 'Street sari back tail' in bpy.data.objects:clothes.append(bpy.data.objects['Street sari back tail'])
for cloth in clothes:cloth.hide_set(False)
for modifier in body.modifiers:
 if modifier.type=='MASK':modifier.show_viewport=False
human_group=body.vertex_groups['body'].index
human={v.index for v in body.data.vertices if any(g.group==human_group and g.weight>.5 for g in v.groups)}
violations=0;samples=0;worst=0.;poses=0
for swing,lean,carrying in [(0.,0.,False),(-.35,0.,False),(-.175,0.,False),(.175,0.,False),(.35,0.,False),(0.,1.,False),(-.175,1.,False),(.175,1.,False),(0.,0.,True),(0.,.7,True),(0.,1.,True)]:
 for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
 for side,sign in [('l',1),('r',-1)]:
  leg=rig.pose.bones.get('thigh_'+side)
  if leg:leg.rotation_mode='QUATERNION';leg.rotation_quaternion=Quaternion(Vector((1,0,0)),swing*sign)
  bone=rig.pose.bones.get('upperarm_'+side)
  if bone:bone.rotation_mode='QUATERNION';bone.rotation_quaternion=Quaternion(Vector((1,0,0)),swing*sign)
  if carrying:
   for part,angle in [('upperarm_',-.8),('lowerarm_',-1.)]:
    arm=rig.pose.bones.get(part+side)
    if arm:
     axis=arm.bone.matrix_local.to_3x3().inverted()@Vector((1,0,0))
     arm.rotation_mode='QUATERNION';arm.rotation_quaternion=Quaternion(axis.normalized(),angle)
 for name,angle in [('spine_01',.24),('spine_02',.20)]:
  bone=rig.pose.bones.get(name)
  if bone:
   axis=bone.bone.matrix_local.to_3x3().inverted()@Vector((1,0,0))
   bone.rotation_mode='QUATERNION';bone.rotation_quaternion=Quaternion(axis.normalized(),angle*lean)
 bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
 skin=body.evaluated_get(dg);mesh=skin.to_mesh();mesh.calc_loop_triangles()
 points=[skin.matrix_world@v.co for v in mesh.vertices]
 faces=[tuple(t.vertices) for t in mesh.loop_triangles if all(i in human for i in t.vertices)]
 volume=VolumeSurface.FromPolygons(points,faces,all_triangles=True,strict=True)
 for cloth in clothes:
  garment=cloth.evaluated_get(dg);fabric=garment.to_mesh();fabric.calc_loop_triangles()
  vertices=[garment.matrix_world@v.co for v in fabric.vertices]
  probes=vertices+[sum((vertices[i] for i in t.vertices),Vector())/3 for t in fabric.loop_triangles]
  for point in probes:
   samples+=1
   if inside_surface(volume,point):
    distance=volume.find_nearest(point)[3]
    if distance>.001:violations+=1;worst=max(worst,distance)
  garment.to_mesh_clear()
 skin.to_mesh_clear();poses+=1
print('STREET_SOURCE_CONTACT',json.dumps(dict(identity=slug,poses=poses,samples=samples,violations=violations,worst_mm=worst*1000,complete_body_vertices=len(body.data.vertices))),flush=True)

if violations:raise RuntimeError("Street garment penetrates the retained MPFB body")
