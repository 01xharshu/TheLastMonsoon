"""Bake individual two-bone foot-target gait studies; no runtime IK dependency."""
import bpy, math
from mathutils import Vector

GAITS = {
 'dock_porter': dict(stride=.40, clearance=.065, sway=.012, arm=.12, stance_width=.06),
 'boatman': dict(stride=.44, clearance=.060, sway=.008, arm=.16),
 'record_clerk': dict(stride=.28, clearance=.040, sway=.024, arm=.085),
}

class GroundedGait:
 def __init__(self,rig,role):
  self.rig=rig;self.profile=GAITS[role];self.targets={};self.constraints=[];self.objects=[]
  for side in ['l','r']:
   foot=rig.pose.bones['foot_'+side]
   goal=bpy.data.objects.new('Foot stance goal '+side,None);bpy.context.collection.objects.link(goal)
   goal.matrix_world=rig.matrix_world@foot.bone.matrix_local
   self.objects.append(goal)
   pole=bpy.data.objects.new('Forward knee pole '+side,None);bpy.context.collection.objects.link(pole)
   pole.location=rig.matrix_world@Vector((foot.bone.head_local.x,-1,.65));self.objects.append(pole)
   ik=rig.pose.bones['calf_'+side].constraints.new('IK');ik.target=goal;ik.pole_target=pole;ik.chain_count=2;ik.use_stretch=False
   orient=foot.constraints.new('COPY_ROTATION');orient.target=goal;orient.target_space='WORLD';orient.owner_space='WORLD'
   self.constraints.extend([ik,orient]);self.targets[side]=(goal,foot.bone.head_local.copy())
   # Choose the anatomical forward knee bend for this rig's local roll.
   goal.location.z-=.025
   choices=[]
   for angle in [0,math.pi/2,-math.pi/2,math.pi]:
    ik.pole_angle=angle;bpy.context.view_layer.update()
    choices.append((rig.pose.bones['calf_'+side].head.y,angle))
   ik.pole_angle=min(choices)[1];goal.location=rig.matrix_world@foot.bone.head_local
  for constraint in self.constraints:constraint.influence=0
  self.frames={};self.max_target_error=0

 def step(self,clip,phase):
  walking=clip=='walk'
  active_feet=walking or self.profile.get('stance_width',0.0)>0
  for constraint in self.constraints:constraint.influence=1 if active_feet else 0
  if active_feet:
   profile=self.profile
   root=self.rig.pose.bones.get('Root')
   if root:
    root.location=root.bone.matrix_local.to_3x3().inverted()@Vector((profile['sway']*math.sin(phase*math.tau) if walking else 0,0,-.025+(.004*math.cos(phase*math.tau*2) if walking else 0)))
   for side,offset in [('l',0),('r',.5)]:
    goal,rest=self.targets[side];t=(phase+offset)%1
    if t<.60:
     y=-profile['stride']*(.5-t/.60);lift=0
    else:
     u=(t-.60)/.40;smooth=u*u*(3-2*u)
     y=profile['stride']*(.5-smooth);lift=profile['clearance']*math.sin(math.pi*u)
    if not walking:y=0;lift=0
    stance=self.profile.get('stance_width',0.0)*(1 if side=='l' else -1)
    goal.location=self.rig.matrix_world@(rest+Vector((stance,y,lift)))
  bpy.context.view_layer.update()
  if walking:
   for side in ['l','r']:
    goal,_=self.targets[side]
    err=((self.rig.matrix_world@self.rig.pose.bones['foot_'+side].head)-goal.location).length
    self.max_target_error=max(self.max_target_error,err)
  return {bone.name:bone.matrix.copy() for bone in self.rig.pose.bones}

 def bake(self,captures):
  for bone in self.rig.pose.bones:
   for constraint in list(bone.constraints):
    if constraint in self.constraints:bone.constraints.remove(constraint)
  # Parent matrices must be restored before converting each child's pose.
  def depth(bone):
   return 0 if bone.parent is None else 1+depth(bone.parent)
  bones=sorted(self.rig.pose.bones,key=depth)
  for action,frames in captures:
   self.rig.animation_data.action=action
   for frame,matrices in frames:
    bpy.context.scene.frame_set(frame)
    for bone in bones:
     if bone.parent:
      bone.matrix_basis=bone.bone.convert_local_to_pose(matrices[bone.name], bone.bone.matrix_local,
       parent_matrix=matrices[bone.parent.name], parent_matrix_local=bone.parent.bone.matrix_local, invert=True)
     else:
      bone.matrix_basis=bone.bone.convert_local_to_pose(matrices[bone.name], bone.bone.matrix_local, invert=True)
     bone.keyframe_insert('rotation_quaternion',frame=frame,group=bone.name)
     bone.keyframe_insert('location',frame=frame,group=bone.name)
     bone.keyframe_insert('scale',frame=frame,group=bone.name)
  for obj in self.objects:bpy.data.objects.remove(obj,do_unlink=True)

def normalize_animation_times(path):
 """Remove Blender's 1-frame timestamp offset in the delivered GLB itself."""
 import json,struct
 raw=path.read_bytes();size=struct.unpack_from('<I',raw,12)[0]
 doc=json.loads(raw[20:20+size]);tail=bytearray(raw[20+size:]);binary_offset=8
 visited=set()
 for animation in doc.get('animations',[]):
  accessors={sampler['input'] for sampler in animation['samplers']}
  first=min(doc['accessors'][index]['min'][0] for index in accessors)
  for index in accessors:
   if index in visited:continue
   visited.add(index);accessor=doc['accessors'][index];view=doc['bufferViews'][accessor['bufferView']]
   offset=binary_offset+view.get('byteOffset',0)+accessor.get('byteOffset',0)
   values=struct.unpack_from('<'+str(accessor['count'])+'f',tail,offset)
   shifted=[max(0,value-first) for value in values]
   struct.pack_into('<'+str(accessor['count'])+'f',tail,offset,*shifted)
   accessor['min']=[min(shifted)];accessor['max']=[max(shifted)]
 packed=json.dumps(doc,separators=(',',':')).encode();packed+=b' '*((-len(packed))%4)
 path.write_bytes(struct.pack('<4sII',b'glTF',2,20+len(packed)+len(tail))+struct.pack('<I4s',len(packed),b'JSON')+packed+tail)
