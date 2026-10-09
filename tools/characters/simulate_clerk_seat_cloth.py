"""Bake a continuous physical garment trial over the complete existing MPFB body.

This operates in memory until all frames finish. It preserves body topology,
body macro shapes and the rig action. Only the two lower garments' Seat keys
are replaced. The complete source and runtime stay isolated and unapproved.
"""
import bpy,sys,runpy
from pathlib import Path
from mathutils import Matrix,Vector

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/characters'))
from purpose_seat_topology import native_triangles
from purpose_cloth_volume import VolumeSurface,inside_surface

review_folder=Path(sys.argv[sys.argv.index('--review-only')+1]) if '--review-only' in sys.argv else None
candidate_source=Path(sys.argv[sys.argv.index('--candidate-source')+1]) if '--candidate-source' in sys.argv else None
candidate_runtime=Path(sys.argv[sys.argv.index('--candidate-runtime')+1]) if '--candidate-runtime' in sys.argv else None
if (candidate_source is None)!=(candidate_runtime is None):raise ValueError('Both candidate paths are required')
source=ROOT/'WorkingAssets/NPCs/record_clerk/desk_study/record_clerk_seat.blend'
bpy.ops.wm.open_mainfile(filepath=str(source))
scene=bpy.context.scene
rig=bpy.data.objects['record_clerk_rig'];body=bpy.data.objects['record_clerk_MakeHuman_body']
rig.animation_data.action=bpy.data.actions['seat_entry'];rig.data.pose_position='POSE'
garments=[bpy.data.objects[name] for name in ['Opaque fitted underwear foundation','Clerk full length trousers']]
if '--wider-stance' in sys.argv:
 from purpose_seat_footplant import plant_entry
 captured=[]
 for frame in range(1,62):
  scene.frame_set(frame);bpy.context.view_layer.update()
  captured.append((frame,{bone.name:bone.matrix.copy() for bone in rig.pose.bones}))
 captured=plant_entry(rig,captured,body,seat_height=.52,ankle_spread=.10,knee_spread=.16)
 def depth(bone):return 0 if bone.parent is None else 1+depth(bone.parent)
 for frame,matrices in captured:
  scene.frame_set(frame)
  for bone in sorted(rig.pose.bones,key=depth):
   kwargs={'parent_matrix':matrices[bone.parent.name],'parent_matrix_local':bone.parent.bone.matrix_local} if bone.parent else {}
   bone.matrix_basis=bone.bone.convert_local_to_pose(matrices[bone.name],bone.bone.matrix_local,invert=True,**kwargs)
   for attribute in ['rotation_quaternion','location','scale']:bone.keyframe_insert(attribute,frame=frame,group=bone.name)
 scene.frame_set(1);bpy.context.view_layer.update()

for obj in bpy.data.objects:
 if obj.type=='MESH' and obj.data.shape_keys:
  for key in obj.data.shape_keys.key_blocks:
   if key.name.startswith(('Walk cloth ','Seat cloth ')):key.value=0
upper=[bpy.data.objects[name] for name in ['Clerk buttoned sleeveless waistcoat','Fitted cotton upper base']]
topology=native_triangles(rig,[body]+garments+upper,ROOT/'characters/npcs/review/record_clerk_seat.glb')
faces=topology[body.name]
if '--single-surfaces' in sys.argv:
 from purpose_seat_fabric_surfaces import rebuild_lower_surfaces
 rebuild_lower_surfaces(rig,body,garments[0],garments[1])
 for obj in garments:
  obj.data.calc_loop_triangles();topology[obj.name]=[tuple(face.vertices) for face in obj.data.loop_triangles]
rig.data.pose_position='REST';bpy.context.view_layer.update()
ev=body.evaluated_get(bpy.context.evaluated_depsgraph_get());rest=ev.to_mesh()
collision_mesh=bpy.data.meshes.new('Full MPFB skin cloth collider')
collision_mesh.from_pydata([v.co[:] for v in rest.vertices],[],faces)
collider=bpy.data.objects.new('Temporary complete skin collider',collision_mesh)
bpy.context.collection.objects.link(collider)
collider.parent=rig;collider.matrix_parent_inverse=body.matrix_parent_inverse.copy();collider.matrix_basis=body.matrix_basis.copy()
for group in body.vertex_groups:collider.vertex_groups.new(name=group.name)
for vertex in rest.vertices:
 for group in vertex.groups:collider.vertex_groups[group.group].add([vertex.index],group.weight,'REPLACE')
ev.to_mesh_clear()
collider.modifiers.new('Animated complete skin','ARMATURE').object=rig
collider.modifiers.new('Fabric collision','COLLISION')
collider.collision.thickness_outer=.004;collider.collision.thickness_inner=.002
collider.hide_render=True
rig.data.pose_position='POSE'
scene.frame_start=1;scene.frame_end=61;scene.render.fps=30;scene.frame_set(1)
# The ordinary garment Basis is not the corrected seat-entry standing fit.
# Start the solver with its already fitted Seat 00 coordinates, retaining the
# original Basis for export and for all other recoverable animation families.
original_basis={}
for obj in garments:
 basis=obj.data.shape_keys.key_blocks['Basis'];fitted=obj.data.shape_keys.key_blocks['Seat cloth 00']
 original_basis[obj.name]=[vertex.co.copy() for vertex in basis.data]
 for vertex,point in zip(basis.data,fitted.data):vertex.co=point.co
bpy.context.view_layer.update()
ev=body.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
volume=VolumeSurface.FromPolygons([ev.matrix_world@v.co for v in mesh.vertices],faces,all_triangles=True);ev.to_mesh_clear()
for obj in garments:
 ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh();points=[ev.matrix_world@v.co for v in mesh.vertices];ev.to_mesh_clear()
 points += [sum((points[i] for i in face),Vector())/3 for face in topology[obj.name]]
 contacts=sum(volume.find_nearest(point)[3]>.002 and inside_surface(volume,point) for point in points)
 print('CLERK_PHYSICAL_INITIAL_CONTACTS',obj.name,contacts,flush=True)
 if contacts and '--single-surfaces' in sys.argv:
  from purpose_seat_contact_repair import repair_key
  repair_key(rig,obj,volume,obj.data.shape_keys.key_blocks['Basis'],topology[obj.name],strict=True)
  for key in obj.data.shape_keys.key_blocks:
   if key.name.startswith('Seat cloth '):
    for vertex,point in zip(key.data,obj.data.shape_keys.key_blocks['Basis'].data):vertex.co=point.co
 elif contacts:raise RuntimeError('Physical cloth must begin outside the full body; source preserved')
 if '--single-surfaces' in sys.argv:
  original_basis[obj.name]=[vertex.co.copy() for vertex in obj.data.shape_keys.key_blocks['Basis'].data]

modifiers={};baked={obj.name:[] for obj in garments}
for obj in garments:
 group=obj.vertex_groups.get('Seat fabric anchors') or obj.vertex_groups.new(name='Seat fabric anchors')
 basis=obj.data.shape_keys.key_blocks['Basis']
 top=max(v.co.z for v in basis.data);bottom=min(v.co.z for v in basis.data)
 for index,vertex in enumerate(basis.data):
  # Keep the waistband attached and prevent cuffs falling through planted feet.
  weight=1.0 if vertex.co.z>top-.065 else (.8 if obj.name=='Clerk full length trousers' and vertex.co.z<bottom+.055 else (.1 if obj.name=='Clerk full length trousers' else .25))
  group.add([index],weight,'REPLACE')
 modifier=obj.modifiers.new('Continuous seated fabric trial','CLOTH');modifiers[obj.name]=modifier
 settings=modifier.settings;settings.quality=24;settings.mass=.18
 settings.tension_stiffness=18;settings.compression_stiffness=18;settings.shear_stiffness=8;settings.bending_stiffness=.4
 settings.air_damping=3;settings.vertex_group_mass=group.name;settings.pin_stiffness=1
 collision=modifier.collision_settings
 collision.use_collision=True;collision.distance_min=.002 if obj.name=='Opaque fitted underwear foundation' else .006;collision.collision_quality=12
 collision.use_self_collision=True;collision.self_distance_min=.004
 modifier.point_cache.frame_start=1;modifier.point_cache.frame_end=61;modifier.point_cache.use_disk_cache=False

def inverse_skin(obj,index):
 blend=Matrix.Identity(4)*0;total=0
 for group in obj.data.vertices[index].groups:
  bone=rig.pose.bones.get(obj.vertex_groups[group.group].name)
  if bone:blend+=(bone.matrix@bone.bone.matrix_local.inverted())*group.weight;total+=group.weight
 matrix=rig.matrix_world@(blend*(1/total) if total else Matrix.Identity(4))@rig.matrix_world.inverted()@obj.matrix_world
 return matrix.inverted_safe()

for frame in range(1,62):
 scene.frame_set(frame);bpy.context.view_layer.update()
 for obj in garments:
  ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
  if len(mesh.vertices)!=len(obj.data.vertices):raise RuntimeError('Simulation changed cloth topology')
  points=[inverse_skin(obj,v.index)@(ev.matrix_world@v.co) for v in mesh.vertices]
  ev.to_mesh_clear();baked[obj.name].append(points)
 print('CLERK_PHYSICAL_CLOTH_FRAME',frame,flush=True)

for obj in garments:
 obj.modifiers.remove(modifiers[obj.name])
 for vertex,point in zip(obj.data.shape_keys.key_blocks['Basis'].data,original_basis[obj.name]):vertex.co=point
 for sample in range(121):
  first=sample//2;fraction=(sample%2)*.5
  left=baked[obj.name][first];right=baked[obj.name][min(first+1,60)]
  key=obj.data.shape_keys.key_blocks['Seat cloth %02d'%sample]
  for vertex,a,b in zip(key.data,left,right):vertex.co=a.lerp(b,fraction)
bpy.data.objects.remove(collider,do_unlink=True)
bpy.data.meshes.remove(collision_mesh)
if '--post-fit' in sys.argv:
 from purpose_seat_contact_repair import fit_seat_contacts
 for obj in garments:
  obj.data.update();obj.data.calc_loop_triangles();topology[obj.name]=[tuple(face.vertices) for face in obj.data.loop_triangles]
 fit_seat_contacts(rig,body,garments+upper,ROOT/'characters/npcs/review/record_clerk_seat.glb',reset_to_basis=False,topology_override=topology)

# Check evaluated displacement, not rest-space inverse-skin coordinates. A
# collision-free exploded garment must fail before it can overwrite the study.
guard_failed=False
for sample in [0,30,60,90,120]:
 frame=1+sample*.5;scene.frame_set(int(frame),subframe=frame%1)
 for obj in garments:
  key=obj.data.shape_keys.key_blocks['Seat cloth %02d'%sample]
  key.value=0;bpy.context.view_layer.update()
  ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh();baseline=[ev.matrix_world@v.co for v in mesh.vertices];ev.to_mesh_clear()
  key.value=1;bpy.context.view_layer.update()
  ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
  maximum=max((ev.matrix_world@v.co-baseline[v.index]).length for v in mesh.vertices);ev.to_mesh_clear();key.value=0
  print('CLERK_PHYSICAL_CLOTH_DISPLACEMENT',sample,obj.name,maximum,flush=True)
  if maximum>.12:guard_failed=True
if guard_failed and review_folder is None and candidate_source is None:raise RuntimeError('Physical cloth trial exceeds 120mm posed displacement; source preserved')
if review_folder is not None:
 source=review_folder/'physical_clerk.blend'
 sys.argv.extend(['--source',str(source),'--runtime',str(review_folder/'physical_clerk.glb')])
if candidate_source is not None:
 source=candidate_source
 sys.argv.extend(['--source',str(source),'--runtime',str(candidate_runtime)])
scene.frame_set(1);bpy.ops.wm.save_as_mainfile(filepath=str(source))
sys.argv.append('--export-only')
runpy.run_path(str(ROOT/'tools/characters/refit_clerk_seat_layers.py'),run_name='__main__')
