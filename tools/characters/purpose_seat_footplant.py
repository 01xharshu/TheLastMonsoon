"""Fixed ankle targets while the unchanged clerk body settles onto its seat."""
import bpy,math
from mathutils import Vector

def _restore(rig,matrices):
 def depth(bone):return 0 if bone.parent is None else 1+depth(bone.parent)
 for bone in sorted(rig.pose.bones,key=depth):
  kwargs={'parent_matrix':matrices[bone.parent.name],'parent_matrix_local':bone.parent.bone.matrix_local} if bone.parent else {}
  bone.matrix_basis=bone.bone.convert_local_to_pose(matrices[bone.name],bone.bone.matrix_local,invert=True,**kwargs)

def plant_entry(rig,captured,body,seat_height=.51,ankle_spread=0.0,knee_spread=0.0):
 first=captured[0][1];last=captured[-1][1];root=rig.pose.bones['Root']
 start=first['Root'].translation-root.bone.matrix_local.translation
 end=last['Root'].translation-root.bone.matrix_local.translation
 start.y+=sum(last['foot_'+s].translation.y-first['foot_'+s].translation.y for s in ['l','r'])*.5
 goals={};constraints=[];helpers=[]
 _restore(rig,last)
 for side in ['l','r']:
  goal=bpy.data.objects.new('Seat fixed ankle '+side,None);bpy.context.collection.objects.link(goal);helpers.append(goal)
  goal.location=rig.matrix_world@last['foot_'+side].translation
  sign=1 if goal.location.x>=0 else -1
  goal.location.x+=sign*ankle_spread;goals[side]=goal
  pole=bpy.data.objects.new('Seat knee pole '+side,None);bpy.context.collection.objects.link(pole);helpers.append(pole)
  pole.location=rig.matrix_world@(last['calf_'+side].translation+Vector((sign*knee_spread,-.35,.08)))
  constraint=rig.pose.bones['calf_'+side].constraints.new('IK');constraint.target=goal;constraint.pole_target=pole;constraint.chain_count=2;constraint.use_tail=True;constraints.append(constraint)
  choices=[]
  for angle in [0,math.pi/2,-math.pi/2,math.pi]:
   constraint.pole_angle=angle;bpy.context.view_layer.update();choices.append((rig.pose.bones['calf_'+side].head.y,angle))
  constraint.pole_angle=min(choices)[1]
 if ankle_spread:
  for iteration in range(40):
   _restore(rig,first);root.location=start;bpy.context.view_layer.update()
   error=max((rig.matrix_world@rig.pose.bones['foot_'+side].head-goals[side].location).length for side in ['l','r'])
   if error<.0005:break
   start.z-=.001
  else:raise RuntimeError('Wider standing stance cannot reach its fixed ankle goals')
 # Fit the full posterior skin to the actual office chair top, keeping
 # ankle targets fixed. The office chair is 0.51m above its floor.
 pelvis_group=body.vertex_groups['pelvis'].index
 for iteration in range(8):
  _restore(rig,last);root.location=end;bpy.context.view_layer.update()
  dg=bpy.context.evaluated_depsgraph_get();ev=body.evaluated_get(dg);mesh=ev.to_mesh()
  pelvis=rig.matrix_world@rig.pose.bones['pelvis'].head
  posterior=[]
  for vertex in mesh.vertices:
   point=ev.matrix_world@vertex.co
   weight=sum(group.weight for group in vertex.groups if group.group==pelvis_group)
   if weight>.5 and point.y>pelvis.y+.03 and point.z<pelvis.z and abs(point.x)<.21:posterior.append(point.z)
  ev.to_mesh_clear()
  if not posterior:raise RuntimeError('No posterior pelvis surface for seat fit')
  gap=seat_height-min(posterior);end.z+=gap
  if abs(gap)<.0001:break
 print('SEAT_POSTERIOR_HEIGHT',seat_height,'root',end.z,flush=True)
 result=[];maximum=0
 for frame,matrices in captured:
  _restore(rig,matrices);phase=(frame-1)/60;blend=phase*phase*(3-2*phase)
  root.location=start.lerp(end,blend);bpy.context.view_layer.update()
  for side in ['l','r']:
   foot=rig.pose.bones['foot_'+side]
   flat=last['foot_'+side].copy();flat.translation=foot.head.copy();foot.matrix=flat
  bpy.context.view_layer.update()
  for side in ['l','r']:maximum=max(maximum,(rig.matrix_world@rig.pose.bones['foot_'+side].head-goals[side].location).length)
  result.append((frame,{bone.name:bone.matrix.copy() for bone in rig.pose.bones}))
 for side,constraint in zip(['l','r'],constraints):rig.pose.bones['calf_'+side].constraints.remove(constraint)
 for helper in helpers:bpy.data.objects.remove(helper,do_unlink=True)
 if maximum>.002:raise RuntimeError('Seated ankle target error '+str(maximum))
 print('SEAT_FIXED_ANKLES',maximum,'m',flush=True)
 return result
