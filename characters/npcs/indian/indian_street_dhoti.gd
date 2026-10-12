extends RefCounted
## Small continuous outer wrap follows leg positions; original complete body stays.
const SIDES:=32
const ROWS:=10
var actor:Node3D
var rig:Skeleton3D
var garment:MeshInstance3D
var previous:PackedVector3Array=[]
var mesh: ArrayMesh
var normal_offset := 0
var normal_stride := 0
var cosines: Array[float]=[]
var sines: Array[float]=[]
var folds: Array[float]=[]
func _init(person:Node3D,skeleton:Skeleton3D)->void:
 actor=person;rig=skeleton
 for side in SIDES:
  var angle:=TAU*side/SIDES
  cosines.append(cos(angle));sines.append(sin(angle));folds.append(.003*(1+cos(angle*8)))
 var cloth:Material
 for node:MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
  if "Street folded dhoti" in node.name:
   cloth=node.get_active_material(0);node.hide()
 if cloth==null:return
 garment=MeshInstance3D.new();garment.name="ContinuousStreetDhoti";actor.add_child(garment)
 garment.material_override=cloth
func point(label:String)->Vector3:
 return actor.to_local(rig.to_global(rig.get_bone_global_pose(rig.find_bone(label)).origin))
func update()->void:
 if garment==null:return
 var hip:=point("pelvis");var left_thigh:=point("thigh_l");var right_thigh:=point("thigh_r")
 var left_knee:=point("calf_l");var right_knee:=point("calf_r")
 var thighs:=(left_thigh+right_thigh)*.5
 var knees:=(left_knee+right_knee)*.5
 var feet:=(point("foot_l")+point("foot_r"))*.5
 var pose:=PackedVector3Array([hip,thighs,knees,feet,left_knee,right_knee])
 if previous.size()==pose.size():
  var dirty:=false
  for i in pose.size():
   if pose[i].distance_squared_to(previous[i])>.00000025:dirty=true;break
  if not dirty:return
 previous=pose
 var points:=PackedVector3Array();points.resize(ROWS*SIDES)
 var normals:=PackedVector3Array();normals.resize(ROWS*SIDES)
 var uv:=PackedVector2Array();var ids:=PackedInt32Array()
 var bounds:=AABB()
 var centres:PackedVector3Array=[]
 for row in ROWS:
  var t:=float(row)/(ROWS-1)
  centres.append((hip+Vector3.UP*.12).lerp(thighs,t/.16) if t<.16 else thighs.lerp(knees.lerp(feet,.12),(t-.16)/.84))
 for row in ROWS:
  var t:=float(row)/(ROWS-1)
  var tangent:Vector3=(centres[mini(ROWS-1,row+1)]-centres[maxi(0,row-1)]).normalized()
  var right:Vector3=(Vector3.RIGHT-tangent*Vector3.RIGHT.dot(tangent)).normalized()
  var front:Vector3=right.cross(tangent).normalized()
  var span:Vector3=(left_thigh-right_thigh).lerp(left_knee-right_knee,t)
  var width:=.135+absf(span.dot(right))*.5
  var depth:=.15+absf(span.dot(front))*.5
  if row==0:width=.235;depth=.18
  for side in SIDES:
   var ca: float=cosines[side];var sa: float=sines[side];var fold: float=folds[side]
   var vertex: Vector3=centres[row]+right*ca*(width+fold)+front*sa*(depth+fold)
   points[row*SIDES+side]=vertex
   bounds=AABB(vertex,Vector3.ZERO) if row==0 and side==0 else bounds.expand(vertex)
   normals[row*SIDES+side]=(right*ca/width+front*sa/depth).normalized()
   if mesh==null:uv.append(Vector2(float(side)/SIDES,t))
 if mesh==null:
  for row in ROWS-1:
   for side in SIDES:
    var a:=row*SIDES+side;var b:=row*SIDES+(side+1)%SIDES
    ids.append_array(PackedInt32Array([a,b,a+SIDES,b,b+SIDES,a+SIDES]))
  var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=points;arrays[Mesh.ARRAY_NORMAL]=normals
  arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=ids
  mesh=ArrayMesh.new()
  mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_DYNAMIC_UPDATE)
  normal_offset=RenderingServer.mesh_surface_get_format_offset(mesh.surface_get_format(0),points.size(),Mesh.ARRAY_NORMAL)
  normal_stride=RenderingServer.mesh_surface_get_format_normal_tangent_stride(mesh.surface_get_format(0),points.size())
  garment.mesh=mesh
 else:
  mesh.surface_update_vertex_region(0,0,points.to_byte_array())
  var packed:=PackedByteArray();packed.resize(normals.size()*normal_stride)
  for i in normals.size():
   var oct: Vector2=normals[i].octahedron_encode()
   # Vector2 multiplication retains the engine's float32 quantisation before integer conversion.
   var encoded: Vector2=oct*65535.0
   packed.encode_u16(i*normal_stride,int(clampf(encoded.x,0,65535)))
   packed.encode_u16(i*normal_stride+2,int(clampf(encoded.y,0,65535)))
   # Godot generates a tangent even when only normals were supplied. Both are interleaved.
   var n: Vector3=normals[i]
   var tangent: Vector3=Vector3(n.z,-n.x,n.y).cross(n.normalized()).normalized()
   var tangent_oct: Vector2=tangent.octahedron_encode()
   tangent_oct.y=maxf(tangent_oct.y,1.0/32767.0)*.5+.5
   var tangent_encoded: Vector2=tangent_oct*65535.0
   var tx:=int(clampf(tangent_encoded.x,0,65535))
   var ty:=int(clampf(tangent_encoded.y,0,65535))
   if tx==0 and ty==65535:tx=65535
   packed.encode_u16(i*normal_stride+4,tx);packed.encode_u16(i*normal_stride+6,ty)
  mesh.surface_update_vertex_region(0,normal_offset,packed)
 # Uploaded vertex changes do not recalculate the resource's bounds.
 mesh.custom_aabb=bounds
