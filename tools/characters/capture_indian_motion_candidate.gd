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
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.get_node("IndianPeasantPairCandidate").hide()
	world.get_node("Player").hide()
	world.get_node("Player/UI").hide()
	world.get_node("LandscapeUI").hide()
	var center := Vector3(-310, 7.2, 230)
	var run_args := OS.get_cmdline_user_args()
	var walkers: Array[AnimationPlayer] = []
	var capture_name := "pair"
	if "--male-only" in run_args: capture_name = "male"
	if "--female-only" in run_args: capture_name = "female"
	for datum in [["village_farmer", -1.25], ["village_woman", 1.25]]:
		var slug: String = datum[0]
		if "--male-only" in run_args and slug != "village_farmer": continue
		if "--female-only" in run_args and slug != "village_woman": continue
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
	var failed := false
	for phase in [0.0, 0.25, 0.5, 0.75]:
		for walker in walkers:
			var duration := walker.get_animation("walk").length
			walker.seek(duration * phase, true)
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://docs/characters/npcs/indian_peasant_%s_walk_%02d.png" % [capture_name, roundi(phase * 100.0)]
		var err := root.get_texture().get_image().save_png(path)
		print("INDIAN_NPC_MOTION_CAPTURE ", err, " ", path)
		failed = failed or err != OK
	quit(1 if failed else 0)
