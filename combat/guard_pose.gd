extends RefCounted
## Shared guard for both the base military rig and household-derived actors.
static func apply(actor: Node3D, age: float) -> void:
	var rig: Skeleton3D = actor._skeleton
	var sway := sin(age * 2.4) * .018
	for side in ["l", "r"]:
		var target: Vector3 = actor.to_global(Vector3(.20 if side == "l" else -.20, (1.38 if side == "l" else 1.27) + sway, .27 if side == "l" else .32))
		var local_target := rig.to_local(target)
		var hand := rig.find_bone("hand_" + side)
		if hand < 0: continue
		for iteration in 18:
			for part in ["lowerarm_", "upperarm_"]:
				var index := rig.find_bone(part + side)
				if index < 0: continue
				var current := rig.get_bone_global_pose(index)
				var palm: Vector3 = rig.get_bone_global_pose(hand) * Vector3(0, .055, 0)
				var from_direction := (palm - current.origin).normalized()
				var to_direction := (local_target - current.origin).normalized()
				if from_direction.length_squared() < .5 or to_direction.length_squared() < .5: continue
				var desired := Basis(Quaternion(from_direction, to_direction)) * current.basis
				var parent := rig.get_bone_parent(index)
				if parent >= 0: desired = rig.get_bone_global_pose(parent).basis.inverse() * desired
				rig.set_bone_pose_rotation(index, desired.orthonormalized().get_rotation_quaternion())
				rig.force_update_all_bone_transforms()
			var palm: Vector3 = rig.get_bone_global_pose(hand) * Vector3(0, .055, 0)
			if palm.distance_to(local_target) < .001: break
		actor.set_meta("hand_contact_" + side, (rig.get_bone_global_pose(hand) * Vector3(0, .055, 0)).distance_to(local_target))
		for index in actor._finger_rest:
			var name := rig.get_bone_name(index)
			if not name.ends_with("_" + side): continue
			var curl := .85 if "_01_" in name else (.98 if "_02_" in name else .43)
			if name.begins_with("thumb"): curl *= .55
			rig.set_bone_pose_rotation(index, actor._finger_rest[index] * Quaternion(actor._finger_pitch[index], curl))
