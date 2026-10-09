extends RefCounted
## Small continuous outer wrap follows leg positions; original complete body stays.
const SIDES:=32
const ROWS:=10
var actor:Node3D
var rig:Skeleton3D
var garment:MeshInstance3D
var previous:PackedVector3Array=[]
func _init(person:Node3D,skeleton:Skeleton3D)->void:
 actor=person;rig=skeleton
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
 var hip:=point("pelvis");var thighs:=(point("thigh_l")+point("thigh_r"))*.5
 var knees:=(point("calf_l")+point("calf_r"))*.5
 var feet:=(point("foot_l")+point("foot_r"))*.5
 var pose:=PackedVector3Array([hip,thighs,knees,feet,point("calf_l"),point("calf_r")])
 if previous.size()==pose.size():
  var dirty:=false
  for i in pose.size():
   if pose[i].distance_squared_to(previous[i])>.00000025:dirty=true;break
  if not dirty:return
 previous=pose
 var points:=PackedVector3Array();var normals:=PackedVector3Array();var uv:=PackedVector2Array();var ids:=PackedInt32Array()
 var centres:PackedVector3Array=[]
 for row in ROWS:
  var t:=float(row)/(ROWS-1)
  centres.append((hip+Vector3.UP*.12).lerp(thighs,t/.16) if t<.16 else thighs.lerp(knees.lerp(feet,.12),(t-.16)/.84))
 for row in ROWS:
  var t:=float(row)/(ROWS-1)
  var tangent:Vector3=(centres[mini(ROWS-1,row+1)]-centres[maxi(0,row-1)]).normalized()
  var right:Vector3=(Vector3.RIGHT-tangent*Vector3.RIGHT.dot(tangent)).normalized()
  var front:Vector3=right.cross(tangent).normalized()
  var span:Vector3=(point("thigh_l")-point("thigh_r")).lerp(point("calf_l")-point("calf_r"),t)
  var width:=.135+absf(span.dot(right))*.5
  var depth:=.15+absf(span.dot(front))*.5
  if row==0:width=.235;depth=.18
  for side in SIDES:
   var a:=TAU*side/SIDES;var fold:=.003*(1+cos(a*8))
   points.append(centres[row]+right*cos(a)*(width+fold)+front*sin(a)*(depth+fold))
   normals.append((right*cos(a)/width+front*sin(a)/depth).normalized());uv.append(Vector2(float(side)/SIDES,t))
 for row in ROWS-1:
  for side in SIDES:
   var a:=row*SIDES+side;var b:=row*SIDES+(side+1)%SIDES
   ids.append_array(PackedInt32Array([a,b,a+SIDES,b,b+SIDES,a+SIDES]))
 var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=points;arrays[Mesh.ARRAY_NORMAL]=normals
 arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=ids
 var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);garment.mesh=mesh
