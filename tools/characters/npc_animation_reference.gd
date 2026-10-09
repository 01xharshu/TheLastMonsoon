extends "res://characters/npcs/households/household_npc_actor.gd"
## Original uncached animation generation and stride calibration for parity checks.
func _measure_stride(clip: Animation) -> void:
	# Calibrate cadence to this rig's actual ankle excursion, not its sex/size label.
	var foot := _skeleton.find_bone("foot_l")
	var minimum := INF
	var maximum := -INF
	for frame in 65:
		for track in clip.get_track_count():
			var bone_name := str(clip.track_get_path(track)).get_slice(":", 1)
			_skeleton.set_bone_pose_rotation(_bones[bone_name], clip.track_get_key_value(track, frame))
		var z := _skeleton.get_bone_global_pose(foot).origin.z
		minimum = minf(minimum, z)
		maximum = maxf(maximum, z)
	# A cycle has two stance strokes across the ankle excursion.
	nominal_walk_speed = maxf(0.05, 2.0 * (maximum - minimum) / clip.length)
	for bone_name in _base_rotations:
		_skeleton.set_bone_pose_rotation(_bones[bone_name], _base_rotations[bone_name])

func _make_clip(walking: bool, turning: bool = false) -> Animation:
	var clip := Animation.new()
	var female := movement_profile == &"female"
	clip.length = (1.05 if female else 0.85) if walking else 3.5
	if turning:
		clip.length = 0.5
	clip.loop_mode = Animation.LOOP_LINEAR
	var path := str(get_path_to(_skeleton))
	for bone_name in _base_rotations:
		var track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track, NodePath(path + ":" + bone_name))
		for frame in range(65):
			var fraction := float(frame) / 64.0
			var phase := fraction * TAU
			var stride := sin(phase)
			var angle := 0.0
			var axis: Vector3 = _pitch_axes[bone_name]
			match bone_name:
				"spine_02": angle = 0.009 * sin(phase * 2.0) if walking else 0.012 * stride
				"head":
					axis = _yaw_axes[bone_name]
					angle = 0.012 * stride if walking else 0.025 * stride
				"thigh_l": angle = -(0.22 if female else 0.32) * stride if walking else 0.0
				"thigh_r": angle = (0.22 if female else 0.32) * stride if walking else 0.0
				"calf_l": angle = 0.35 * maxf(0.0, stride) if walking else 0.0
				"calf_r": angle = 0.35 * maxf(0.0, -stride) if walking else 0.0
				"upperarm_l": angle = (0.10 if female else 0.16) * stride if walking else 0.012 * stride
				"upperarm_r": angle = -(0.10 if female else 0.16) * stride if walking else -0.012 * stride
				"lowerarm_l", "lowerarm_r": angle = 0.08 + (0.02 * absf(stride) if walking else 0.0)
				"foot_l": angle = ((0.22 if female else 0.32) * stride - 0.35 * maxf(0.0, stride)) if walking else 0.0
				"foot_r": angle = (-(0.22 if female else 0.32) * stride - 0.35 * maxf(0.0, -stride)) if walking else 0.0
			if turning:
				# Two small alternating lifts let each foot reposition during the
				# root pivot. Keep the ankle level through hip/knee compensation.
				var left_lift := maxf(0.0, stride)
				var right_lift := maxf(0.0, -stride)
				match bone_name:
					"thigh_l": angle = -0.23 * left_lift
					"thigh_r": angle = -0.23 * right_lift
					"calf_l": angle = 0.46 * left_lift
					"calf_r": angle = 0.46 * right_lift
					"foot_l": angle = -0.23 * left_lift
					"foot_r": angle = -0.23 * right_lift
			var base: Quaternion = _base_rotations[bone_name]
			clip.rotation_track_insert_key(track, fraction * clip.length, base * Quaternion(axis, angle))
	return clip
