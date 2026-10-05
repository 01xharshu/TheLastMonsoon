extends SceneTree
## Flat-floor ankle diagnostic; mesh/cloth contact and production approval stay open.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var report := {"passed": true, "actors": {}, "scope": "baked flat-floor ankle heights and stance slip; no toe/mesh/cloth/terrain approval"}
	for role in ["dock_porter", "boatman", "record_clerk"]:
		var actor := Node3D.new()
		actor.set_script(load("res://characters/npcs/indian/indian_npc_candidate.gd"))
		actor.set("candidate_slug", role)
		root.add_child(actor)
		actor.set_process(false)
		var skeleton := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var feet := [skeleton.find_bone("foot_l"), skeleton.find_bone("foot_r")]
		var rest := []
		for bone in feet: rest.append((skeleton.global_transform * skeleton.get_bone_global_pose(bone)).origin.y)
		actor.set("walking", true)
		actor.call("step_motion", .2)
		var stride: float = {"dock_porter": .40, "boatman": .44, "record_clerk": .28}[role]
		var previous := [Vector3.ZERO, Vector3.ZERO]
		var contact := [false, false]
		var support_error := 0.0
		var slip := 0.0
		var clear := 0.0
		for frame in 108:
			actor.position.z += stride / .72 / 30.0
			actor.call("step_motion", 1.0 / 30.0)
			var lowest := INF
			for side in 2:
				var point := (skeleton.global_transform * skeleton.get_bone_global_pose(feet[side])).origin
				var height: float = point.y - rest[side]
				lowest = minf(lowest, absf(height))
				clear = maxf(clear, height)
				var planted := absf(height) < .001
				if frame > 0 and planted and contact[side]:
					var delta := Vector2(point.x, point.z).distance_to(Vector2(previous[side].x, previous[side].z))
					slip = maxf(slip, delta)
				previous[side] = point
				contact[side] = planted
			support_error = maxf(support_error, lowest)
		var passed := support_error < .015 and slip < .005 and clear > .020
		report.actors[role] = {"passed": passed, "support_ankle_delta_m": support_error, "max_planted_step_slip_m": slip, "swing_ankle_lift_m": clear, "travel_speed_m_s": stride / .72}
		report.passed = report.passed and passed
		actor.queue_free()
	FileAccess.open("res://docs/characters/npcs/purpose_gait_validation.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  ") + "\n")
	print("PURPOSE_GAIT ", JSON.stringify(report))
	quit(0 if report.passed else 1)
