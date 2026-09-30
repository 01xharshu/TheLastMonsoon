extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var roster := Node3D.new()
	roster.set_script(load("res://world/suryagarh/british_npc_roster.gd"))
	root.add_child(roster)
	await process_frame
	var errors: Array[String] = []
	var results: Array = []
	for actor in roster.get_children():
		actor.set_process(false)
		var axis: Vector3 = actor.get("patrol_axis")
		var distance: float = actor.get("patrol_distance")
		var origin: Vector3 = actor.get("_home")
		actor.position = origin + axis.normalized()*distance
		actor.rotation.y = atan2(axis.x,axis.z)
		actor.set("_clock",4.0)
		var anchor: Vector3 = actor.position
		var start_yaw: float = actor.rotation.y
		var drift := 0.0
		var turn_motion := 0.0
		var skeleton := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var foot_l := skeleton.find_bone("foot_l")
		var foot_r := skeleton.find_bone("foot_r")
		actor.call("_set_animation", &"idle", 0.2)
		var neutral_l := skeleton.get_bone_global_pose(foot_l).origin.y
		var neutral_r := skeleton.get_bone_global_pose(foot_r).origin.y
		var lift_l := 0.0
		var lift_r := 0.0
		var max_turn_blend := 0.0
		for frame in 50:
			actor.call("_process",0.01)
			drift = maxf(drift,actor.position.distance_to(anchor))
			turn_motion = maxf(turn_motion,float(actor.get("travel_speed")))
			lift_l = maxf(lift_l, skeleton.get_bone_global_pose(foot_l).origin.y - neutral_l)
			lift_r = maxf(lift_r, skeleton.get_bone_global_pose(foot_r).origin.y - neutral_r)
			max_turn_blend = maxf(max_turn_blend, float(actor.get("turn_blend")))
		var end_yaw: float = actor.rotation.y
		actor.call("_process",0.1)
		var return_distance: float = actor.position.distance_to(anchor)
		var heading: float = actor.basis.z.normalized().dot(-axis.normalized())
		actor.set("_clock",9.5)
		actor.position = origin
		actor.rotation.y = atan2(-axis.x,-axis.z)
		var home: Vector3 = actor.position
		for frame in 50:
			actor.call("_process",0.01)
		var home_drift: float = actor.position.distance_to(home)
		actor.call("_process",0.1)
		var outbound_step: float = actor.position.distance_to(home)
		var outbound_heading: float = actor.basis.z.normalized().dot(axis.normalized())
		if drift > 0.001 or turn_motion > 0.001 or absf(angle_difference(start_yaw,end_yaw)) < PI-0.02 or absf(return_distance-distance*0.05)>0.001 or heading < 0.999 or home_drift > 0.001 or absf(outbound_step-distance*0.05)>0.001 or outbound_heading<0.999:
			errors.append(str(actor.name)+": reversal turn/return failed")
		if lift_l < 0.005 or lift_r < 0.005 or max_turn_blend < 0.99:
			errors.append(str(actor.name)+": turn tree failed to lift both feet")
		results.append({"actor":str(actor.name),"stationary_turn_drift_m":drift,"return_step_m":return_distance,"return_heading_dot":heading,"home_turn_drift_m":home_drift,"outbound_heading_dot":outbound_heading,"left_turn_lift_m":lift_l,"right_turn_lift_m":lift_r,"maximum_turn_blend":max_turn_blend})
	var report := {"passed":errors.is_empty() and results.size()==16,"actors":results,"errors":errors,"scope":"0.5s turns, tree-driven alternating ankle lifts, stationary anchors and first movement steps; mesh sole and normal-speed contact remain visual review"}
	FileAccess.open("res://docs/characters/british/candidates/turn_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("BRITISH_TURN ",JSON.stringify(report))
	quit(0 if report.passed else 1)
