extends SceneTree
## Run with the Metal renderer (without --headless) for repeatable visual review.
func _initialize() -> void:
	if OS.get_environment("FOREST_REVIEW_DIR").is_empty():
		push_error("Set FOREST_REVIEW_DIR to an OS temporary directory")
		quit(1)
		return
	call_deferred("capture")

func capture() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var benchmark: Node3D = load("res://environment/forest/scenes/forest_benchmark.tscn").instantiate()
	root.add_child(benchmark)
	current_scene = benchmark
	benchmark.get_node("GameTimeSystem").clock_paused = true
	var player: CharacterBody3D = benchmark.get_node("Player")
	player.visible = false
	player.set_physics_process(false)
	player.get_node("UI").visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var camera := Camera3D.new()
	camera.fov = 68.0
	benchmark.add_child(camera)
	var views := [
		["side", Vector3(-8, 2.2, 17), Vector3(9, 2.0, -10)]
	]
	for chunk in benchmark.get_node("ForestGenerator/GeneratedChunks_Runtime").get_children():
		var batch := chunk.get_node_or_null("Hero_LOD0_Part0") as MultiMeshInstance3D
		if batch == null: continue
		var point: Vector3 = batch.global_transform * batch.multimesh.get_instance_transform(0).origin
		views.append(["bark_close", point + Vector3(2.0, 1.8, 2.0), point + Vector3(0.1, 1.6, 0)])
		break
	for view in views:
		if not OS.get_environment("FOREST_REVIEW_VIEW").is_empty() and view[0] != OS.get_environment("FOREST_REVIEW_VIEW"): continue
		root.size = Vector2i(1280, 720)
		DisplayServer.window_set_size(Vector2i(1280, 720))
		camera.position = view[1]
		camera.look_at(view[2])
		camera.make_current()
		for i in 30: await process_frame
		RenderingServer.force_draw()
		print("FOREST_RENDER_METRICS ", view[0], " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		var image := root.get_texture().get_image()
		image.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
		image.save_png(OS.get_environment("FOREST_REVIEW_DIR").path_join("") + view[0] + ".png")
		print("FOREST_CAPTURE ", view[0])
	quit()
