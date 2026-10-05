"""Isolated MPFB passenger donor: preserve body, fit cloth seated corrective."""
import bpy, sys, json, math
from pathlib import Path
from mathutils import Vector, Quaternion, Matrix
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/characters'))
from whole_body_contract import retain_complete_body
src=ROOT/'WorkingAssets/NPCs/village_farmer/village_farmer_motion_candidate.blend'
out=ROOT/'WorkingAssets/NPCs/errand_passenger';out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(src))
rig=bpy.data.objects['village_farmer_rig'];body=bpy.data.objects['village_farmer_MakeHuman_body']
retain_complete_body(body);rig.data.pose_position='REST';bpy.context.view_layer.update()
# Bake supported garment masks and helper exclusion; retain original full source in donor.
deps=bpy.context.evaluated_depsgraph_get()
for obj in list(bpy.data.objects):
 if obj.type!='MESH':continue
 mesh=bpy.data.meshes.new_from_object(obj.evaluated_get(deps),preserve_all_data_layers=True,depsgraph=deps)
 obj.data=mesh
 for modifier in list(obj.modifiers):
  if modifier.type!='ARMATURE':obj.modifiers.remove(modifier)
  else:modifier.use_deform_preserve_volume=False
body_count=len(body.data.vertices)
# Opaque fitted foundation made from the donor surface, never removed from the body.
selected=[p for p in body.data.polygons if all(.44 < body.data.vertices[i].co.z < .96 for i in p.vertices)]
indices=sorted({i for p in selected for i in p.vertices});remap={v:i for i,v in enumerate(indices)}
mesh=bpy.data.meshes.new('Adult cotton foundation');mesh.from_pydata([body.data.vertices[i].co+body.data.vertices[i].normal*.007 for i in indices],[],[tuple(remap[i] for i in p.vertices) for p in selected])
foundation=bpy.data.objects.new('Opaque adult foundation shorts',mesh);bpy.context.collection.objects.link(foundation)
mat=bpy.data.materials.new('Opaque unbleached foundation cotton');mat.diffuse_color=(.40,.35,.25,1);mat.use_nodes=True
mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.40,.35,.25,1);mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.95
mesh.materials.append(mat)
for group in body.vertex_groups:foundation.vertex_groups.new(name=group.name)
for old,new in remap.items():
 for g in body.data.vertices[old].groups:foundation.vertex_groups[g.group].add([new],g.weight,'REPLACE')
foundation.parent=rig;foundation.matrix_world=body.matrix_world.copy()
modifier=foundation.modifiers.new('Foundation skin','ARMATURE');modifier.object=rig
# Increase lower-cloth resolution; fit the garment, never cut the body.
rest_body=body.evaluated_get(bpy.context.evaluated_depsgraph_get())
rest_bvh=BVHTree.FromPolygons([rest_body.matrix_world@v.co for v in rest_body.data.vertices],[list(p.vertices) for p in rest_body.data.polygons])
for name in ['Kurta loose lower panel','Knee length wrapped dhoti','Dhoti woven border']:
 obj=bpy.data.objects[name];bpy.context.view_layer.objects.active=obj
 modifier=obj.modifiers.new('Smooth garment resolution','SUBSURF');modifier.levels=2
 bpy.ops.object.modifier_apply(modifier=modifier.name)
 for vertex in obj.data.vertices:
  point=obj.matrix_world@vertex.co;near,normal,_,_=rest_bvh.find_nearest(point)
  if near is not None and (point-near).dot(normal)<.014:
   vertex.co=obj.matrix_world.inverted()@(near+normal*.014)
bpy.context.view_layer.update()
# Pose exactly the runtime's seated hip/knee bend, leaving donor actions intact.
rig.data.pose_position='POSE';rig.animation_data.action=None
base={p.name:p.rotation_quaternion.copy() for p in rig.pose.bones}
for side in ['l','r']:
 for prefix,angle in [('thigh_',-1.5),('calf_',1.5)]:
  bone=rig.pose.bones[prefix+side];bone.rotation_mode='QUATERNION'
  axis=bone.bone.matrix_local.to_3x3().inverted()@Vector((1,0,0))
  bone.rotation_quaternion=base[bone.name]@Quaternion(axis,angle)
bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get()
eval_body=body.evaluated_get(deps)
verts=[eval_body.matrix_world@v.co for v in eval_body.data.vertices]
bvh=BVHTree.FromPolygons(verts,[list(p.vertices) for p in eval_body.data.polygons])
pelvis=rig.matrix_world@rig.pose.bones['pelvis'].head
report=[]
for name in ['Kurta loose lower panel','Knee length wrapped dhoti','Dhoti woven border']:
 obj=bpy.data.objects[name];obj.shape_key_add(name='Basis');key=obj.shape_key_add(name='PassengerSeatedClearance')
 posed=obj.evaluated_get(deps);maximum=0;modified=0
 for v in obj.data.vertices:
  p=posed.matrix_world@posed.data.vertices[v.index].co;target=p.copy()
  near,normal,_,distance=bvh.find_nearest(p)
  if near is not None and (p-near).dot(normal)<.014:target=near+normal*.014
  # Cloth on the bench stays on top of it, rather than passing through its plank.
  if target.y>-.20 and abs(target.x)<.75 and target.z<pelvis.z+.025:target.z=pelvis.z+.025
  for correction in range(16):
   near,normal,_,_=bvh.find_nearest(target)
   if near is None or (target-near).dot(normal)>=.014:break
   target=near+normal*.015
  transform=Matrix(((0,0,0,0),)*4)
  total=0
  for g in v.groups:
   bone=rig.pose.bones.get(obj.vertex_groups[g.group].name)
   if bone:
    transform+=(rig.matrix_world@bone.matrix@bone.bone.matrix_local.inverted()@rig.matrix_world.inverted())*g.weight;total+=g.weight
  if total>0:
   transform *= 1.0/total
   local=obj.matrix_world.inverted()@(transform.inverted_safe()@target)
   displacement=(local-v.co).length
   if displacement>.0001:key.data[v.index].co=local;modified+=1;maximum=max(maximum,displacement)
 report.append({'garment':name,'changed_vertices':modified,'max_corrective_m':maximum})
for bone in rig.pose.bones:bone.rotation_quaternion=base[bone.name]
rig.data.pose_position='REST';bpy.context.view_layer.update()
bpy.context.preferences.filepaths.save_version=0
source=out/'errand_passenger_mpfb.blend';bpy.ops.wm.save_as_mainfile(filepath=str(source))
rig.data.pose_position='POSE';bpy.context.scene.frame_set(1)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for obj in bpy.data.objects:
 if obj.type=='MESH':obj.select_set(True)
bpy.context.view_layer.objects.active=rig
runtime=ROOT/'characters/npcs/motion/errand_passenger/errand_passenger.glb'
runtime.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(runtime),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_cameras=False,export_lights=False,export_skins=True,export_morph=True,export_apply=False)
(out/'manifest.json').write_text(json.dumps({'source_donor':str(src.relative_to(ROOT)),'source':str(source.relative_to(ROOT)),'complete_body_vertices':body_count,'body_masks_disabled':True,'opaque_foundation':foundation.name,'correctives':report,'status':'CONTACT_CLOTH_CANDIDATE'},indent=2)+'\n')
print('PASSENGER_CLOTH',json.dumps(report))
