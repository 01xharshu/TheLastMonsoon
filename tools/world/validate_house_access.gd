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
	var moving_visual_count := 0
	for home in homes:
		var door = home.get_node("EntranceDoor")
		if door.get_node("LeftLeaf").find_children("*","MeshInstance3D",true,false).size() > 0 and door.get_node("RightLeaf").find_children("*","MeshInstance3D",true,false).size() > 0: moving_visual_count += 1
		if door.night_lock and not door.always_open: locked_count += 1
		if home.get_meta("window_access")=="open": clear_count += 1
		door._time_changed(1,21,0)
	await create_timer(3.0).timeout
	check(moving_visual_count==33,"all 33 entrance doors retain moving meshes")
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
	await create_timer(3.0).timeout
	print("INSIDE LATCH ",player.get_meta("door_latch_failure","none")," at ",player.global_position)
	check(door.opened,"inside can release latch and exit")
	player.global_position = Vector3(0,30,0)
	for h in homes: h.get_node("EntranceDoor")._time_changed(2,6,0)
	await create_timer(3.0).timeout
	check(not door.locked and door.opened,"dawn restores access")
	check(get_nodes_in_group("occupied_command_fort").size()==1,"occupied fort estate loaded")
	var fort = get_nodes_in_group("occupied_command_fort")[0]
	check(fort.has_node("FortKitchen") and fort.has_node("FortStores") and fort.has_node("ServantQuarters"),"fort service interiors exist")
	check(fort.has_node("FortCook") and fort.has_node("FortSteward"),"two independent staff candidates loaded")
	var private_gates := 0
	for rich_home in get_nodes_in_group("wealthy_household"):
		if rich_home.has_node("EntranceDoor"):
			var entrance = rich_home.get_node("EntranceDoor")
			entrance._time_changed(1,21,0)
			private_gates += 1
	var estate_gate = world.get_node("Settlement/BhairavpurLandownerEstate/EstateGateFrame/EntranceGate")
	estate_gate._time_changed(1,21,0)
	await create_timer(3.0).timeout
	check(private_gates==2 and estate_gate.locked and not estate_gate.opened,"wealthy homes and landowner gate latch at night")
	var shutter = homes[1].get_node("TimberWindowFrameEast/PairedWoodShutters")
	check(shutter.get_node("LeftLeaf").find_children("*","MeshInstance3D",true,false).size() > 0,"moving shutter visuals survive village batching")
	var leaf = shutter.get_node("LeftLeaf")
	shutter.restore_state(false)
	var closed_basis: Basis = leaf.global_basis
	shutter.restore_state(true)
	check(not leaf.global_basis.is_equal_approx(closed_basis),"visible shutter leaf rotates with physical state")
	shutter.restore_state(false)
	player.global_position=shutter.get_parent().to_global(Vector3(0,.4,1.8))
	await physics_frame
	await physics_frame
	shutter.interact(player)
	check(not shutter.opened,"outside cannot unlatch wooden window")
	player.global_position=shutter.get_parent().to_global(Vector3(0,.4,-1.8))
	await physics_frame
	await physics_frame
	shutter.interact(player)
	await create_timer(3.0).timeout
	print("SHUTTER LATCH ",player.get_meta("door_latch_failure","none")," at ",player.global_position," hand gap ",player.get_meta("door_latch_hand_gap",-1))
	check(shutter.opened and is_equal_approx(shutter.swing,1.0) and is_equal_approx(absf(leaf.rotation.y),PI*.5),"inside can animate wooden shutters open")
	player.global_position=Vector3(0,30,0)
	await physics_frame
	await physics_frame
	var fort_gate = fort.get_node("FortEntranceGate")
	fort_gate._time_changed(1,21,0)
	await create_timer(2.6).timeout
	check(fort_gate.locked and not fort_gate.opened and is_zero_approx(fort_gate.swing),"paired fort entrance closes at night")

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
		for layer in world.find_children("*","CanvasLayer",true,false): layer.hide()
		root.content_scale_size=Vector2i(1280,720)
		root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
		home.get_node("EntranceDoor").restore_state(false)
		shutter.night_lock=false
		shutter.restore_state(false)
		camera.fov=55
		camera.global_position=home.to_global(Vector3(7,2.8,9))
		camera.look_at(home.to_global(Vector3(0,1.4,4)))
		for i in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/world/captures/house_door_realism.png")
		var frame = shutter.get_parent()
		camera.global_position=frame.to_global(Vector3(.6,1.1,1.8))
		camera.look_at(frame.to_global(Vector3(0,.55,0)))
		for i in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/world/captures/wood_shutter_closed.png")
		shutter.restore_state(true)
		for i in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/world/captures/wood_shutter_open.png")
	var report := {"failures":failures,"night_latched_homes":locked_count,"entry_window_homes":clear_count,"visual_approval":"open"}
	var file := FileAccess.open("res://docs/world/house_access_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
