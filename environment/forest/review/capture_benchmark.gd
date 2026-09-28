extends SceneTree
## Run with the Metal renderer (without --headless) for repeatable visual review.
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	DisplayServer.window_set_size(Vector2i(640, 360))
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
	for view in views:
		root.size = Vector2i(640, 360)
		DisplayServer.window_set_size(Vector2i(640, 360))
		camera.position = view[1]
		camera.look_at(view[2])
		camera.make_current()
		for i in 30: await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
		image.save_png("res://environment/forest/review/" + view[0] + ".png")
		print("FOREST_CAPTURE ", view[0])
	quit()
