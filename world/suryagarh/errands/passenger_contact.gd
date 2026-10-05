extends RefCounted
## Wrist position and palm orientation are solved independently; body mesh is untouched.
static func grip(actor: Node3D, cart: Node3D, side: float, blend: float) -> void:
	var rig: Skeleton3D = actor.get("_skeleton")
	var hand_side := "r" if side < 0 else "l"
	var hand := rig.find_bone("hand_"+hand_side)
	# Visible LowSideRail bounds: z 1.825..3.195, upper surface y 1.68.
	var target := cart.to_global(Vector3(side*.87,1.695,1.86))
	var desired_world := Basis(cart.global_basis.z*side,-cart.global_basis.x*side,-cart.global_basis.y).orthonormalized()
	var desired := rig.global_basis.inverse()*desired_world
	desired = rig.get_bone_global_pose(hand).basis.slerp(desired,blend)
	target = actor.palm_world(hand_side).lerp(target,blend)
	var wrist_target := rig.to_local(target)-desired*Vector3(0,.055,0)
	for iteration in 48:
		for label in ["lowerarm_"+hand_side,"upperarm_"+hand_side]:
			var index := rig.find_bone(label)
			var pose := rig.get_bone_global_pose(index)
			var current := rig.get_bone_global_pose(hand).origin
			var from := (current-pose.origin).normalized()
			var to := (wrist_target-pose.origin).normalized()
			if from.length_squared()<.1 or to.length_squared()<.1: continue
			var basis := Basis(Quaternion(from,to))*pose.basis
			var parent := rig.get_bone_parent(index)
			if parent>=0: basis = rig.get_bone_global_pose(parent).basis.inverse()*basis
			rig.set_bone_pose_rotation(index,basis.orthonormalized().get_rotation_quaternion())
			rig.force_update_all_bone_transforms()
		if rig.get_bone_global_pose(hand).origin.distance_to(wrist_target)<.0005: break
	var parent := rig.get_bone_parent(hand)
	var local := rig.get_bone_global_pose(parent).basis.inverse()*desired
	rig.set_bone_pose_rotation(hand,local.orthonormalized().get_rotation_quaternion())
	actor.set_grip(hand_side,.85*blend)
	rig.force_update_all_bone_transforms()
	actor.set_meta("passenger_palm_error_m",actor.palm_world(hand_side).distance_to(target))
	actor.set_meta("passenger_palm_target",target)
	actor.set_meta("passenger_grip_weight",blend)
	actor.set_meta("passenger_palm_normal_dot",(rig.global_basis*rig.get_bone_global_pose(hand).basis.z).normalized().dot(-cart.global_basis.y))

static func cloth(actor: Node3D, amount: float) -> void:
	for node in actor.find_children("*","MeshInstance3D",true,false):
		if node.mesh == null: continue
		for index in node.mesh.get_blend_shape_count():
			if str(node.mesh.get_blend_shape_name(index)) == "PassengerSeatedClearance":
				node.set_blend_shape_value(index,amount)
