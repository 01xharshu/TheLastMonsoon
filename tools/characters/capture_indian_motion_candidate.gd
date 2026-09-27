extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func _load_candidate(slug: String) -> Node3D:
	var path := ProjectSettings.globalize_path("res://WorkingAssets/NPCs/%s/%s_rigged_candidate.glb" % [slug, slug])
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var err := document.append_from_file(path, state)
	assert(err == OK, "Cannot load rigged GLB: %s" % path)
	return document.generate_scene(state)

func capture() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var run_args := OS.get_cmdline_user_args()
	var recording := "--record" in run_args
	var world: Node3D = Node3D.new() if recording else load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	if recording:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-45, -25, 0)
		world.add_child(light)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color(0.2, 0.22, 0.25)
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color.WHITE
		environment.environment.ambient_light_energy = 0.6
		world.add_child(environment)
		var ground := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(12, 12)
		ground.mesh = plane
		world.add_child(ground)
	else:
		world.get_node("IndianPeasantPairCandidate").hide()
		world.get_node("Player").hide()
		world.get_node("Player/UI").hide()
		world.get_node("LandscapeUI").hide()
	var center := Vector3.ZERO if recording else Vector3(-310, 7.2, 230)
	if "--tree" in run_args:
		# Freeze unrelated gameplay while candidate trees continue to evaluate.
		for frame in 3:
			await physics_frame
		world.process_mode = Node.PROCESS_MODE_DISABLED
	var walkers: Array[AnimationPlayer] = []
	var tree_actors: Array[Node3D] = []
	var capture_name := "pair"
	if "--male-only" in run_args: capture_name = "male"
	if "--female-only" in run_args: capture_name = "female"
	for datum in [["village_farmer", -1.25], ["village_woman", 1.25]]:
		var slug: String = datum[0]
		if "--male-only" in run_args and slug != "village_farmer": continue
		if "--female-only" in run_args and slug != "village_woman": continue
		if "--tree" in run_args:
			var actor := Node3D.new()
			actor.set_script(load("res://characters/npcs/indian/indian_npc_candidate.gd"))
			actor.set("candidate_slug", slug)
			actor.process_mode = Node.PROCESS_MODE_ALWAYS
			world.add_child(actor)
			actor.global_position = center + Vector3(float(datum[1]), 0, 0)
			actor.set("walking", true)
			tree_actors.append(actor)
			continue
		var figure: Node3D = _load_candidate(slug)
		world.add_child(figure)
		figure.global_position = center + Vector3(float(datum[1]), 0, 0)
		var player: AnimationPlayer = figure.find_child("AnimationPlayer", true, false)
		assert(player != null, "No AnimationPlayer in %s" % slug)
		print("MOTION_CLIPS ", slug, " ", player.get_animation_list())
		player.play("walk")
		player.pause()
		walkers.append(player)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 42.0
	camera.global_position = center + Vector3(0, 1.92, 4.6)
	camera.look_at(center + Vector3(0, .82, 0))
	camera.make_current()
	if "--record" in run_args and "--tree" in run_args:
		var folder := "/tmp/tlm_indian_tree_frames"
		DirAccess.make_dir_recursive_absolute(folder)
		for actor in tree_actors: actor.set_process(false)
		for frame in 120:
			for actor in tree_actors:
				actor.set("walking", frame < 90 or actor != tree_actors[0])
				actor.call("step_motion", 1.0 / 30.0)
			await process_frame
			RenderingServer.force_draw(false)
			var err := root.get_texture().get_image().save_png(folder + "/%04d.png" % frame)
			if err != OK:
				quit(1)
				return
		print("INDIAN_TREE_RECORD 120 frames; fixed 30 Hz evaluation; first actor stops after 3s")
		quit()
		return
	var failed := false
	for phase in [0.0, 0.25, 0.5, 0.75]:
		if "--tree" in run_args:
			Engine.time_scale = 1.0
			await create_timer(0.6, true, false, true).timeout
			if phase == 0.75:
				tree_actors[0].set("walking", false)
				await create_timer(0.25, true, false, true).timeout
		for walker in walkers:
			var duration := walker.get_animation("walk").length
			walker.seek(duration * phase, true)
		for i in 3:
			await process_frame
		RenderingServer.force_draw(false)
		var prefix := "tree" if "--tree" in run_args else "walk"
		var path := "res://docs/characters/npcs/indian_peasant_%s_%s_%02d.png" % [capture_name, prefix, roundi(phase * 100.0)]
		var err := root.get_texture().get_image().save_png(path)
		print("INDIAN_NPC_MOTION_CAPTURE ", err, " ", path)
		failed = failed or err != OK
	quit(1 if failed else 0)
