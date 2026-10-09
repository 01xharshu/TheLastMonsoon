extends SceneTree
## Capture the integrated forest under the main world's existing lighting.
func _initialize() -> void:
	if OS.get_environment("FOREST_REVIEW_DIR").is_empty():
		push_error("Set FOREST_REVIEW_DIR to an OS temporary directory")
		quit(1)
		return
	call_deferred("capture")

func capture() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	for body in world.find_children("*", "CollisionObject3D", true, false):
		body.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	world.process_mode = Node.PROCESS_MODE_DISABLED # Fixed forest art fixture; other actors are frozen.
	root.add_child(world)
	current_scene = world
	for body in world.find_children("*", "CollisionObject3D", true, false):
		body.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	world.get_node("GameTimeSystem").clock_paused = true
	var player: Node3D = world.get_node("Player")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.visible = false
	player.get_node("UI").visible = false
	world.get_node("LandscapeUI").visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var camera := Camera3D.new()
	camera.fov = 68.0
	camera.far = 1800.0
	world.add_child(camera)
	var layout = load("res://world/suryagarh/landscape_layout.gd").new()
	var views := [
		["world_entry", Vector2(344, -105), Vector2(375, -102)],
		["world_inside", Vector2(374, -91), Vector2(395, -110)]
	]
	for view in views:
		var p: Vector2 = view[1]
		var target: Vector2 = view[2]
		camera.position = Vector3(p.x, layout.height(p.x, p.y) + 1.8, p.y)
		camera.look_at(Vector3(target.x, layout.height(target.x, target.y) + 1.8, target.y))
		camera.make_current()
		for i in 30: await process_frame
		RenderingServer.force_draw()
		print("FOREST_RENDER_METRICS ", view[0], " draw_calls=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " primitives=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		var captured := root.get_texture().get_image()
		captured.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
		captured.save_png(OS.get_environment("FOREST_REVIEW_DIR").path_join("") + view[0] + ".png")
		print("FOREST_WORLD_CAPTURE ", view[0])
	current_scene = null
	world.queue_free()
	for i in 3: await process_frame
	quit()
