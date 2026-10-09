extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene := load("res://characters/npcs/indian/river_routine_review.tscn").instantiate() as Node3D
	root.add_child(scene)
	current_scene = scene
	var issues: Array[String] = []
	var samples: Array[Dictionary] = []
	var stages := ["depart", "arrive", "lower_pot", "fill", "lift_pot", "wash", "sit_down", "talk", "stand_up", "pickup_pot", "return", "deliver", "home"]
	var times := [5.0, 11.0, 13.5, 17.0, 21.5, 29.0, 36.5, 43.0, 49.5, 52.5, 60.0, 66.5, 69.5]
	for woman in scene.women: woman.set_process(false)
	for index in times.size():
		for woman in scene.women:
			woman.sample(times[index])
			if woman.action != stages[index]: issues.append("Unexpected action at " + str(times[index]))
			if woman.skeleton == null: issues.append("Missing MPFB skeleton")
			if woman.water_full != (index >= 4): issues.append("Water ownership mismatch")
			if woman.cloth.visible != (index == 5): issues.append("Laundry visibility mismatch")
			if index == 12 and (not woman.delivered or woman.global_position.distance_to(woman.home) > .001): issues.append("Missing home delivery")
		samples.append({"action": stages[index], "seconds": times[index], "hands": scene.women[0].hand_errors.duplicate(), "feet": scene.women[0].foot_errors.duplicate(), "mouth_y": scene.women[0].mouth_height})
	# Sampling must not accumulate additive spine/arm transforms across actions.
	var first = scene.women[0]
	first.sample(5.0)
	var spine: int = first.skeleton.find_bone("spine_01")
	var initial: Quaternion = first.skeleton.get_bone_pose_rotation(spine)
	first.sample(29.0)
	first.sample(5.0)
	if initial.angle_to(first.skeleton.get_bone_pose_rotation(spine)) > .001:
		issues.append("Action transforms accumulate across samples")
	# Normal-speed incremental traversal, independently moving all members.
	for woman in scene.women: woman.sample(0.0)
	var maxima: Dictionary = {}
	for frame in 2250:
		for woman in scene.women:
			woman.tick_routine(1.0 / 30.0)
			if not maxima.has(woman.action): maxima[woman.action] = {"hand_m": 0.0, "ankle_m": 0.0, "peak_hand_time": 0.0}
			for error in woman.hand_errors.values():
				if error > maxima[woman.action]["hand_m"]:
					maxima[woman.action]["hand_m"] = error
					maxima[woman.action]["peak_hand_time"] = woman.elapsed
			for error in woman.foot_errors.values(): maxima[woman.action]["ankle_m"] = maxf(maxima[woman.action]["ankle_m"], error)
	for stage in maxima:
		if maxima[stage]["hand_m"] > .015: issues.append(stage+" hand target exceeds 15mm: "+str(maxima[stage]["hand_m"]))
		if maxima[stage]["ankle_m"] > .015: issues.append(stage+" ankle target exceeds 15mm: "+str(maxima[stage]["ankle_m"]))
	for woman in scene.women:
		if not woman.delivered: issues.append("Continuous sequence never delivered")
	if scene.women[0].animation_tree == scene.women[1].animation_tree: issues.append("Shared animation owner")
	# During stance, the foot sweeps backward by exactly the travelled distance.
	# This catches a fast foot cycle even when every ankle reaches its IK target.
	first.travel_override=true;first.travel_speed=1.15;first.travel_direction=Vector3.FORWARD
	var planted_drift := 0.0
	for side in ["l","r"]:
		var start_phase := .1+(.5 if side=="r" else 0.0)
		first.travel_position=Vector3.ZERO
		first.travel_gait_time=start_phase*first.WALK_STRIDE/.6/.4
		first.sample(1.0)
		var planted: Vector3=first.skeleton.to_global(first.Contact.point(first.skeleton,"foot_"+side))
		for frame in 12:
			var phase_delta := float(frame+1)/12.0*.2
			first.travel_position=Vector3(0,0,-phase_delta*first.WALK_STRIDE/.6)
			first.travel_gait_time=(start_phase+phase_delta)*first.WALK_STRIDE/.6/.4
			first.sample(1.0)
			planted_drift=maxf(planted_drift,planted.distance_to(first.skeleton.to_global(first.Contact.point(first.skeleton,"foot_"+side))))
	if planted_drift>.001:issues.append("Planted foot slides during walking: "+str(planted_drift))
	var cycle_seconds: float=first.WALK_STRIDE/.6/first.travel_speed
	if cycle_seconds<.75 or cycle_seconds>1.15:issues.append("Walking cadence outside ordinary pace")
	var report := {"passed": issues.is_empty(), "issues": issues, "members": scene.women.size(), "planted_drift_m": planted_drift, "walk_cycle_seconds": cycle_seconds, "samples": samples, "continuous_target_maxima": maxima, "visual_approved": false, "contact_approved": false, "in_world": false}
	print("RIVER_ROUTINE ", JSON.stringify(report))
	quit(0 if issues.is_empty() else 1)
