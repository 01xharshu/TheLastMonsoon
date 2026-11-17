extends RefCounted
## Gentle rig-space offsets over Arjun's existing complete MPFB body.
static func make(rig: Skeleton3D, idle: Animation, action: String) -> Animation:
	var clip := Animation.new()
	clip.length = 5.0
	for bone in ["spine_01","spine_02","neck_01","head","upperarm_l","upperarm_r","lowerarm_l","lowerarm_r","hand_l","hand_r"]:
		var index := rig.find_bone(bone)
		if index < 0: continue
		var path := NodePath("Arjun_Rig/Skeleton3D:"+bone)
		var source_track := idle.find_track(path,Animation.TYPE_ROTATION_3D)
		var base: Quaternion = idle.track_get_key_value(source_track,0) if source_track >= 0 else rig.get_bone_pose_rotation(index)
		var axes := rig.get_bone_global_rest(index).basis.orthonormalized().inverse()
		var track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track,path)
		for step in 41:
			var u := float(step)/40.0
			var envelope := smoothstep(0,.18,u)*(1.0-smoothstep(.76,1.0,u))
			var angles := Vector3.ZERO
			var side := 1.0 if bone.ends_with("_l") else -1.0
			match action:
				"look":
					if bone == "head" or bone == "neck_01": angles.y = sin(u*TAU)*.38*envelope
					if bone == "spine_02": angles.y = sin(u*TAU)*.10*envelope
				"scratch":
					if bone == "head": angles = Vector3(.04,0,.09)*envelope
					if bone == "neck_01": angles.z = .035*envelope
				"clothes":
					if bone == "head": angles.x = .16*envelope
					if bone.begins_with("upperarm"): angles = Vector3(-.18,side*.12,-side*.22)*envelope
					if bone.begins_with("lowerarm"): angles.x = (-.72+sin(u*TAU*2)*.10)*envelope
					if bone.begins_with("hand"): angles.x = .12*envelope
				"stretch":
					if bone == "spine_02": angles.x = -.12*envelope
					if bone == "head": angles.x = -.10*envelope
					if bone.begins_with("upperarm"): angles = Vector3(-.7,0,side*.7)*envelope
					if bone.begins_with("lowerarm"): angles.x = -.45*envelope
			var rotation := base*Quaternion(axes*Vector3.RIGHT,angles.x)*Quaternion(axes*Vector3.UP,angles.y)*Quaternion(axes*Vector3.BACK,angles.z)
			clip.rotation_track_insert_key(track,u*clip.length,rotation)
	return clip
