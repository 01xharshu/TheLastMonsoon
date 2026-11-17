extends RefCounted
## A supported floor sit: squat, settle, extend each leg, then relax.
## Pose tracks own torso motion; joint targets own contact, with no root travel.
const LENGTH := 3.6

static func make(rig: Skeleton3D, idle: Animation) -> Animation:
	var clip := Animation.new()
	clip.length = LENGTH
	for bone in ["pelvis","spine_01","spine_02","spine_03","neck_01","head","thigh_l","thigh_r","calf_l","calf_r","foot_l","foot_r","upperarm_l","upperarm_r","lowerarm_l","lowerarm_r","hand_l","hand_r"]:
		var index := rig.find_bone(bone)
		if index < 0: continue
		var path := NodePath("Arjun_Rig/Skeleton3D:"+bone)
		var source := idle.find_track(path,Animation.TYPE_ROTATION_3D)
		var base: Quaternion = idle.track_get_key_value(source,0) if source >= 0 else rig.get_bone_pose_rotation(index)
		var axes := rig.get_bone_global_rest(index).basis.orthonormalized().inverse()
		var track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track,path)
		for step in 61:
			var u := float(step)/60.0
			var squat := smoothstep(.08,.35,u)*(1.0-smoothstep(.55,.88,u))
			var settled := smoothstep(.75,1.0,u)
			var angles := Vector3.ZERO
			if bone == "spine_01": angles.x = .20*squat+.035*settled
			if bone == "spine_02": angles.x = .08*squat
			if bone == "head": angles.x = -.12*squat+.035*settled
			var rotation := base*Quaternion(axes*Vector3.RIGHT,angles.x)
			clip.rotation_track_insert_key(track,u*LENGTH,rotation)
	return clip

static func hip_fraction(u: float) -> float:
	return .70*smoothstep(.04,.45,u)+.30*smoothstep(.45,.80,u)

static func leg_fraction(u: float, side: String) -> float:
	return smoothstep(.42,.64,u) if side == "l" else smoothstep(.64,.88,u)

static func hand_contact(visual: Node3D, side: String, world_target: Vector3, fingers_world: Vector3, normal_world: Vector3, weight: float) -> void:
	if weight <= 0.0: return
	var rig: Skeleton3D = visual.skeleton
	var equipment: Node = visual.equipment
	var hand_index: int = visual.bones["hand_"+side]
	var forearm_index: int = visual.bones["lowerarm_"+side]
	var before := {}
	for bone in ["upperarm_"+side,"lowerarm_"+side,"hand_"+side]: before[bone] = rig.get_bone_pose_rotation(visual.bones[bone])
	var sign_side := 1.0 if side == "l" else -1.0
	var facing: Basis = visual.actor.get_node("VisualRoot").global_basis.orthonormalized()
	var pole: Vector3 = rig.global_basis.inverse()*facing*Vector3(sign_side*.75,-.50,-.10)
	var normal: Vector3 = (rig.global_basis.inverse()*normal_world).normalized()
	var fingers: Vector3 = (rig.global_basis.inverse()*fingers_world).normalized()
	fingers = (fingers-normal*fingers.dot(normal)).normalized()
	var across := fingers.cross(normal).normalized()
	var desired: Basis = Basis(across,fingers,normal)*(equipment.palm_axes[side] as Basis).inverse()
	for pass_index in 3:
		var hand := rig.get_bone_global_pose(hand_index)
		solve_limb(visual,"upperarm_"+side,"lowerarm_"+side,"hand_"+side,rig.to_local(world_target)-hand.basis*equipment.palm_offsets[side],pole,2.50)
	var forearm := rig.get_bone_global_pose(forearm_index)
	var hand := rig.get_bone_global_pose(hand_index)
	var axis := (hand.origin-forearm.origin).normalized()
	var palm_normal: Vector3 = (hand.basis*(equipment.palm_axes[side] as Basis)).z
	var from_normal := palm_normal-axis*palm_normal.dot(axis)
	var to_normal := normal-axis*normal.dot(axis)
	var roll: float = visual.idle_hand_roll[side]
	if from_normal.length() > .2 and to_normal.length() > .2:
		var requested := from_normal.normalized().signed_angle_to(to_normal.normalized(),axis)
		# Nearly opposite normals have two equally valid rotations. Keep the
		# previous side of the forearm, never flip by 180 degrees on a new frame.
		if absf(requested) > 2.5 and absf(roll) > .02: requested = absf(requested)*signf(roll)
		roll = move_toward(roll,clampf(requested,-.65,.65),minf(visual.get_process_delta_time(),1.0/30.0)*2.5)
	visual.idle_hand_roll[side] = roll
	var rolled := Basis(Quaternion(axis,roll))*forearm.basis
	var parent := rig.get_bone_parent(forearm_index)
	rig.set_bone_pose_rotation(forearm_index,(rig.get_bone_global_pose(parent).basis.inverse()*rolled).orthonormalized().get_rotation_quaternion())
	rig.force_update_all_bone_transforms()
	var local := (rig.get_bone_global_pose(forearm_index).basis.inverse()*desired).orthonormalized().get_rotation_quaternion()
	var neutral: Quaternion = equipment.rest_rotations["hand_"+side]
	var angle := neutral.angle_to(local)
	rig.set_bone_pose_rotation(hand_index,neutral.slerp(local,minf(1.0,.55/maxf(angle,.001))))
	for bone in before:
		var index: int = visual.bones[bone]
		rig.set_bone_pose_rotation(index,(before[bone] as Quaternion).slerp(rig.get_bone_pose_rotation(index),weight))
	equipment._grasp(side,.08*weight)
	rig.force_update_all_bone_transforms()

static func solve_limb(visual: Node, upper: String, lower: String, end: String, target: Vector3, pole: Vector3, max_flex: float) -> void:
	var rig: Skeleton3D = visual.skeleton
	var origin := rig.get_bone_global_pose(visual.bones[upper]).origin
	var a := rig.get_bone_global_rest(visual.bones[upper]).origin.distance_to(rig.get_bone_global_rest(visual.bones[lower]).origin)
	var b := rig.get_bone_global_rest(visual.bones[lower]).origin.distance_to(rig.get_bone_global_rest(visual.bones[end]).origin)
	var direction := (target-origin).normalized()
	var minimum := sqrt(maxf(.001,a*a+b*b+2.0*a*b*cos(max_flex)))
	var distance := clampf(origin.distance_to(target),minimum,a+b-.004)
	var bend := (pole-direction*pole.dot(direction)).normalized()
	var frame := Engine.get_process_frames()
	if visual.idle_bend.has(upper):
		var previous: Dictionary = visual.idle_bend[upper]
		var prior: Vector3 = previous.bend
		prior = (prior-direction*prior.dot(direction)).normalized()
		if not prior.is_zero_approx():
			if previous.frame == frame:
				bend = prior
			else:
				var turn := prior.signed_angle_to(bend,direction)
				var limit: float = minf(visual.get_process_delta_time(),1.0/30.0)*5.0
				bend = Quaternion(direction,clampf(turn,-limit,limit))*prior
	visual.idle_bend[upper] = {"frame":frame,"bend":bend}
	var along := (a*a-b*b+distance*distance)/(2.0*distance)
	var joint := origin+direction*along+bend*sqrt(maxf(0.0,a*a-along*along))
	var plane := bend.cross(direction).normalized()
	orient_joint(visual,upper,lower,joint,plane)
	orient_joint(visual,lower,end,origin+direction*distance,plane)

static func foot_contact(visual: Node, side: String, target_world: Vector3, pole: Vector3, weight: float) -> void:
	var rig: Skeleton3D = visual.skeleton
	var index: int = visual.bones["foot_"+side]
	var rest := rig.get_bone_global_rest(index)
	var before := {}
	for name in ["thigh_"+side,"calf_"+side,"foot_"+side]: before[name] = rig.get_bone_pose_rotation(visual.bones[name])
	var offset := rest.basis.inverse()*Vector3(0,-.085,.06)
	var target := rig.to_local(target_world)-rest.basis*offset
	solve_limb(visual,"thigh_"+side,"calf_"+side,"foot_"+side,target,pole,2.60)
	var parent := rig.get_bone_parent(index)
	var local := rig.get_bone_global_pose(parent).basis.inverse()*rest.basis
	rig.set_bone_pose_rotation(index,local.orthonormalized().get_rotation_quaternion())
	for name in before:
		var bone_index: int = visual.bones[name]
		rig.set_bone_pose_rotation(bone_index,(before[name] as Quaternion).slerp(rig.get_bone_pose_rotation(bone_index),weight))
	rig.force_update_all_bone_transforms()

static func orient_joint(visual: Node, bone: String, child: String, endpoint: Vector3, plane: Vector3) -> void:
	var rig: Skeleton3D = visual.skeleton
	var index: int = visual.bones[bone]
	var current := rig.get_bone_global_pose(index)
	var direction := (endpoint-current.origin).normalized()
	var hinge := (plane-direction*plane.dot(direction)).normalized()
	var child_axis := rig.get_bone_pose_position(visual.bones[child]).normalized()
	var facing: Basis = visual.actor.get_node("VisualRoot").global_basis.orthonormalized()
	var anatomical_world: Vector3 = facing.x if bone.begins_with("thigh") or bone.begins_with("calf") else facing.y*(-1.0 if bone.ends_with("_l") else 1.0)
	var anatomical_rig: Vector3 = rig.global_basis.inverse()*anatomical_world
	var native_hinge := rig.get_bone_global_rest(index).basis.inverse()*anatomical_rig
	var local_x := (native_hinge-child_axis*native_hinge.dot(child_axis)).normalized()
	if not visual.idle_axis_sign.has(bone):
		visual.idle_axis_sign[bone] = 1.0 if (current.basis*local_x).dot(hinge) >= 0.0 else -1.0
	hinge *= float(visual.idle_axis_sign[bone])
	var native_frame := Basis(local_x,child_axis,local_x.cross(child_axis))
	var desired := Basis(hinge,direction,hinge.cross(direction))*native_frame.inverse()
	var parent := rig.get_bone_parent(index)
	rig.set_bone_pose_rotation(index,(rig.get_bone_global_pose(parent).basis.inverse()*desired).orthonormalized().get_rotation_quaternion())
	rig.force_update_all_bone_transforms()
