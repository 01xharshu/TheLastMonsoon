extends SceneTree

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var world: Node3D
	if "--full-world" in OS.get_cmdline_user_args():
		world = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
		current_scene = world
		root.add_child(world)
	else:
		world = preload("res://tools/world/institution_fixture_world.gd").new()
		world.name = "InstitutionFixture"
		root.add_child(world)
		current_scene = world
		var clock_node := preload("res://world/suryagarh/systems/game_time_system.gd").new()
		clock_node.name = "GameTimeSystem"
		clock_node.clock_paused = true
		world.add_child(clock_node)
		var player_node: Node3D = load("res://player/player.tscn").instantiate()
		player_node.name = "Player"
		world.add_child(player_node)
		player_node.set_physics_process(false)
		var builder := preload("res://tools/world/institution_fixture_builder.gd").new()
		builder.name = "Settlement"
		world.add_child(builder)
	for frame in 3: await physics_frame
	var operations = world.get_node("Settlement/BritishCantonment/Operations")
	var player = world.get_node("Player")
	player.set_physics_process(false)
	var inventory = player.get_node("InventoryComponent")
	var clock = world.get_node("GameTimeSystem")
	clock.clock_paused = true
	clock.total_game_minutes = 8*60
	clock._update_readable_time(true)
	operations.set_process(false)
	player.set_meta("mounted_vehicle",null)
	inventory.items["rupees"] = 10
	player.health = 20
	player.global_position = operations.district.get_node("MilitaryHospital/HospitalService").global_position
	assert(operations.request("hospital",player))
	assert(player.health == 20 and inventory.get_item_count("rupees") == 10,"Treatment transferred before completion")
	operations._process(6.1)
	assert(player.health == 70 and inventory.get_item_count("rupees") == 8)
	assert(not operations.request("hospital",player),"Daily treatment duplicated")
	assert(operations.request("issue",player))
	var before: int = inventory.get_item_count("roti")
	player.global_position += Vector3(3,0,0)
	operations._process(4)
	assert(inventory.get_item_count("roti") == before and operations.stock.ration == 12,"Cancelled service granted resources")
	assert(operations.request("issue",player))
	operations._process(4)
	assert(inventory.get_item_count("roti") == before+2 and operations.stock.ration == 11)
	assert(not operations.request("issue",player))
	assert(operations.request("fodder",player))
	operations._process(4)
	assert(inventory.get_item_count("stable_fodder") == 1)
	# Disable horse physics only in this focused transfer test; routes are a separate gate.
	operations.horse.set_physics_process(false)
	operations.horse.position = Vector3(-10,.24,-1.7)
	assert(operations.request("feed",player))
	operations._process(4)
	assert(inventory.get_item_count("stable_fodder") == 0 and operations.horse.get_meta("care_feed") == 1)
	inventory.stored_water_liters = 1
	assert(operations.request("water",player))
	operations._process(4)
	assert(is_equal_approx(inventory.stored_water_liters,.5))
	assert(operations.request("groom",player))
	operations._process(4)
	assert(operations.horse.get_meta("care_groom") == 1)
	assert(operations.request("bell",player))
	assert(not operations.request("bell",player))
	assert(operations.bell_sound.stream.get_length() > 2.9)
	assert(operations.request("worship",player))
	operations._process(4)
	assert(operations.ledger.has("worship/1"))
	var saved: Dictionary = operations.export_state()
	operations.ledger.clear()
	operations.stock.ration = 0
	operations.restore_state(JSON.parse_string(JSON.stringify(saved)))
	assert(operations.ledger.has("issue/1") and operations.stock.ration == 11)
	var manager = root.get_node("SaveManager")
	var original: String = manager.save_root
	manager.save_root = "user://institution_services_validation"
	assert(manager.save_game(world,1))
	operations.ledger.clear()
	manager.pending_slot = 1
	manager.apply_pending(world)
	assert(operations.ledger.has("issue/1"),"Disk save lost daily completion")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(manager.slot_path(1)))
	manager.save_root = original
	clock.advance_minutes(1440)
	assert(operations.stock.ration == 12 and operations.stock.dressings == 8)
	assert(operations.request("hospital",player))
	var orderly = operations.district.get_node("MilitaryHospital/HospitalService").staff
	orderly.set_meta("dead",true)
	operations._process(7)
	assert(operations.pending.is_empty() and inventory.get_item_count("rupees") == 8)
	orderly.set_meta("dead",false)
	operations.horse.vitality.dead = true
	assert(not operations.request("groom",player))
	operations.horse.vitality.dead = false
	clock.advance_minutes(12*60)
	assert(not operations.request("issue",player))
	print("INSTITUTION SERVICES PASS: delayed treatment, cancellation, stock, daily guards, living staff/horse, care, chapel, bell, disk save/load")
	quit()
