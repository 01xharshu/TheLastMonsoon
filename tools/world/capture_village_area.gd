extends SceneTree
## Fresh views of the village in the actual Suryagarh world and lighting.

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Village captures require a rendering backend")
		quit(1)
		return
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	var player: CharacterBody3D = world.get_node("Player")
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.hide()
	for layer in world.find_children("*", "CanvasLayer", true, false):
		layer.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var clock: Node = world.get_node("GameTimeSystem")
	clock.clock_paused = true
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 58.0
	camera.far = 1600.0
	camera.make_current()
	var views := [
		["village_overview", Vector3(-455, 58, 350), Vector3(-331, 8, 235)],
		["village_well", Vector3(-280, 11.5, 239), Vector3(-289, 8.4, 231)],
		["village_market", Vector3(-322, 13, 275), Vector3(-296, 8.8, 280)],
		["village_west_lane", Vector3(-374, 10, 216), Vector3(-374, 9, 285)],
		["village_garden", Vector3(-430, 15, 264), Vector3(-407, 7.5, 270)],
	]
	for view in views:
		camera.global_position = view[1]
		camera.look_at(view[2])
		for i in 24:
			await process_frame
		await RenderingServer.frame_post_draw
		var path: String = "res://docs/world/captures/" + str(view[0]) + ".png"
		var error := root.get_texture().get_image().save_png(path)
		if error != OK:
			push_error("Village capture failed: " + path)
			quit(1)
			return
		print("VILLAGE CAPTURE ", path)
	world.queue_free()
	await process_frame
	quit()
