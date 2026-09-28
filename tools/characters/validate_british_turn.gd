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
		for frame in 50:
			actor.call("_process",0.01)
			drift = maxf(drift,actor.position.distance_to(anchor))
			turn_motion = maxf(turn_motion,float(actor.get("travel_speed")))
		var end_yaw: float = actor.rotation.y
		actor.call("_process",0.1)
		var return_distance: float = actor.position.distance_to(anchor)
		var heading: float = actor.basis.z.normalized().dot(-axis.normalized())
		if drift > 0.001 or turn_motion > 0.001 or absf(angle_difference(start_yaw,end_yaw)) < PI-0.02 or absf(return_distance-distance*0.05)>0.001 or heading < 0.999:
			errors.append(str(actor.name)+": reversal turn/return failed")
		results.append({"actor":str(actor.name),"stationary_turn_drift_m":drift,"return_step_m":return_distance,"return_heading_dot":heading})
	var report := {"passed":errors.is_empty() and results.size()==16,"actors":results,"errors":errors,"scope":"0.5s root turn, stationary anchor and first return step; foot/mesh turn contact remains visual review"}
	FileAccess.open("res://docs/characters/british/candidates/turn_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("BRITISH_TURN ",JSON.stringify(report))
	quit(0 if report.passed else 1)
