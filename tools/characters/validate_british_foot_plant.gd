extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var roster := Node3D.new()
	roster.set_script(load("res://world/suryagarh/british_npc_roster.gd"))
	root.add_child(roster)
	await process_frame
	var errors: Array[String] = []
	var records: Array = []
	for actor in roster.get_children():
		actor.set_process(false)
		actor.set("_clock",0.0)
		actor.call("_process",0.0)
		var worst := 0.0
		var locked := 0
		var limited := 0
		var swing_clearance := INF
		var drop_min := INF
		var drop_max := 0.0
		for frame in 610:
			actor.call("_process",1.0/60.0)
			var plant = actor.get("foot_plant")
			if plant.active:
				var index: int = plant.legs[plant.planted_side][2]
				var actual: Vector3 = plant.skeleton.to_global(plant.skeleton.get_bone_global_pose(index).origin)
				worst = maxf(worst,actual.distance_to(plant.planted_world))
				var other_side := "r" if plant.planted_side == "l" else "l"
				var other: int = plant.legs[other_side][2]
				var swing_y: float = plant.skeleton.to_global(plant.skeleton.get_bone_global_pose(other).origin).y
				swing_clearance = minf(swing_clearance, swing_y - float(plant.ankle_height[other_side]))
				drop_min = minf(drop_min, plant.hip_drop)
				drop_max = maxf(drop_max, plant.hip_drop)
				locked += 1
				if plant.reach_limited: limited += 1
		actor.set("movement_enabled",false)
		actor.call("_process",0.2)
		if locked<60 or worst>0.025 or swing_clearance < -0.005 or actor.get("foot_plant").active:
			errors.append(str(actor.name)+": contact target drift/release failed")
		records.append({"actor":str(actor.name),"locked_frames":locked,"worst_ankle_target_error_m":worst,"reach_limited_frames":limited,"min_swing_ankle_clearance_m":swing_clearance,"hip_drop_min_m":drop_min,"hip_drop_max_m":drop_max})
	var report := {"passed":errors.is_empty() and records.size()==16,"actors":records,"errors":errors,"scope":"flat surveyed-grade world ankle target hold and release; not mesh sole/cloth or uneven-ground approval"}
	FileAccess.open("res://docs/characters/british/candidates/foot_plant_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("BRITISH_FOOT_PLANT ",JSON.stringify(report))
	quit(0 if report.passed else 1)
