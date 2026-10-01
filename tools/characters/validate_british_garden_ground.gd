extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var world := load("res://world/suryagarh/suryagarh_world.tscn").instantiate() as Node3D
	root.add_child(world)
	for frame in 5:
		await process_frame
	for node in world.find_children("*", "", true, false):
		node.set_process(false)
		node.set_physics_process(false)
	var roster := world.get_node("BritishNpcRosterCandidate")
	var excluded: Array[RID] = [world.get_node("Player").get_rid()]
	for actor in roster.get_children():
		excluded.append(actor.get_node("BodyCollider").get_rid())
	await physics_frame
	var errors: Array[String] = []
	var results: Array = []
	for actor in roster.get_children():
		if actor.get("movement_profile") != &"female" or actor.name == "OfficialWoman":
			continue
		var home: Vector3 = actor.get("_home")
		var axis: Vector3 = actor.get("patrol_axis")
		var distance: float = actor.get("patrol_distance")
		var worst := 0.0
		var hits := 0
		for step in 5:
			for width in [-0.6, 0.0, 0.6]:
				var point: Vector3 = home + axis * distance * float(step) / 4.0 + Vector3.RIGHT * float(width)
				var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.5, point - Vector3.UP * 0.5, 1)
				query.exclude = excluded
				var floor := world.get_world_3d().direct_space_state.intersect_ray(query)
				# Repeated builder labels receive generated node names on the east
				# walk; identify its actual footprint and surveyed floor, not its name.
				if floor.is_empty() or not str(floor.collider.get_path()).begins_with("/root/Suryagarh/Settlement/GovernmentHouse/") or absf(floor.collider.global_position.x - home.x) > 0.01:
					errors.append(str(actor.name) + ": footprint outside paved walk at " + str(point))
					continue
				hits += 1
				worst = maxf(worst, absf(floor.position.y - home.y))
		if worst > 0.002:
			errors.append(str(actor.name) + ": support gap " + str(worst))
		results.append({"actor": str(actor.name), "route_origin": str(home), "axis": str(axis), "footprint_samples": hits, "maximum_support_gap_m": worst})
	var report := {"passed": errors.is_empty() and results.size() == 7, "actors": results, "errors": errors, "scope": "seven garden patrol footprints, 15 floor rays each; rendered sole/cloth contact requires separate review"}
	FileAccess.open("res://docs/characters/british/candidates/garden_ground_validation.json", FileAccess.WRITE).store_string(JSON.stringify(report,"  ") + "\n")
	print("BRITISH_GARDEN_GROUND ", JSON.stringify(report))
	quit(0 if report.passed else 1)
