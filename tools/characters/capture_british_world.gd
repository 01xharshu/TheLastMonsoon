extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("British NPC visual capture needs a display")
		quit(1)
		return
	var world := load("res://world/suryagarh/suryagarh_world.tscn").instantiate() as Node3D
	root.add_child(world)
	current_scene = world
	world.get_node("Player").hide()
	world.get_node("Player/UI").hide()
	world.get_node("LandscapeUI").hide()
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 45.0
	camera.make_current()
	var shots := [
		{"name":"compound_overview", "eye":Vector3(345, 24, 245), "aim":Vector3(345, 12.8, 280), "fov":65.0},
		{"name":"corporal_pair_world", "eye":Vector3(330, 14.1, 265), "aim":Vector3(330, 12.9, 273), "fov":35.0},
		{"name":"captain_pair_world", "eye":Vector3(375, 14.1, 267), "aim":Vector3(375, 12.9, 275), "fov":35.0},
		{"name":"official_pair_world", "eye":Vector3(-389, 10.6, -94), "aim":Vector3(-389, 9.3, -85), "fov":35.0},
	]
	for shot in shots:
		camera.fov = shot.fov
		camera.global_position = shot.eye
		camera.look_at(shot.aim)
		for i in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		var path: String = "res://docs/characters/british/candidates/" + str(shot.name) + ".png"
		var err := root.get_texture().get_image().save_png(path)
		print("BRITISH_WORLD_CAPTURE ", shot.name, " ", err, " ", path)
		if err != OK:
			quit(1)
			return
	quit(0)
