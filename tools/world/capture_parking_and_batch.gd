extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	create_timer(90).timeout.connect(func(): quit(2))
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	DisplayServer.window_set_size(root.size)
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for frame in 8: await physics_frame
	var actor: CharacterBody3D = world.get_node("Player")
	actor.set_physics_process(false)
	actor.get_node("UI").hide()
	world.get_node("LandscapeUI").hide()
	var clock: GameTimeSystem = world.get_node("GameTimeSystem")
	clock.clock_paused = true
	clock.advance_hours(6)
	for coach in get_nodes_in_group("household_coach"): coach.get_node("HouseholdTravel").set_physics_process(false)
	var camera := Camera3D.new()
	camera.fov = 55
	world.add_child(camera)
	camera.make_current()
	var bay: Node3D = world.get_node("LiveCarts/GovernmentHouseFamilyCarriageParking")
	actor.global_position = bay.global_position+Vector3(14,1,14)
	actor.hide()
	camera.global_position = bay.global_position+Vector3(10,6,12)
	camera.look_at(bay.global_position+Vector3(0,1,0))
	await capture("cart_standing_current")
	camera.global_position = Vector3(-329,13,256)
	camera.look_at(Vector3(-321,8.3,244))
	actor.global_position = camera.global_position
	await capture("village_batch_current")
	var map: Control = actor.get_node("UI/WorldMap")
	actor.get_node("UI").show()
	map.set_open(true)
	var location: Vector2 = map.sites[str(bay.get_meta("parking_label"))]
	map.map_center = location
	map.zoom = 4.0
	map.clamp_center()
	map.select_point(map.project(location))
	await capture("cart_parking_map_current")
	print("PARKING / BATCH NATIVE CAPTURES COMPLETE")
	world.queue_free()
	for frame in 3: await physics_frame
	quit()
func capture(label: String) -> void:
	for frame in 4: await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://docs/world/captures/"+label+".png")
	assert(error == OK)
