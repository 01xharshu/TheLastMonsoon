extends SceneTree
## Close static costume review for all eight in-world British NPC pairs.

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("British pair review needs a display")
		quit(1)
		return
	var world := load("res://world/suryagarh/suryagarh_world.tscn").instantiate() as Node3D
	root.add_child(world)
	current_scene = world
	world.get_node("Player").hide()
	world.get_node("Player/UI").hide()
	world.get_node("LandscapeUI").hide()
	var roster := world.get_node("BritishNpcRosterCandidate")
	for actor in roster.get_children():
		actor.set("patrol_distance", 0.0)
		actor.set("_clock", 6.25)
		(actor as Node3D).rotation.y = 0.0
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 35.0
	camera.make_current()
	var pairs := [
		{"rank":"private", "x":315.0, "z":270.0, "y":12.8},
		{"rank":"corporal", "x":329.0, "z":273.0, "y":12.8},
		{"rank":"sergeant", "x":345.0, "z":274.0, "y":12.8},
		{"rank":"lieutenant", "x":360.0, "z":274.0, "y":12.8},
		{"rank":"captain", "x":374.0, "z":275.0, "y":12.8},
		{"rank":"major", "x":314.0, "z":298.0, "y":12.8},
		{"rank":"colonel", "x":321.0, "z":313.0, "y":12.8},
		{"rank":"official", "x":-390.0, "z":-85.0, "y":9.3},
	]
	for pair in pairs:
		var rank: String = pair.rank
		camera.global_position = Vector3(float(pair.x) + 1.35, float(pair.y) + 1.55, float(pair.z) - 6.0)
		camera.look_at(Vector3(float(pair.x) + 1.35, float(pair.y) + 0.9, float(pair.z)))
		for i in 10:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://docs/characters/british/candidates/" + rank + "_pair_world_review.png"
		var err := root.get_texture().get_image().save_png(path)
		print("BRITISH_PAIR_REVIEW ", rank, " ", err, " ", path)
		if err != OK:
			quit(1)
			return
	quit(0)
