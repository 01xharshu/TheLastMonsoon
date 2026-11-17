"""Render disposable workwear-study geometry for rejection screening."""
import sys,tempfile
import os,subprocess,time
from pathlib import Path
import bpy
from mathutils import Vector,Matrix,Quaternion
args=sys.argv[sys.argv.index('--')+1:]
source=Path(args[0]).resolve();out=Path(args[1]).resolve();root=Path(tempfile.gettempdir()).resolve()
if not source.is_relative_to(root) or not out.is_relative_to(root):raise ValueError('Study and output must be temporary')
deadline=time.monotonic()+120
announced=False
while True:
 processes=subprocess.check_output(['ps','-axo','pid=,command='],text=True)
 busy=False
 for line in processes.splitlines():
  fields=line.strip().split(None,1)
  if len(fields)!=2:continue
  pid,command=fields
  if int(pid)==os.getpid():continue
  if command.startswith('/Applications/Godot.app/Contents/MacOS/Godot') and '--headless' not in command:
   busy=True
  if command.startswith('/Applications/Blender.app/Contents/MacOS/Blender'):
   busy=True
 if not busy:break
 if not announced:
  print('OCCUPATION_RENDER waiting for active renderer',flush=True);announced=True
 if time.monotonic()>=deadline:raise RuntimeError('Renderer busy; occupation review not launched')
 time.sleep(2)
bpy.ops.wm.open_mainfile(filepath=str(source))
scene=bpy.context.scene
for obj in bpy.data.objects:
 if obj.type=='MESH':
  obj.hide_render = not any(x in obj.name for x in ('artisan_complete_MakeHuman_body','Workwear transfer study','Farmer_hair','Farmer_eyes','Street opaque foundation'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.data.pose_position='REST'
highlight='--highlight-foundation' in args
if highlight:
 foundation=bpy.data.objects['Street opaque foundation']
 material=bpy.data.materials.new('Temporary foundation coverage highlight')
 material.diffuse_color=(1,0,1,1)
 foundation.data.materials.clear();foundation.data.materials.append(material)
scene.render.engine='BLENDER_WORKBENCH'
scene.display.shading.light='STUDIO';scene.display.shading.color_type='MATERIAL';scene.display.shading.show_shadows=True
scene.render.resolution_x=800;scene.render.resolution_y=800;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
data=bpy.data.cameras.new('StudyCamera');camera=bpy.data.objects.new('StudyCamera',data);scene.collection.objects.link(camera);scene.camera=camera
data.type='ORTHO';data.ortho_scale=2.1
for pose in ('idle','walk','seated'):
 rig.data.pose_position='POSE'
 for bone in rig.pose.bones:bone.matrix_basis=Matrix.Identity(4)
 for object_name,key_name,target in [('Street opaque foundation','Study walk foundation','walk'),('Street opaque foundation','Study seated foundation','seated'),('Workwear transfer study','Study seated correction','seated'),('Workwear transfer study','Study walk correction','walk')]:
  obj=bpy.data.objects.get(object_name)
  if obj and obj.data.shape_keys:
   key=obj.data.shape_keys.key_blocks.get(key_name)
   if key:key.value=1.0 if pose==target else 0.0
 for side,sign in [('l',1),('r',-1)]:
  rotations=[('thigh_'+side,-1.35),('calf_'+side,1.5),('upperarm_'+side,-.45),('lowerarm_'+side,-.85)] if pose=='seated' else [('thigh_'+side,.30*sign if pose=='walk' else 0),('upperarm_'+side,.25*sign if pose=='walk' else 0)]
  for name,angle in rotations:
   bone=rig.pose.bones.get(name)
   if bone:
    axis=bone.bone.matrix_local.to_3x3().inverted()@Vector((1,0,0))
    bone.rotation_mode='QUATERNION';bone.rotation_quaternion=Quaternion(axis.normalized(),angle)
 bpy.context.view_layer.update()
 for name,loc in [('front',(0,-4,1.05)),('side',(4,0,1.05)),('back',(0,4,1.05))]:
  camera.location=loc;camera.rotation_euler=(Vector((0,0,.85))-camera.location).to_track_quat('-Z','Y').to_euler()
  scene.render.filepath=str(out/(('highlight_' if highlight else '')+pose+'_'+name+'.png'));bpy.ops.render.render(write_still=True)
  print('OCCUPATION_RENDER',pose,name,flush=True)
