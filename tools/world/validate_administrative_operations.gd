extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var world = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for frame in 12: await physics_frame
	var player = world.get_node("Player")
	player.set_physics_process(false)
	var inv = player.get_node("InventoryComponent")
	var clock = world.find_child("GameTimeSystem",true,false)
	clock.advance_minutes(10*60-fmod(clock.total_game_minutes,1440))
	assert(get_nodes_in_group("administrative_staff").size() == 4)
	var services = get_nodes_in_group("administrative_services")
	assert(services.size() == 3)
	for service in services:
		player.global_position = service.global_position+Vector3(0,.9,1.5)
		if service.role in ["court","revenue"]:
			var money_before: int = inv.get_item_count("rupees")
			if service.role == "revenue": inv.items["rupees"] = 0
			service.interact(player)
			assert(not service.completed,"Missing prerequisite accepted")
			inv.items["rupees"] = money_before
		service.staff.set_meta("dead",true)
		service.interact(player)
		assert(not service.completed,"Unavailable clerk accepted service")
		service.staff.set_meta("dead",false)
	inv.add_item("rupees",5)
	for role in ["petition","court","revenue"]:
		for service in services:
			if service.role != role: continue
			player.global_position = service.global_position+Vector3(0,.9,1.5)
			service.interact(player)
			assert(service.completed)
			var before: Dictionary = inv.items.duplicate(true)
			service.interact(player)
			assert(inv.items == before,"Repeated service duplicated transaction")
			var saved: Dictionary = service.export_state()
			service.completed = false
			service.restore_state(JSON.parse_string(JSON.stringify(saved)))
			assert(service.completed)
	assert(inv.get_item_count("petition_receipt") == 0)
	assert(inv.get_item_count("court_receipt") == 1)
	assert(inv.get_item_count("revenue_receipt") == 1)
	assert(inv.get_item_count("rupees") == 3)
	var saves = root.get_node("SaveManager")
	var original_root: String = saves.save_root
	saves.save_root = "user://administrative_validation"
	assert(saves.save_game(world,1))
	for service in services: service.completed = false
	inv.items.clear()
	saves.pending_slot = 1
	saves.apply_pending(world)
	for service in services: assert(service.completed,"Save/load lost service completion")
	assert(inv.get_item_count("rupees") == 3 and inv.get_item_count("revenue_receipt") == 1)
	saves.save_root = original_root
	var district = world.get_node("Settlement/AdministrativeDistrict")
	var secure = district.get_node("DistrictTreasury/StrongroomDoor")
	player.global_position = secure.global_position+Vector3(0,.9,2)
	secure.interact(player)
	assert(not secure.opened and not secure.moving)
	player.global_position = Vector3(520,12,170)
	for room in get_nodes_in_group("administrative_buildings"):
		var door = room.get_node("EntranceDoor")
		door.set_open(false)
		for frame in 80: await physics_frame
		assert(not door.opened and is_zero_approx(door.swing))
		var ray = PhysicsRayQueryParameters3D.create(door.global_position+Vector3(0,1,1),door.global_position+Vector3(0,1,-1))
		assert(not world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"Closed door lacks physical collision")
		player.global_position = door.global_position+Vector3(0,.95,1.2)
		player.velocity = Vector3.ZERO
		door.interact(player)
		for frame in 180: await physics_frame
		if not door.opened:
			print("LATCH FAILED ",room.name," ",player.get_meta("door_latch_failure","none")," gap ",player.get_meta("door_latch_hand_gap",-1))
			quit(1)
			return
		assert(is_equal_approx(door.swing,1))
		player.global_position = Vector3(520,12,170)
	clock.advance_minutes(12*60)
	for frame in 80: await physics_frame
	for room in get_nodes_in_group("administrative_buildings"):
		assert(room.get_node("EntranceDoor").locked)
	for service in services:
		service.completed = false
		player.global_position = service.global_position+Vector3(0,.9,1.5)
		service.interact(player)
		assert(not service.completed,"Closed office accepted transaction")
	print("ADMINISTRATIVE OPERATIONS: PASS — 4 staff, 3 transactions, repeat protection, actual save/load, closed hours, 3 colliding doors and secured strongroom")
	quit()
