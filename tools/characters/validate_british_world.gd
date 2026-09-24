extends SceneTree

const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const OUTPUT := "res://docs/characters/british/candidates/roster_world_validation.json"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := load("res://world/suryagarh/suryagarh_world.tscn").instantiate() as Node3D
	root.add_child(world)
	await process_frame
	var roster := world.get_node_or_null("BritishNpcRosterCandidate") as Node3D
	var errors: Array[String] = []
	var placed := 0
	if roster == null:
		errors.append("BritishNpcRosterCandidate missing from world")
	else:
		for actor in roster.get_children():
			var rank: String = str(actor.get_meta("concept_rank_or_post", ""))
			var plot_name := "GovernmentHouse" if rank == "official" else "CompanyCompound"
			var plot: Dictionary = Layout.PLOTS[plot_name]
			var pos: Vector3 = (actor as Node3D).global_position
			var centre: Vector2 = plot.center
			var half: Vector2 = plot.half
			if absf(pos.x-centre.x) > half.x or absf(pos.z-centre.y) > half.y:
				errors.append(actor.name + " outside " + plot_name)
			if absf(pos.y-float(plot.grade)) > 0.2:
				errors.append(actor.name + " off surveyed grade")
			if actor.find_children("*", "Skeleton3D", true, false).size() != 1:
				errors.append(actor.name + " has no single imported skeleton")
			placed += 1
	var passed := errors.is_empty() and placed == 16
	var report := {"passed":passed,"placed":placed,"errors":errors,"company_compound":"seven military pairs","government_house":"civil official pair","scope":"world load and surveyed placement; visual contact requires rendered review"}
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	print("BRITISH_WORLD_VALIDATION ", JSON.stringify(report))
	quit(0 if passed else 1)
