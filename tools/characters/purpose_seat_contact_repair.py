"""Repair sparse trapped cloth constraints; never alter the full MPFB body."""
import bpy
from mathutils import Matrix,Vector
from mathutils.bvhtree import BVHTree
from purpose_cloth_volume import inside_surface,VolumeSurface

def repair_key(rig,obj,tree,key,triangles=None,strict=False):
 bpy.context.view_layer.update();ev=obj.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
 points=[ev.matrix_world@v.co for v in mesh.vertices];faces=triangles if triangles is not None else [tuple(p.vertices) for p in mesh.polygons];ev.to_mesh_clear()
 initial_points=[point.copy() for point in points]
 inverse=[];normals=[]
 for vertex in obj.data.vertices:
  blend=Matrix.Identity(4)*0;total=0
  for group in vertex.groups:
   bone=rig.pose.bones.get(obj.vertex_groups[group.group].name)
   if bone:blend+=(bone.matrix@bone.bone.matrix_local.inverted())*group.weight;total+=group.weight
  transform=(rig.matrix_world@(blend*(1/total) if total else Matrix.Identity(4))@rig.matrix_world.inverted()@obj.matrix_world).to_3x3()
  inverse.append(transform.inverted_safe());normals.append((transform.inverted_safe().transposed()@vertex.normal).normalized())
 cache={}
 def depth(point):
  stamp=tuple(round(value,7) for value in point)
  if stamp not in cache:
   near,normal,_,distance=tree.find_nearest(point)
   cache[stamp]=(distance if inside_surface(tree,point) else -distance,normal)
  return cache[stamp]
 def escape(point,outward,cohort=None):
  penetration,normal=depth(point)
  if penetration<-.003:return Vector()
  probes=[point]+(cohort or [])
  def clear(shift):return all(depth(probe+shift)[0]<-.004 for probe in probes)
  directions=[normal,outward,(normal+outward).normalized(),Vector((0,-1,0)),Vector((0,1,0)),Vector((1,0,0)),Vector((-1,0,0)),Vector((0,0,-1)),Vector((0,0,1))]
  candidates=[]
  for direction in directions:
   if direction.length_squared<.5:continue
   lower=0.0
   for distance in [.004,.008,.016,.032,.064,.128,.256]:
    if clear(direction*distance):
     upper=distance
     for iteration in range(8):
      mid=(lower+upper)*.5
      if clear(direction*mid):upper=mid
      else:lower=mid
     candidates.append((upper*(1+.25*max(0,1-direction.dot(outward))),direction*upper));break
    lower=distance
  if not candidates:raise RuntimeError('No bounded exterior cloth projection: '+obj.name+' at '+str(tuple(point))+' signed depth '+str(penetration))
  return min(candidates,key=lambda item:item[0])[1]
 def apply(index,shift):
  if (points[index]+shift-initial_points[index]).length>.12:
   raise RuntimeError('Garment projection exceeds 120mm posed displacement; revise garment construction or pose instead: '+obj.name+' vertex '+str(index)+' at '+str(tuple(initial_points[index])))
  points[index]+=shift;key.data[index].co+=inverse[index]@shift
 initial=0;remaining=0
 for iteration in range(96):
  hits=0
  for face in faces:
   point=sum((points[i] for i in face),Vector())/len(face)
   if depth(point)[0]>.001:
    hits+=1;outward=sum((normals[i] for i in face),Vector()).normalized();shift=escape(point,outward,[points[i] for i in face])
    for index in face:apply(index,shift)
  for index,point in enumerate(points):
   if depth(point)[0]>.001:
    hits+=1;apply(index,escape(point,normals[index]))
  if iteration==0:initial=hits
  remaining=hits
  if hits==0:break
 if remaining:
  print('SEAT_REPAIR_UNRESOLVED',obj.name,remaining,flush=True)
  if strict:raise RuntimeError('Unresolved interpolated cloth contacts: '+obj.name)
 return initial

def fit_seat_contacts(rig,body,cloth,runtime,samples=None,smooth=False,reset_to_basis=True,topology_override=None):
 from purpose_seat_topology import native_triangles
 for obj in bpy.data.objects:
  if obj.type=='MESH' and obj.data.shape_keys:
   for key in obj.data.shape_keys.key_blocks:
    if key.name.startswith(('Walk cloth ','Seat cloth ')):key.value=0
 topology=topology_override if topology_override is not None else native_triangles(rig,[body]+cloth,runtime)
 for sample in (range(121) if samples is None else samples):
  frame=1+sample*.5;bpy.context.scene.frame_set(int(frame),subframe=frame%1);bpy.context.view_layer.update()
  ev=body.evaluated_get(bpy.context.evaluated_depsgraph_get());mesh=ev.to_mesh()
  tree=VolumeSurface.FromPolygons([ev.matrix_world@v.co for v in mesh.vertices],topology[body.name],all_triangles=True,strict=True);ev.to_mesh_clear()
  hits=0
  for obj in cloth:
   print('CLERK_SEAT_GARMENT_BEGIN',sample,obj.name,flush=True)
   key=obj.data.shape_keys.key_blocks['Seat cloth %02d'%sample]
   if reset_to_basis and obj.name in ['Opaque fitted underwear foundation','Clerk full length trousers']:
    basis=obj.data.shape_keys.key_blocks['Basis']
    for index in range(len(key.data)):key.data[index].co=basis.data[index].co
   key.value=1
   hits+=repair_key(rig,obj,tree,key,topology[obj.name])
   if smooth and obj.name=='Clerk full length trousers':
    from purpose_cloth_smoothing import smooth_offsets
    for cycle in range(3):
     smooth_offsets(obj,key)
     hits+=repair_key(rig,obj,tree,key,topology[obj.name],strict=True)
   key.value=0
  print('CLERK_SEAT_REPAIR',sample,hits,flush=True)
