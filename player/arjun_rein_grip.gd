extends RefCounted
## Rein grip independent of the selected/stowed weapon's trigger-finger pose.
static func apply(visual: Node3D, frame: Basis, targets: Dictionary) -> void:
 var skeleton: Skeleton3D = visual.skeleton
 var equipment: Node3D = visual.equipment
 for side in ["l", "r"]:
  var inward: Vector3 = frame.x*(1.0 if side == "l" else -1.0)
  inward = (inward*.45-frame.y*.89).normalized()
  var fingers: Vector3 = (-frame.z).normalized()
  var across := fingers.cross(inward).normalized()
  var palm_basis := Basis(across,fingers,inward)
  var desired: Basis = skeleton.global_basis.inverse()*palm_basis*(equipment.palm_axes[side] as Basis).inverse()
  var target: Vector3 = skeleton.to_local(targets[side])
  var pole: Vector3 = skeleton.global_basis.inverse()*(frame.x*(-.35 if side == "l" else .35)-frame.y*.85+frame.z*.15)
  var hand_index := skeleton.find_bone("hand_"+side)
  for iteration in 3:
   equipment._solve_arm(side,target-desired*equipment.palm_offsets[side],pole)
   var parent := skeleton.get_bone_parent(hand_index)
   var rotation := (skeleton.get_bone_global_pose(parent).basis.inverse()*desired).orthonormalized().get_rotation_quaternion()
   skeleton.set_bone_pose_rotation(hand_index,rotation)
   skeleton.force_update_all_bone_transforms()
  for finger in ["index","middle","ring","pinky","thumb"]:
   for joint in ["01","02","03"]:
    var name: String = finger+"_"+joint+"_"+side
    skeleton.set_bone_pose_rotation(skeleton.find_bone(name),equipment.rest_rotations[name])
  skeleton.force_update_all_bone_transforms()
  var palm: Basis = desired*(equipment.palm_axes[side] as Basis)
  for finger in ["index","middle","ring","pinky"]:
   var curl := 1.02 if finger == "index" else 1.12
   equipment._rotate_digit(finger+"_01_"+side,palm.x,curl)
   equipment._rotate_digit(finger+"_02_"+side,palm.x,.95)
   equipment._rotate_digit(finger+"_03_"+side,palm.x,.58)
  equipment._rotate_digit("thumb_01_"+side,palm.y,.55 if side == "r" else -.55)
  equipment._rotate_digit("thumb_02_"+side,palm.x,.60)
  equipment._rotate_digit("thumb_03_"+side,palm.x,.30)
