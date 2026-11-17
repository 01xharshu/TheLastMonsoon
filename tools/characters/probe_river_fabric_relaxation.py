"""Disposable Blender cloth relaxation probe for a seated river garment.

The source is never saved or modified. Run through a temporary output folder;
this probe is not an accepted runtime asset or a replacement for motion checks.
"""
import bpy, json, os, sys
from pathlib import Path
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/characters'))
from river_cloth_correctives import apply_river_pose
from purpose_cloth_volume import VolumeSurface, inside_surface
from river_triangle_contact import crosses

folder=Path(sys.argv[sys.argv.index('--')+1]);folder.mkdir(parents=True,exist_ok=True)
source=ROOT/'WorkingAssets/NPCs/river_activity/river_activity_draped.blend'
data=json.loads((source.parent/'poses.json').read_text())
pose=min((p for p in data['poses'] if p['key'].startswith('River cloth')),key=lambda p:abs(p['time']-43.0))
bpy.ops.wm.open_mainfile(filepath=str(source));scene=bpy.context.scene
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
body=next(o for o in bpy.data.objects if o.type=='MESH' and 'MakeHuman_body' in o.name)
wrap=bpy.data.objects['Wrapped sari lower drape']
if rig.animation_data:
 rig.animation_data.action=None
 for track in rig.animation_data.nla_tracks:track.mute=True
rig.data.pose_position='POSE'
c=Matrix(((1,0,0,0),(0,0,-1,0),(0,1,0,0),(0,0,0,1)))
corrections={name:(c@Matrix(rest)@c.inverted()).inverted()@rig.data.bones[name].matrix_local for name,rest in data['rest'].items() if name in rig.data.bones}
apply_river_pose(rig,pose['bones'],c,corrections)
for obj in bpy.data.objects:
 if obj.type=='MESH' and obj.data.shape_keys:
  for key in obj.data.shape_keys.key_blocks:key.value=1.0 if key.name==pose['key'] else 0.0
bpy.context.view_layer.update()
def evaluated(obj):
 ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh();mesh.calc_loop_triangles()
 points=[ev.matrix_world@v.co for v in mesh.vertices];faces=[tuple(t.vertices) for t in mesh.loop_triangles]
 ev.to_mesh_clear();return points,faces
body_points,body_faces=evaluated(body);cloth_points,cloth_faces=evaluated(wrap)
# The temporary collider is the actual complete posed MakeHuman surface.
for obj in bpy.data.objects:obj.hide_render=True
def mesh_object(name,points,faces):
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(points,[],faces);mesh.update()
 obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);return obj
collider=mesh_object('Probe complete posed body collider',body_points,body_faces)
collider.modifiers.new('Fabric collision','COLLISION');collider.collision.thickness_outer=.004
collider.hide_render=True
fabric=mesh_object('Probe relaxed sari',cloth_points,cloth_faces)
for face in fabric.data.polygons:face.use_smooth=True
fabric.data.materials.append(wrap.data.materials[0])
anchors=fabric.vertex_groups.new(name='Waist anchors');anchors.add(list(range(40)),1.0,'REPLACE')
modifier=fabric.modifiers.new('Disposable physical relaxation','CLOTH')
modifier.settings.quality=12;modifier.settings.mass=.18;modifier.settings.vertex_group_mass=anchors.name
modifier.settings.tension_stiffness=18;modifier.settings.compression_stiffness=18;modifier.settings.shear_stiffness=8;modifier.settings.bending_stiffness=.4
modifier.collision_settings.use_collision=True;modifier.collision_settings.distance_min=.006;modifier.collision_settings.collision_quality=8
modifier.collision_settings.use_self_collision=True;modifier.collision_settings.self_distance_min=.004
end_frame=max(2,int(os.environ.get('TLM_RIVER_RELAX_FRAMES','25')))
scene.render.fps=30;scene.frame_start=1;scene.frame_end=end_frame
modifier.point_cache.frame_start=1;modifier.point_cache.frame_end=end_frame;modifier.point_cache.use_disk_cache=False
for obj in [body,bpy.data.objects['Fitted cotton upper base'],bpy.data.objects['Opaque fitted bra and thong foundation']]:obj.hide_render=False
# A quiet floor prevents the unsupported hem from falling indefinitely.
floor_z=min(p.z for p in body_points)-.005
floor=mesh_object('Probe ground',[(-5,-5,floor_z),(5,-5,floor_z),(5,5,floor_z),(-5,5,floor_z)],[(0,1,2),(0,2,3)])
floor.modifiers.new('Ground collision','COLLISION');floor.collision.thickness_outer=.002
floor.hide_render=True
camera_data=bpy.data.cameras.new('Probe camera');camera=bpy.data.objects.new('Probe camera',camera_data);bpy.context.collection.objects.link(camera)
center=sum(body_points,Vector())/len(body_points);camera.location=center+Vector((2.5,-3.0,2.1));camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();camera_data.type='ORTHO';camera_data.ortho_scale=2.4;scene.camera=camera
light_data=bpy.data.lights.new('Probe light','AREA');light=bpy.data.objects.new('Probe light',light_data);bpy.context.collection.objects.link(light);light.location=center+Vector((0,-1,3));light_data.energy=700;light_data.shape='DISK';light_data.size=5
scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=720;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.frame_set(1);bpy.context.view_layer.update();scene.render.filepath=str(folder/'before.png');bpy.ops.render.render(write_still=True)
for frame in range(2,end_frame+1):
 scene.frame_set(frame);bpy.context.view_layer.update()
 if frame%10==0:print('RIVER_FABRIC_RELAX_FRAME',frame,flush=True)
after,_=evaluated(fabric)
maximum=max((a-b).length for a,b in zip(after,cloth_points))
volume=VolumeSurface.FromPolygons(body_points,body_faces,all_triangles=True)
def penetrations(points):
 samples=points+[sum((points[i] for i in face),Vector())/3.0 for face in cloth_faces]
 depths=[]
 for point in samples:
  _,_,_,distance=volume.find_nearest(point)
  if distance is not None and distance>.002 and inside_surface(volume,point):depths.append(distance)
 return {'samples':len(samples),'violations':len(depths),'worst_m':max(depths,default=0.0)}
initial_contact=penetrations(cloth_points);relaxed_contact=penetrations(after)
limited=[]
for start,end in zip(cloth_points,after):
 displacement=end-start
 limited.append(start+displacement*(min(1.0,.14/max(displacement.length,1e-12))))
limited_contact=penetrations(limited)
def layer_crossings(points):
 tree=BVHTree.FromPolygons(points,cloth_faces,all_triangles=True);result={}
 for name in ['Fitted cotton upper base','Opaque fitted bra and thong foundation']:
  inner,faces=evaluated(bpy.data.objects[name]);other=BVHTree.FromPolygons(inner,faces,all_triangles=True)
  result[name]=sum(1 for a,b in tree.overlap(other) if crosses([points[i] for i in cloth_faces[a]],[inner[i] for i in faces[b]]))
 return result
limited_layers=layer_crossings(limited)
scene.render.filepath=str(folder/'after.png');bpy.ops.render.render(write_still=True)
print('RIVER_FABRIC_RELAX',json.dumps({'pose':pose['time'],'vertices':len(after),'max_displacement_m':maximum,'simulation_seconds':(end_frame-1)/30,'initial_contact':initial_contact,'relaxed_contact':relaxed_contact,'limited_140mm_contact':limited_contact,'limited_140mm_layers':limited_layers,'source_saved':False,'contact_approved':False,'visual_approved':False}),flush=True)
if '--build-relaxed' in sys.argv:
 import hashlib
 from river_surface_binding import inverse_skin
 if limited_contact['violations'] or any(limited_layers.values()):
  raise RuntimeError('Refusing to author an intersecting seated relaxation')
 delta=[b-a for a,b in zip(cloth_points,limited)]
 # Reopen the clean source so disposable collider, rendering and simulator
 # objects never enter the editable candidate or its eventual runtime export.
 bpy.ops.wm.open_mainfile(filepath=str(source))
 rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
 body=next(o for o in bpy.data.objects if o.type=='MESH' and 'MakeHuman_body' in o.name)
 wrap=bpy.data.objects['Wrapped sari lower drape']
 original=[tuple(v.co) for v in body.data.vertices]
 if rig.animation_data:
  rig.animation_data.action=None
  for track in rig.animation_data.nla_tracks:track.mute=True
 rig.data.pose_position='POSE';apply_river_pose(rig,pose['bones'],c,corrections)
 inverse=inverse_skin(rig,wrap)
 def smooth(a,b,x):
  t=max(0.,min(1.,(x-a)/(b-a)));return t*t*(3.-2.*t)
 count=0
 for item in data['poses']:
  if not item['key'].startswith('River cloth '):continue
  weight=smooth(35.0,38.0,item['time'])*(1.-smooth(46.0,48.0,item['time']))
  if weight<=0:continue
  key=wrap.data.shape_keys.key_blocks.get(item['key'])
  if key is None:raise RuntimeError('Missing seated cloth key '+item['key'])
  for index,point in enumerate(key.data):point.co+=inverse[index].to_3x3()@delta[index]*weight
  count+=1
 assert original==[tuple(v.co) for v in body.data.vertices]
 for obj in bpy.data.objects:
  if obj.type=='MESH' and obj.data.shape_keys:
   for key in obj.data.shape_keys.key_blocks:key.value=0
 rig.data.pose_position='REST'
 if rig.animation_data:
  for track in rig.animation_data.nla_tracks:track.mute=False
 bpy.context.preferences.filepaths.save_version=0
 target=source.parent/'river_activity_relaxed.blend';bpy.ops.wm.save_as_mainfile(filepath=str(target))
 digest=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
 manifest={'source_sha256':digest(source),'pose_sha256':digest(source.parent/'poses.json'),'relaxed_sha256':digest(target),'seated_keys':count,'maximum_adjustment_m':max(v.length for v in delta),'reference_time':pose['time'],'complete_body_unchanged':True,'visual_approved':False}
 (source.parent/'relaxed_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print('RIVER_FABRIC_RELAX_CANDIDATE',json.dumps(manifest),flush=True)
