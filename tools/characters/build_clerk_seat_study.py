"""Isolated full-body clerk seat entry; never replaces the live clerk export."""
import bpy,sys,json,math,hashlib
from pathlib import Path
from mathutils import Vector,Quaternion
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'tools/characters'))
from purpose_local_cloth import _fit_pose
from purpose_gait import normalize_animation_times
out=ROOT/'WorkingAssets/NPCs/record_clerk/desk_study';out.mkdir(parents=True,exist_ok=True)
source=ROOT/'WorkingAssets/NPCs/record_clerk/record_clerk_motion_candidate.blend'
bpy.ops.wm.open_mainfile(filepath=str(source));rig=bpy.data.objects['record_clerk_rig'];body=bpy.data.objects['record_clerk_MakeHuman_body']
rig.animation_data.action=bpy.data.actions['idle'];bpy.context.scene.frame_set(1);bpy.context.view_layer.update()
base={p.name:p.rotation_quaternion.copy() for p in rig.pose.bones};root_base=rig.pose.bones['Root'].location.copy()
# A sleeveless waistcoat follows the torso; arm weights must not drag its
# armhole into the sleeve when the clerk reaches across the desk.
vest=bpy.data.objects['Clerk buttoned sleeveless waistcoat']
arm_groups={g.index for g in vest.vertex_groups if g.name.startswith(('upperarm_','lowerarm_','hand_','thumb_','index_','middle_','ring_','pinky_'))}
torso=vest.vertex_groups.get('spine_03') or vest.vertex_groups.new(name='spine_03')
for vertex in vest.data.vertices:
 weight=sum(g.weight for g in vertex.groups if g.group in arm_groups)
 for index in arm_groups:vest.vertex_groups[index].remove([vertex.index])
 if weight:torso.add([vertex.index],weight,'ADD')

for obj in bpy.data.objects:
 if obj.type=='MESH' and obj.data.shape_keys:
  for key in obj.data.shape_keys.key_blocks:
   if key.name.startswith(('Walk cloth ','Seat cloth ')):key.value=0
clip=bpy.data.actions.new('seat_entry');rig.animation_data.action=clip
constraints=[];helpers=[];targets={};captured=[]
for side,sign in [('l',1),('r',-1)]:
 goal=bpy.data.objects.new('Desk hand target '+side,None);bpy.context.collection.objects.link(goal);helpers.append(goal)
 pole=bpy.data.objects.new('Desk elbow pole '+side,None);bpy.context.collection.objects.link(pole);pole.location=(sign*.45,-.15,.62);helpers.append(pole)
 constraint=rig.pose.bones['lowerarm_'+side].constraints.new('IK');constraint.target=goal;constraint.pole_target=pole;constraint.chain_count=2;constraint.use_tail=True;constraint.influence=1.0 if '--reach' in sys.argv else 0.0;constraints.append(constraint)
 targets[side]=(goal,rig.matrix_world@rig.pose.bones['hand_'+side].head.copy())
for frame in range(1,62):
 t=(frame-1)/60;blend=t*t*(3-2*t)
 for bone in rig.pose.bones:
  bone.rotation_quaternion=base[bone.name]
  angle=(-1.45 if bone.name.startswith('thigh_') else 1.45 if bone.name.startswith('calf_') else .06 if bone.name=='spine_02' else 0)*blend
  if angle:
   axis=bone.bone.matrix_local.to_3x3().inverted()@Vector((1,0,0));bone.rotation_quaternion=base[bone.name]@Quaternion(axis,angle)
 root=rig.pose.bones['Root'];root.location=root_base.copy();bpy.context.view_layer.update()
 dg=bpy.context.evaluated_depsgraph_get();ev=body.evaluated_get(dg);mesh=ev.to_mesh()
 # Maintain actual full-body floor support while the legs bend.
 lowest=min((ev.matrix_world@v.co).z for v in mesh.vertices);ev.to_mesh_clear();root.location.z-=lowest
 bpy.context.view_layer.update()
 for side,sign in [('l',1),('r',-1)]:
  goal,rest=targets[side]
  reach=max(0,min(1,(t-.35)/.65));reach=reach*reach*(3-2*reach)
  target=Vector((sign*.18,-.44,.88 if side=='r' else .82))
  goal.location=(rest+Vector((0,0,root.location.z-root_base.z))).lerp(target,reach)
 bpy.context.view_layer.update()
 captured.append((frame,{bone.name:bone.matrix.copy() for bone in rig.pose.bones}))
for constraint in constraints:
 for bone in rig.pose.bones:
  if constraint in list(bone.constraints):bone.constraints.remove(constraint);break
for helper in helpers:bpy.data.objects.remove(helper,do_unlink=True)
def depth(bone):return 0 if bone.parent is None else 1+depth(bone.parent)
for frame,matrices in captured:
 bpy.context.scene.frame_set(frame)
 for bone in sorted(rig.pose.bones,key=depth):
  kwargs={'parent_matrix':matrices[bone.parent.name],'parent_matrix_local':bone.parent.bone.matrix_local} if bone.parent else {}
  bone.matrix_basis=bone.bone.convert_local_to_pose(matrices[bone.name],bone.bone.matrix_local,invert=True,**kwargs)
  for attribute in ['rotation_quaternion','location','scale']:bone.keyframe_insert(attribute,frame=frame,group=bone.name)
cloth=[bpy.data.objects[n] for n in ['Opaque fitted underwear foundation','Fitted cotton upper base','Clerk full length trousers','Clerk buttoned sleeveless waistcoat']]
for obj in cloth:
 if not obj.data.shape_keys:obj.shape_key_add(name='Basis')
for sample in range(121):
 frame=1+sample*60/120;bpy.context.scene.frame_set(int(frame),subframe=frame%1);bpy.context.view_layer.update()
 dg=bpy.context.evaluated_depsgraph_get();ev=body.evaluated_get(dg);mesh=ev.to_mesh()
 tree=BVHTree.FromPolygons([ev.matrix_world@v.co for v in mesh.vertices],[list(p.vertices) for p in mesh.polygons]);ev.to_mesh_clear()
 for obj in cloth:
  key=obj.shape_key_add(name='Seat cloth %02d'%sample);key.value=1;_fit_pose(rig,obj,tree,key,vertex_priority=True);key.value=0
 print('CLERK_SEAT_SAMPLE',sample,flush=True)
rig.animation_data.action=clip;bpy.context.scene.frame_set(1)
working=out/'record_clerk_seat.blend';bpy.ops.wm.save_as_mainfile(filepath=str(working))
# Bake only helper exclusion in the exported skin; all human body surfaces remain.
rig.data.pose_position='REST';bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get()
mesh=bpy.data.meshes.new_from_object(body.evaluated_get(dg),preserve_all_data_layers=True,depsgraph=dg)
skin=bpy.data.objects.new('record_clerk_export_full_body',mesh);bpy.context.collection.objects.link(skin)
for group in body.vertex_groups:skin.vertex_groups.new(name=group.name)
skin.parent=rig;skin.matrix_parent_inverse=body.matrix_parent_inverse.copy();skin.matrix_basis=body.matrix_basis.copy();skin.modifiers.new('Complete skin','ARMATURE').object=rig
rig.data.pose_position='POSE';bpy.context.scene.frame_set(1);bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
for obj in bpy.data.objects:
 if obj.type=='MESH' and obj!=body:obj.select_set(True)
bpy.context.view_layer.objects.active=rig
runtime=ROOT/'characters/npcs/review/record_clerk_seat.glb';runtime.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(runtime),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIONS',export_force_sampling=True,export_frame_range=False,export_cameras=False,export_lights=False,export_yup=True,export_skins=True,export_apply=False)
normalize_animation_times(runtime)
import subprocess
subprocess.run(['/usr/bin/python3',str(ROOT/'tools/characters/audit_clerk_seat_body.py')],check=True)
(out/'manifest.json').write_text(json.dumps({'status':'ISOLATED_UNAPPROVED','source':str(working),'runtime':str(runtime),'live_source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'seat_cloth_samples':121,'body_vertices':len(mesh.vertices),'scope':'seat entry and garment fit study; hand/seat/floor contact and renderer approval required'},indent=2)+'\n')
