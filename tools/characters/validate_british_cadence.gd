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
		actor.set("_clock",0.0)
		actor.call("_process",0.0)
		actor.call("_process",0.25)
		var speed: float = actor.get("travel_speed")
		var rate: float = actor.get("walk_playback_rate")
		var nominal: float = actor.get("nominal_walk_speed")
		if absf(nominal*rate-speed) > 0.001:
			errors.append(str(actor.name)+": cadence does not match travel")
		var distance: float = actor.get("patrol_distance")
		actor.set("patrol_distance",distance*0.5)
		actor.set("_clock",0.0)
		actor.call("_process",0.0)
		actor.call("_process",0.25)
		var slow_rate: float = actor.get("walk_playback_rate")
		if absf(slow_rate-rate*0.5)>0.001:
			errors.append(str(actor.name)+": cadence does not respond to speed")
		actor.set("movement_enabled",false)
		actor.call("_process",0.2)
		if not is_zero_approx(float(actor.get("travel_speed"))) or not is_zero_approx(float(actor.get("locomotion_blend"))):
			errors.append(str(actor.name)+": stop leaves movement/blend")
		results.append({"actor":str(actor.name),"travel_m_s":speed,"nominal_m_s":nominal,"walk_rate":rate,"half_speed_rate":slow_rate})
	var report := {"passed":results.size()==16 and errors.is_empty(),"actors":results,"errors":errors,"scope":"actual movement and tree rate; ankle-excursion cadence estimate, not planted-foot or sole-contact approval"}
	FileAccess.open("res://docs/characters/british/candidates/cadence_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("BRITISH_CADENCE ",JSON.stringify(report))
	quit(0 if report.passed else 1)
