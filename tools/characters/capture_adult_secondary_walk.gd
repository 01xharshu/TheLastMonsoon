extends SceneTree
## Disposable native review of the gated adult river candidate while walking.
## This checks breast-bone response; it does not claim buttock secondary motion.

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var output := OS.get_environment("TLM_SECONDARY_WALK_OUTPUT")
	var foundation_only := OS.get_environment("TLM_SECONDARY_FOUNDATION_ONLY") == "1"
	if output.is_empty():
		push_error("Temporary TLM_SECONDARY_WALK_OUTPUT is required")
		quit(1)
		return
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.23, .26, .29)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .8
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -25, 0)
	world.add_child(light)
	var actor = load("res://characters/npcs/indian/river_woman_study.gd").new()
	actor.home = Vector3.ZERO
	actor.bank = Vector3(0, 0, -10)
	world.add_child(actor)
	actor.set_process(false)
	actor.set_physics_process(false)
	await process_frame
	if not actor.get_meta("adult_character", false) or actor.secondary_motion.entries.size() != 2:
		push_error("Expected adult candidate with two authored breast bones")
		quit(1)
		return
	actor.travel_override = true
	actor.travel_speed = 1.15
	actor.travel_direction = Vector3.FORWARD
	actor.travel_position = Vector3.ZERO
	actor.travel_gait_time = 0.0
	actor.sample(1.0)
	if is_instance_valid(actor.pot):
		actor.pot.hide()
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 35.0
	var frames := 0
	var captured := 0
	var walking_seconds := 0.0
	var previous := Time.get_ticks_usec()
	while walking_seconds < 3.0:
		await process_frame
		var now := Time.get_ticks_usec()
		var delta := minf(float(now - previous) / 1000000.0, .05)
		previous = now
		walking_seconds += delta
		actor.travel_position += Vector3.FORWARD * actor.travel_speed * delta
		actor.travel_gait_time += delta
		actor.tick_routine(delta)
		# The river routine re-enables its carried pot each tick. Hide it only
		# for this diagnostic so it cannot obscure the moving upper garment.
		if is_instance_valid(actor.pot):
			actor.pot.hide()
		if foundation_only:
			for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
				if str(mesh.name) in ["Fitted cotton upper base", "Wrapped sari lower drape", "Sari lower border", "Woven sari pallu over blouse", "LaundryStudyCloth"]:
					mesh.hide()
		frames += 1
		if captured < 4 and walking_seconds >= .4 + .65 * captured:
			for side in ["front", "back"]:
				var sign_value := -1.0 if side == "front" else 1.0
				camera.global_position = actor.global_transform * Vector3(0, 1.0, sign_value * 3.2)
				camera.look_at(actor.global_position + Vector3.UP * .9)
				await process_frame
				RenderingServer.force_draw(false)
				root.get_texture().get_image().save_png(output + "/" + side + "_%02d.png" % captured)
			captured += 1
			# Capture time is diagnostic overhead, not a gameplay acceleration.
			previous = Time.get_ticks_usec()
	var peak: float = actor.secondary_motion.peak_displacement_m
	var passed: bool = frames > 30 and captured == 4 and peak > .0001 and peak <= actor.secondary_motion.limit_m() + .00001
	print("ADULT_SECONDARY_WALK ", JSON.stringify({"passed": passed, "frames": frames,
		"seconds": walking_seconds, "views": captured, "peak_m": peak,
		"limit_m": actor.secondary_motion.limit_m(), "profile": actor.get_meta("adult_body_profile"),
		"foundation_only": foundation_only, "scope": "gated adult river candidate; breast bones only"}))
	if not passed:
		push_error("Walking secondary response or front/back captures failed")
	actor.queue_free()
	await process_frame
	quit(0 if passed else 1)
