extends Node3D
## Outer garment only. Complete MPFB body and opaque foundations stay untouched.
var actor:Node3D
var rig:Skeleton3D
var garment:MeshInstance3D
var female:=false
var cotton:Material
var border:Material
var previous:Array[Vector3]=[]
var waist_anchors:Array[Vector3]=[]
var rebuilds:=0
var max_rebuild_us:=0
var measure_cost:=false
var rebuild_costs:=PackedInt32Array()
const SIDES:=32
const ROWS:=9
func configure(person:Node3D) -> bool:
 actor=person;rig=actor.get("_skeleton");female=actor.get("movement_profile")==&"female"
 var originals:Array[MeshInstance3D]=[]
 for node in actor.find_children("*","MeshInstance3D",true,false):
  var label:=node.name.to_lower()
  if "gathered skirt" in label or "wrapped dhoti" in label:
   cotton=node.get_active_material(0);originals.append(node)
  elif "dhoti woven border" in label:
   border=node.get_active_material(0);originals.append(node)
  # Keep the fitted waist transition as the original opaque waistband.
 if cotton==null:return false
 waist_anchors=preload("res://characters/npcs/households/household_waist_fit.gd").anchors(actor,rig,SIDES)
 for node in originals:node.hide()
 garment=MeshInstance3D.new();garment.name="ContinuousOuterDrapeCandidate";add_child(garment)
 actor.set_meta("coach_dress",garment)
 update_pose();return true
func _joint(label:String) -> Vector3:
 return actor.to_local(rig.to_global(rig.get_bone_global_pose(rig.find_bone(label)).origin))
func update_pose() -> void:
 var hip:=_joint("pelvis")
 garment.global_transform=Transform3D(actor.global_basis,actor.to_global(hip))
 var pose:Array[Vector3]=[hip,_joint("thigh_l"),_joint("thigh_r"),_joint("calf_l"),_joint("calf_r"),_joint("foot_l"),_joint("foot_r")]
 var dirty:=previous.size()!=pose.size()
 if not dirty:
  for i in pose.size():
   if pose[i].distance_squared_to(previous[i])>.00000025:dirty=true;break
 if not dirty:return
 previous=pose.duplicate()
 var start:=Time.get_ticks_usec()
 var hips:Vector3=(pose[1]+pose[2])*.5
 var knees:Vector3=(pose[3]+pose[4])*.5
 var feet:Vector3=(pose[5]+pose[6])*.5
 var centres:Array[Vector3]=[];var spans:Array[Vector3]=[]
 for row in ROWS:
  var t:=row/float(ROWS-1)
  if t<.15:
   centres.append((hip+Vector3.UP*.12).lerp(hips,(t/.15)))
   spans.append(pose[1]-pose[2])
  elif t<.62:
   var u:float=(t-.15)/.47
   centres.append(hips.lerp(knees,u));spans.append((pose[1]-pose[2]).lerp(pose[3]-pose[4],u))
  else:
   var u:float=(t-.62)/.38
   var end:Vector3=feet+Vector3.UP*.08 if female else knees.lerp(feet,.22)
   centres.append(knees.lerp(end,u));spans.append((pose[3]-pose[4]).lerp(pose[5]-pose[6],u if female else u*.22))
 var points:=PackedVector3Array()
 var normals:=PackedVector3Array()
 var uvs:=PackedVector2Array()
 for row in ROWS:
  var t:=row/float(ROWS-1)
  var tangent:Vector3=(centres[mini(row+1,ROWS-1)]-centres[maxi(row-1,0)]).normalized()
  var right:Vector3=(Vector3.RIGHT-tangent*Vector3.RIGHT.dot(tangent)).normalized()
  if right.length_squared()<.5:right=Vector3.RIGHT
  var cross:=right.cross(tangent).normalized()
  var width:float=.11+absf(spans[row].dot(right))*.5
  var depth:float=.115+absf(spans[row].dot(cross))*.5
  if row==0:width=.225 if female else .215;depth=.22 if female else .18
  elif female:width+=.09*t;depth+=.055*t+.075*sin(t*PI)+.025
  else:width+=.025*t;depth+=.025*t
  for side in SIDES:
   var angle:=TAU*side/SIDES
   var fold:=1+.035*sin(angle*8)
   var at:=centres[row]-hip+(right*cos(angle)*width+cross*sin(angle)*depth)*fold
   var waist:=actor.to_local(rig.to_global(rig.get_bone_global_pose(rig.find_bone("pelvis"))*waist_anchors[side]))-hip
   if row==0:at=waist
   elif row==1:at=waist.lerp(at,.45)
   points.append(at)
   normals.append((right*cos(angle)/width+cross*sin(angle)/depth).normalized())
   uvs.append(Vector2(float(side)/SIDES,t))
 var result:=ArrayMesh.new()
 for panel in (2 if not female and border!=null else 1):
  var indices:=PackedInt32Array()
  for row in ROWS-1:
   if border!=null and not female and ((row>=ROWS-3)!=(panel==1)):continue
   for side in SIDES:
    var a:=row*SIDES+side;var b:=row*SIDES+(side+1)%SIDES
    indices.append_array(PackedInt32Array([a,b,a+SIDES,b,b+SIDES,a+SIDES]))
  var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
  arrays[Mesh.ARRAY_VERTEX]=points;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_INDEX]=indices
  result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
  result.surface_set_material(panel,border if panel==1 else cotton)
 garment.mesh=result;rebuilds+=1
 var cost:=Time.get_ticks_usec()-start
 max_rebuild_us=maxi(max_rebuild_us,cost)
 if measure_cost:rebuild_costs.append(cost)
 actor.set_meta("drape_rebuilds",rebuilds);actor.set_meta("drape_max_rebuild_us",max_rebuild_us)
