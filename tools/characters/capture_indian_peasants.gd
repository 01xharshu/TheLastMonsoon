extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Forward+/Metal visual capture requires a display")
		quit(1)
		return
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	var pair: Node3D = world.get_node("IndianPeasantPairCandidate")
	assert(pair.get_node("VillageFarmer") != null and pair.get_node("VillageWoman") != null)
	world.get_node("Player").hide()
	world.get_node("Player/UI").hide()
	world.get_node("LandscapeUI").hide()
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 42.0
	camera.global_position = pair.global_position + Vector3(0, 1.92, 4.6)
	camera.look_at(pair.global_position + Vector3(0, .82, 0))
	camera.make_current()
	for i in 35:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://docs/characters/npcs/indian_peasant_pair_world.png"
	var err := root.get_texture().get_image().save_png(path)
	print("INDIAN_NPC_WORLD_CAPTURE ", err, " ", path)
	quit(0 if err == OK else 1)
