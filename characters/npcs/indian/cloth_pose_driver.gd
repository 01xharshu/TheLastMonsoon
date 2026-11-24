extends RefCounted
## Garment-only corrective targets selected by the actual articulated pose.
static var bank: Dictionary={}
var rig: Skeleton3D
var poses: Dictionary={}
var meshes: Array[MeshInstance3D]=[]
var dependencies: Dictionary={}
var pose_bones: Dictionary={}
func configure(actor: Node3D,skeleton: Skeleton3D) -> void:
 rig=skeleton
 var role: String=str(actor.get_meta("body_base",""))
 if role.is_empty():return
 if bank.is_empty() and FileAccess.file_exists("res://characters/npcs/workplace_repair/pose_driver.json"):
  var data=JSON.parse_string(FileAccess.get_file_as_string("res://characters/npcs/workplace_repair/pose_driver.json"))
  if data is Dictionary:bank=data
 poses=bank.get(role,{})
 for sample in poses:
  for name in poses[sample]:
   var index: int=rig.find_bone(name)
   if index>=0:pose_bones[name]=index
 for mesh in actor.find_children("*","MeshInstance3D",true,false):
  if mesh.mesh!=null and mesh.mesh.get_blend_shape_count()>0:
   meshes.append(mesh)
   dependencies[mesh.get_instance_id()]=_skin_dependencies(mesh)
func _skin_dependencies(mesh: MeshInstance3D) -> Dictionary:
 var result: Dictionary={}
 if mesh.skin==null:return result
 var ancestors: Array[String]=[]
 for bind in mesh.skin.get_bind_count():
  var index: int=mesh.skin.get_bind_bone(bind)
  if index<0:index=rig.find_bone(mesh.skin.get_bind_name(bind))
  var tracked: String=""
  while index>=0:
   var name: String=rig.get_bone_name(index)
   if pose_bones.has(name):
    tracked=name
    break
   index=rig.get_bone_parent(index)
  ancestors.append(tracked)
 for surface in mesh.mesh.get_surface_count():
  var arrays: Array=mesh.mesh.surface_get_arrays(surface)
  var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
  var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
  for slot in weights.size():
   if weights[slot]<=0:continue
   var name: String=ancestors[bones[slot]]
   if not name.is_empty():result[name]=float(result.get(name,0))+weights[slot]
 var total: float=0.0
 for amount in result.values():total+=float(amount)
 if total>0:
  for name in result:result[name]=float(result[name])/total
 return result
func apply() -> void:
 if poses.is_empty() or meshes.is_empty():return
 # Evaluate articulated error once, then weight it by each garment's actual
 # skin dependencies. Arm motion must not choose a lower-wrap correction.
 var current: Dictionary={}
 for name in pose_bones:current[name]=rig.get_bone_pose_rotation(pose_bones[name]).normalized()
 var errors: Dictionary={}
 for sample in poses:
  var components: Dictionary={}
  for name in poses[sample]:
   if not current.has(name):continue
   var v: Array=poses[sample][name]
   var reference:=Quaternion(float(v[0]),float(v[1]),float(v[2]),float(v[3])).normalized()
   components[name]=maxf(0.0,1-absf((current[name] as Quaternion).dot(reference)))
  errors[sample]=components
 for mesh in meshes:
  var influence: Dictionary=dependencies.get(mesh.get_instance_id(),{})
  var distances: Array=[]
  for sample in errors:
   var distance: float=0.0
   var full_body: float=0.0
   for name in errors[sample]:
    full_body+=float(errors[sample][name])
    distance+=float(errors[sample][name])*(float(influence.get(name,0)) if not influence.is_empty() else 1.0)
   distances.append([sample,distance,full_body])
  # Equivalent governing-bone poses can still differ in nearby body contact.
  # Resolve only an exact tie with the whole pose, never list order.
  distances.sort_custom(func(a,b):
   if float(a[1])==float(b[1]):
    if float(a[2])==float(b[2]):return str(a[0])<str(b[0])
    return a[2]<b[2]
   return a[1]<b[1])
  var first: float=float(distances[0][1])
  var second: float=float(distances[1][1]) if distances.size()>1 else first
  if distances.size()>1 and first<=1e-8 and second<=1e-8:
   first=float(distances[0][2]);second=float(distances[1][2])
  var weights: Dictionary={str(distances[0][0]):1.0}
  if distances.size()>1 and first>.00000001:
   # A nearby fitted fold dominates; broad mixing can cross the body between
   # individually safe shapes positioned on different sides of a bent joint.
   var a: float=1/pow(maxf(first,.00000001),2)
   var b: float=1/pow(maxf(second,.00000001),2)
   weights={str(distances[0][0]):a/(a+b),str(distances[1][0]):b/(a+b)}
  for key in mesh.mesh.get_blend_shape_count():
   var label: String=str(mesh.mesh.get_blend_shape_name(key))
   if label.begins_with("Contact_"):
    var target: float=float(weights.get(label.trim_prefix("Contact_"),0))
    if not is_equal_approx(target,mesh.get_blend_shape_value(key)):mesh.set_blend_shape_value(key,target)
