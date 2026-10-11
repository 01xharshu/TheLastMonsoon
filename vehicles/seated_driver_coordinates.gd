extends RefCounted
## Keep contact calculations in the vehicle frame, avoiding world-coordinate cancellation.
static func relative(node: Node3D,ancestor: Node3D) -> Transform3D:
 var result := Transform3D.IDENTITY
 var cursor: Node = node
 while cursor != ancestor:
  assert(cursor != null,"Driver contact node is outside its vehicle")
  if cursor is Node3D:
   if cursor.is_set_as_top_level(): return ancestor.global_transform.affine_inverse()*node.global_transform
   result=cursor.transform*result
  cursor=cursor.get_parent()
 return result

static func anchor(driver: Node3D,coach: Node3D,socket: Node3D) -> void:
 var rig: Skeleton3D = driver._skeleton
 var parent_to_coach := relative(driver.get_parent(),coach)
 var socket_to_parent := parent_to_coach.affine_inverse()*relative(socket,coach)
 driver.rotation.y=socket_to_parent.basis.get_euler().y+PI
 var pelvis := rig.find_bone("pelvis")
 var hip_parent: Vector3 = driver.transform*(relative(rig,driver)*rig.get_bone_global_pose(pelvis).origin)
 driver.position+=socket_to_parent.origin+parent_to_coach.basis.inverse()*Vector3.UP*.11-hip_parent
 var rig_to_coach := relative(rig,coach)
 for side in ["l","r"]:
  var foot: Vector3 = driver.foot_target_local(side)
  driver.foot_targets[side]=coach.to_global(foot)
  driver.foot_plant._solve(driver.foot_plant.legs[side],rig_to_coach.affine_inverse()*foot)
  var grip: Vector3 = coach.rein_grip_local(side)
  hand_contact(driver,side,rig_to_coach.affine_inverse()*grip,rig_to_coach.basis)
  driver.set_grip(side,.7)

static func hand_contact(driver: Node3D,side: String,target: Vector3,to_coach: Basis) -> void:
 var rig: Skeleton3D = driver._skeleton
 var hand := rig.find_bone("hand_"+side)
 for iteration in 18:
  for part in ["lowerarm_","upperarm_"]:
   var index := rig.find_bone(part+side)
   var current := rig.get_bone_global_pose(index)
   var palm: Vector3 = rig.get_bone_global_pose(hand)*Vector3(0,.055,0)
   var from_direction := (palm-current.origin).normalized()
   var to_direction := (target-current.origin).normalized()
   var desired := Basis(Quaternion(from_direction,to_direction))*current.basis
   var parent := rig.get_bone_parent(index)
   if parent>=0: desired=rig.get_bone_global_pose(parent).basis.inverse()*desired
   rig.set_bone_pose_rotation(index,desired.orthonormalized().get_rotation_quaternion())
   rig.force_update_all_bone_transforms()
  var gap: Vector3 = (rig.get_bone_global_pose(hand)*Vector3(0,.055,0))-target
  if (to_coach*gap).length()<.001: break
 var gap: Vector3 = (rig.get_bone_global_pose(hand)*Vector3(0,.055,0))-target
 driver.set_meta("hand_contact_"+side,(to_coach*gap).length())
