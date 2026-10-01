extends SceneTree
## Isolated 1.0x idle/walk/reversal study, not a live-world or seated approval.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var rank := "private"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--rank="):
			rank = argument.trim_prefix("--rank=")
	assert(rank in ["private", "corporal", "sergeant"])
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 900)
	var stage := Node3D.new()
	root.add_child(stage)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(10, 10)
	floor_mesh.mesh = plane
	stage.add_child(floor_mesh)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -35, 0)
	light.light_energy = 1.6
	stage.add_child(light)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.22, 0.25, 0.29)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.65
	environment.environment = settings
	stage.add_child(environment)
	var actor = load("res://characters/npcs/british/candidates/private_skirt_actor.gd").new()
	actor.movement_profile = &"female"
	actor.patrol_distance = 0.9
	actor.add_child(load("res://characters/npcs/british/candidates/%s_woman_skirt_candidate.glb" % rank).instantiate())
	if "--live-roster" in OS.get_cmdline_user_args():
		actor.free()
		var roster := Node3D.new()
		roster.set_script(load("res://world/suryagarh/british_npc_roster.gd"))
		stage.add_child(roster)
		actor = roster.get_node(rank.capitalize() + "Woman")
		actor.reparent(stage)
		actor.position = Vector3.ZERO
		actor._home = Vector3.ZERO
		actor._clock = 0.0
		roster.queue_free()
	else:
		stage.add_child(actor)
	actor.set_process(false)
	var pair_actor: Node3D
	if "--pair" in OS.get_cmdline_user_args():
		pair_actor = load("res://characters/npcs/british/british_npc_actor.gd").new()
		pair_actor.position = Vector3(1.5, 0, 0)
		pair_actor.set("patrol_distance", 0.9)
		var male_path := "res://characters/npcs/british/candidates/sergeant_man_uniform_candidate.glb" if "--uniform-candidate" in OS.get_cmdline_user_args() else "res://characters/npcs/british/%s_man.glb" % rank
		pair_actor.add_child(load(male_path).instantiate())
		stage.add_child(pair_actor)
		pair_actor.set_process(false)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.fov = 32.0
	camera.make_current()
	var maximum := Vector4.ZERO
	var errors: Array[String] = []
	for frame in 660:
		actor._process(1.0 / 60.0)
		if pair_actor != null:
			pair_actor.call("_process", 1.0 / 60.0)
		for index in 4:
			maximum[index] = maxf(maximum[index], actor.cloth_values[index])
		camera.position = actor.position + Vector3(2.6, 1.25, -3.8)
		if pair_actor != null:
			camera.position = actor.position + Vector3(3.0, 1.45, -5.8)
			camera.look_at(actor.position + Vector3(0.75, 0.88, 0))
		else:
			camera.look_at(actor.position + Vector3(0, 0.88, 0))
		if not "--fast-review" in OS.get_cmdline_user_args() or frame in [30, 190, 260, 610]:
			await process_frame
		if frame in [30, 190, 260, 610] and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/characters/british/candidates/%sskirt_motion_%d.png" % ["sergeant_uniform_" if "--uniform-candidate" in OS.get_cmdline_user_args() else "" if rank == "private" else rank + "_", frame])
	for index in 4:
		if maximum[index] < 0.1:
			errors.append("Morph %d never moved" % index)
	actor.movement_enabled = false
	for frame in 90:
		actor._process(1.0 / 60.0)
		await process_frame
	if actor.cloth_values.length() > 0.001:
		errors.append("Cloth did not settle when idle")
	var report := {"passed": errors.is_empty(), "errors": errors, "maximum_morph_values": [maximum.x, maximum.y, maximum.z, maximum.w], "settled_values_length": actor.cloth_values.length(), "frames_at_60_hz": 750, "sampled_render_review": "--fast-review" in OS.get_cmdline_user_args(), "rank": rank, "pair_rendered": pair_actor != null, "spawned_from_live_roster": "--live-roster" in OS.get_cmdline_user_args(), "scope": "isolated actual AnimationTree idle/walk/turn morph import and settling; body penetration, run, seated and live-world approval remain open"}
	FileAccess.open("res://docs/characters/british/candidates/%sskirt_motion_validation.json" % ("" if rank == "private" else rank + "_"), FileAccess.WRITE).store_string(JSON.stringify(report, "  ") + "\n")
	print("BRITISH_SKIRT_MOTION ", JSON.stringify(report))
	quit(0 if report.passed else 1)
