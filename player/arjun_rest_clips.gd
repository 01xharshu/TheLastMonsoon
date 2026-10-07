extends RefCounted
## Editable rig-space rest actions derived from the existing MPFB sit and idle
## clips. Root travel stays with the player and the cot contact solver.

static func make(rig: Skeleton3D, sitting: Animation, idle: Animation, waking: bool) -> Animation:
	var clip := Animation.new()
	clip.length = 0.36 if waking else 0.52
	clip.loop_mode = Animation.LOOP_NONE
	for bone in ["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "head", "thigh_l", "thigh_r", "calf_l", "calf_r", "foot_l", "foot_r", "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "hand_l", "hand_r"]:
		var index := rig.find_bone(bone)
		if index < 0: continue
		var path := NodePath("Arjun_Rig/Skeleton3D:" + bone)
		var sitting_track := sitting.find_track(path, Animation.TYPE_ROTATION_3D)
		var idle_track := idle.find_track(path, Animation.TYPE_ROTATION_3D)
		if sitting_track < 0 and idle_track < 0: continue
		var sit_rotation: Quaternion = sitting.track_get_key_value(sitting_track, 0) if sitting_track >= 0 else rig.get_bone_pose_rotation(index)
		var idle_rotation: Quaternion = idle.track_get_key_value(idle_track, 0) if idle_track >= 0 else rig.get_bone_pose_rotation(index)
		var track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track, path)
		var axes := rig.get_bone_global_rest(index).basis.orthonormalized().inverse()
		for step in 9:
			var phase := float(step) / 8.0
			var recline := 1.0 - phase if waking else phase
			var eased := smoothstep(0.0, 1.0, recline)
			var rotation := sit_rotation.slerp(idle_rotation, eased)
			# A brief arm brace supports the body's weight between sitting and lying.
			# It fades before the relaxed sleep pose and reverses on waking.
			var brace := pow(maxf(0.0, 1.0 - absf(recline - 0.48) / 0.32), 2.0)
			if bone == "upperarm_r":
				rotation *= Quaternion(axes * Vector3.RIGHT, -0.34 * brace) * Quaternion(axes * Vector3.BACK, 0.18 * brace)
			elif bone == "lowerarm_r":
				rotation *= Quaternion(axes * Vector3.RIGHT, -0.38 * brace)
			elif bone == "spine_02":
				rotation *= Quaternion(axes * Vector3.RIGHT, 0.06 * brace)
			clip.rotation_track_insert_key(track, clip.length * phase, rotation)
	return clip
