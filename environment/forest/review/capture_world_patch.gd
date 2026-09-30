extends SceneTree
## Capture the integrated forest under the main world's existing lighting.
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	DisplayServer.window_set_size(Vector2i(640, 360))
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
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
		await RenderingServer.frame_post_draw
		var captured := root.get_texture().get_image()
		captured.resize(1280, 720, Image.INTERPOLATE_LANCZOS)
		captured.save_png("res://environment/forest/review/" + view[0] + ".png")
		print("FOREST_WORLD_CAPTURE ", view[0])
	quit()
