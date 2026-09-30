extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool,label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func run() -> void:
	var world = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 12: await physics_frame
	var player = world.get_node("Player")
	player.set_physics_process(false)
	player.global_position = Vector3(0,30,0)
	var clock = world.get_node("GameTimeSystem")
	clock.clock_paused = true
	var homes = get_nodes_in_group("bhairavpur_home")
	check(homes.size()==33,"33 homes loaded")
	var locked_count := 0
	var clear_count := 0
	for home in homes:
		var door = home.get_node("EntranceDoor")
		if door.night_lock and not door.always_open: locked_count += 1
		if home.get_meta("window_access")=="open": clear_count += 1
		door._time_changed(1,21,0)
	await create_timer(1.0).timeout
	check(locked_count==25,"25 homes latch at night")
	check(clear_count==4,"four intentional window entry houses")
	var home = homes[1]
	var door = home.get_node("EntranceDoor")
	check(door.locked and not door.opened,"private house closed at night")
	var a: Vector3 = home.to_global(Vector3(0,1.4,home.get_node("EntranceDoor").position.z+1))
	var z: Vector3 = home.to_global(Vector3(0,1.4,home.get_node("EntranceDoor").position.z-1))
	var hit = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,z))
	check(not hit.is_empty() and hit.collider==door,"closed door physically blocks entrance")
	player.global_position = a
	door.interact(player)
	check(not door.opened,"outside cannot release night latch")
	player.global_position = z
	door.interact(player)
	await create_timer(1.0).timeout
	check(door.opened,"inside can release latch and exit")
	player.global_position = Vector3(0,30,0)
	for h in homes: h.get_node("EntranceDoor")._time_changed(2,6,0)
	await create_timer(1.0).timeout
	check(not door.locked and door.opened,"dawn restores access")
	check(get_nodes_in_group("occupied_command_fort").size()==1,"occupied fort estate loaded")
	var fort = get_nodes_in_group("occupied_command_fort")[0]
	check(fort.has_node("FortKitchen") and fort.has_node("FortStores") and fort.has_node("ServantQuarters"),"fort service interiors exist")
	check(fort.has_node("FortCook") and fort.has_node("FortSteward"),"two independent staff candidates loaded")
	if DisplayServer.get_name() != "headless":
		root.size=Vector2i(1280,720)
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.global_position=fort.to_global(Vector3(125,100,145))
		camera.look_at(fort.to_global(Vector3(0,0,-20)))
		camera.current=true
		for i in 20: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/world/captures/occupied_fort_candidate.png")
		camera.global_position=home.to_global(Vector3(9,5,11))
		camera.look_at(home.to_global(Vector3(0,1.5,0)))
		for i in 12: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/world/captures/house_access_candidate.png")
		camera.global_position=fort.to_global(Vector3(-41,2.8,-67))
		camera.look_at(fort.to_global(Vector3(-45,1.2,-76)))
		for i in 12: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/world/captures/fort_kitchen_candidate.png")
	var report := {"failures":failures,"night_latched_homes":locked_count,"entry_window_homes":clear_count,"visual_approval":"open"}
	var file := FileAccess.open("res://docs/world/house_access_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	quit(0 if failures.is_empty() else 1)
