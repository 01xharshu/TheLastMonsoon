"""Recover actual MPFB fabric surfaces for the isolated clerk cloth trial.

The prior trousers contain a baked Solidify volume. A cloth solver needs the
original garment sheet, not opposing shell faces separated by two millimetres.
The foundation uses the existing complete body's surface and exact skin weights.
No human body vertices, macro shapes or dimensions are changed.
"""
import bpy
from pathlib import Path
from bl_ext.blender_org.mpfb.services.humanservice import HumanService
from whole_body_contract import retain_complete_body

def rebuild_lower_surfaces(rig,body,foundation,trousers):
 previous=rig.data.pose_position;rig.data.pose_position='REST';bpy.context.view_layer.update()
 materials={obj.name:list(obj.data.materials) for obj in [foundation,trousers]}
 def replace(obj,points,faces,groups,weights):
  old=obj.data;mesh=bpy.data.meshes.new(obj.name+' fabric surface')
  mesh.from_pydata(points,[],faces);mesh.update();obj.data=mesh
  obj.vertex_groups.clear()
  for name in groups:obj.vertex_groups.new(name=name)
  for index,assignments in enumerate(weights):
   for group,weight in assignments:
    if weight>0:obj.vertex_groups[group].add([index],weight,'REPLACE')
  for material in materials[obj.name]:mesh.materials.append(material)
  for polygon in mesh.polygons:polygon.use_smooth=True
  if old.users==0:bpy.data.meshes.remove(old)
  if obj.name=='Clerk full length trousers':
   bpy.ops.object.select_all(action='DESELECT');obj.select_set(True);bpy.context.view_layer.objects.active=obj
   bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.subdivide(number_cuts=1,smoothness=0);bpy.ops.object.mode_set(mode='OBJECT')
  obj.shape_key_add(name='Basis')
  for sample in range(121):obj.shape_key_add(name='Seat cloth %02d'%sample)
  print('CLERK_FABRIC_SURFACE',obj.name,len(obj.data.vertices),len(obj.data.polygons),flush=True)

 # Extract only a garment patch. The original complete MPFB skin remains intact.
 ev=body.evaluated_get(bpy.context.evaluated_depsgraph_get());skin=ev.to_mesh()
 relevant={g.index for g in body.vertex_groups if g.name=='pelvis'}
 keep={v.index for v in skin.vertices if .78<v.co.z<1.0 and sum(g.weight for g in v.groups if g.group in relevant)>.35}
 faces=[tuple(p.vertices) for p in skin.polygons if all(i in keep for i in p.vertices)]
 used=sorted({i for face in faces for i in face});mapping={i:j for j,i in enumerate(used)}
 transform=foundation.matrix_world.inverted()@ev.matrix_world
 points=[transform@(skin.vertices[i].co+skin.vertices[i].normal*.006) for i in used]
 weights=[[(g.group,g.weight) for g in skin.vertices[i].groups] for i in used]
 replace(foundation,points,[tuple(mapping[i] for i in face) for face in faces],[g.name for g in body.vertex_groups],weights)
 ev.to_mesh_clear()

 # Ask MPFB to fit its original single-sheet clothing to this same human.
 data=Path.home()/'Library/Application Support/Blender/5.2/extensions/.user/blender_org/mpfb/data'
 asset=data/'clothes/male_casualsuit03/male_casualsuit03.mhclo'
 donor=HumanService.add_mhclo_asset(str(asset),body,asset_type='Clothes',subdiv_levels=0)
 retain_complete_body(body)
 parent=list(range(len(donor.data.vertices)))
 def root(index):
  while parent[index]!=index:parent[index]=parent[parent[index]];index=parent[index]
  return index
 for edge in donor.data.edges:parent[root(edge.vertices[0])]=root(edge.vertices[1])
 maximum={};counts={}
 for vertex in donor.data.vertices:
  component=root(vertex.index);maximum[component]=max(maximum.get(component,-1),vertex.co.z)
  if vertex.co.z<.8:counts[component]=counts.get(component,0)+1
 lower=max((component for component in counts if maximum[component]<1.1),key=counts.get)
 faces=[tuple(p.vertices) for p in donor.data.polygons if all(root(i)==lower for i in p.vertices)]
 used=sorted({i for face in faces for i in face});mapping={i:j for j,i in enumerate(used)}
 transform=trousers.matrix_world.inverted()@donor.matrix_world
 points=[transform@(donor.data.vertices[i].co+donor.data.vertices[i].normal*.009) for i in used]
 # Add a rounded dropped crotch to the garment pattern, tapering into the legs.
 # This supplies fabric ease beneath the pelvis without changing the human.
 for point in points:
  lateral=max(0.0,1.0-abs(point.x)/.12)
  vertical=max(0.0,1.0-abs(point.z-.76)/.16)
  point.z-=.10*lateral*lateral*vertical
 weights=[[(g.group,g.weight) for g in donor.data.vertices[i].groups] for i in used]
 replace(trousers,points,[tuple(mapping[i] for i in face) for face in faces],[g.name for g in donor.vertex_groups],weights)
 mesh=donor.data;bpy.data.objects.remove(donor,do_unlink=True)
 if mesh.users==0:bpy.data.meshes.remove(mesh)
 for obj in [foundation,trousers]:
  for modifier in list(obj.modifiers):
   if modifier.type in ['MASK','SOLIDIFY']:obj.modifiers.remove(modifier)
  armature=next((m for m in obj.modifiers if m.type=='ARMATURE'),None)
  if armature is None:armature=obj.modifiers.new('Authoritative body rig','ARMATURE')
  armature.object=rig;armature.use_deform_preserve_volume=False
  obj['construction']='Single fabric surface over complete unchanged MPFB physique; separate opaque foundation retained'
 rig.data.pose_position=previous;bpy.context.scene.frame_set(1);bpy.context.view_layer.update()
