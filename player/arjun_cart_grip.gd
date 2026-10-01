extends RefCounted
## Vertical boarding rail grip, independent of the selected weapon.
static func apply(visual: Node3D, vehicle: Node, side: String, contact: float) -> void:
	var skeleton: Skeleton3D = visual.skeleton
	var equipment: Node3D = visual.equipment
	var hand_index := skeleton.find_bone("hand_" + side)
	var hand := skeleton.get_bone_global_pose(hand_index)
	var rail_frame: Basis = vehicle.cart.global_basis
	var fingers: Vector3 = -rail_frame.x * vehicle.transition_side
	var palm_basis := Basis(rail_frame.y, fingers, rail_frame.y.cross(fingers))
	var desired: Basis = skeleton.global_basis.inverse() * palm_basis * (equipment.palm_axes[side] as Basis).inverse()
	var blended: Basis = hand.basis.slerp(desired, contact).orthonormalized()
	var target: Vector3 = skeleton.to_local(vehicle.transition_hand_world() + palm_basis.z * .018)
	var palm: Vector3 = hand * equipment.palm_offsets[side]
	var destination := palm.lerp(target, contact)
	for iteration in 4:
		equipment._solve_arm(side, destination - blended * equipment.palm_offsets[side])
		var parent := skeleton.get_bone_parent(hand_index)
		var rotation := (skeleton.get_bone_global_pose(parent).basis.inverse() * blended).orthonormalized().get_rotation_quaternion()
		skeleton.set_bone_pose_rotation(hand_index, rotation)
		skeleton.force_update_all_bone_transforms()
	for finger in ["index", "middle", "ring", "pinky", "thumb"]:
		for joint in ["01", "02", "03"]:
			var name: String = finger + "_" + joint + "_" + side
			skeleton.set_bone_pose_rotation(skeleton.find_bone(name), equipment.rest_rotations[name])
	var palm_frame: Basis = blended * equipment.palm_axes[side]
	for finger in ["index", "middle", "ring", "pinky"]:
		equipment._rotate_digit(finger + "_01_" + side, palm_frame.x, 1.05 * contact)
		equipment._rotate_digit(finger + "_02_" + side, palm_frame.x, .95 * contact)
		equipment._rotate_digit(finger + "_03_" + side, palm_frame.x, .58 * contact)
	equipment._rotate_digit("thumb_01_" + side, palm_frame.y, (.55 if side == "l" else -.55) * contact)
	equipment._rotate_digit("thumb_02_" + side, palm_frame.x, .65 * contact)
	equipment._rotate_digit("thumb_03_" + side, palm_frame.x, .35 * contact)
