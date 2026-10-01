extends SceneTree
## Isolated 1.0x idle/walk/reversal study, not a live-world or seated approval.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
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
	actor.add_child(load("res://characters/npcs/british/candidates/private_woman_skirt_candidate.glb").instantiate())
	stage.add_child(actor)
	actor.set_process(false)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.fov = 32.0
	camera.make_current()
	var maximum := Vector4.ZERO
	var errors: Array[String] = []
	for frame in 660:
		actor._process(1.0 / 60.0)
		for index in 4:
			maximum[index] = maxf(maximum[index], actor.cloth_values[index])
		camera.position = actor.position + Vector3(2.6, 1.25, -3.8)
		camera.look_at(actor.position + Vector3(0, 0.88, 0))
		await process_frame
		if frame in [30, 190, 260, 610] and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/characters/british/candidates/skirt_motion_%d.png" % frame)
	for index in 4:
		if maximum[index] < 0.1:
			errors.append("Morph %d never moved" % index)
	actor.movement_enabled = false
	for frame in 90:
		actor._process(1.0 / 60.0)
		await process_frame
	if actor.cloth_values.length() > 0.001:
		errors.append("Cloth did not settle when idle")
	var report := {"passed": errors.is_empty(), "errors": errors, "maximum_morph_values": [maximum.x, maximum.y, maximum.z, maximum.w], "settled_values_length": actor.cloth_values.length(), "frames_at_60_hz": 750, "scope": "isolated actual AnimationTree idle/walk/turn morph import and settling; body penetration, run, seated and live-world approval remain open"}
	FileAccess.open("res://docs/characters/british/candidates/skirt_motion_validation.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  ") + "\n")
	print("BRITISH_SKIRT_MOTION ", JSON.stringify(report))
	quit(0 if report.passed else 1)
