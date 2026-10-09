extends SceneTree
var failures: Array[String] = []
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
var layout := Layout.new()
var saves: Node

func _initialize() -> void:
	call_deferred("validate")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func validate() -> void:
	saves = root.get_node("SaveManager")
	var temporary := OS.get_environment("TLM_SAVE_TEST_DIR")
	if temporary.is_empty() or not temporary.begins_with(OS.get_environment("TMPDIR")):
		push_error("TLM_SAVE_TEST_DIR must be an OS temporary directory")
		quit(2); return
	saves.save_root = temporary + "/saves"
	saves.settings_path = temporary + "/settings.cfg"
	check(saves.newest_slot() == 0,"Fresh save directory should have no Continue slot")
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 30: await physics_frame
	var player: CharacterBody3D = world.get_node("Player")
	player.set_physics_process(false)
	var inventory: Node = player.get_node("InventoryComponent")
	var survival: Node = player.get_node("SurvivalComponent")
	var equipment: Node3D = player.get_node("VisualRoot/CharacterVisual").equipment
	player.global_position = Vector3(-245,layout.height(-245,185)+1.0,185)
	player.rotation.y = 0.42
	player.camera_pitch = -0.25
	world.get_node("GameTimeSystem").total_game_minutes = 2200.0
	inventory.add_item("water_bag",1)
	inventory.add_item("roti",3)
	inventory.add_water(1.25)
	survival.hydration = 43.0
	equipment.selected = 1
	equipment.stowed = false
	equipment._refresh()
	var door = world.get_node("Settlement/BhairavpurHouse1/EntranceDoor")
	door.restore_state(false)
	var shutters = world.get_node("Settlement/BhairavpurHouse1/TimberWindowFrameEast/PairedWoodShutters")
	shutters.swing_direction=-1.0
	shutters.restore_state(true)
	for slot in range(1,4):
		check(saves.save_game(world,slot),"Could not create fresh slot %d" % slot)
		check(not saves.read_slot(slot).is_empty(),"Fresh slot %d unreadable" % slot)
	inventory.add_item("roti",1)
	check(saves.save_game(world,2),"Could not replace existing slot 2")
	check(saves.last_error.is_empty(),"Successful save retained failure message")
	check(not FileAccess.file_exists(saves.slot_path(2)+".tmp"),"Successful save left temporary file")
	var newest: Dictionary = saves.read_slot(2)
	newest["saved_at"] = int(Time.get_unix_time_from_system())+2
	var newest_file := FileAccess.open(saves.slot_path(2),FileAccess.WRITE)
	newest_file.store_string(JSON.stringify(newest));newest_file.close()
	var original_root: String = saves.save_root
	var blocker := FileAccess.open(temporary+"/blocked",FileAccess.WRITE)
	blocker.store_string("directory creation blocker");blocker.close()
	saves.save_root = temporary+"/blocked/saves"
	check(not saves.save_game(world,2),"Invalid save destination reported success")
	saves.save_root = original_root
	check(saves.read_slot(2).items.roti == 4,"Failed write changed good slot")
	door.restore_state(true)
	shutters.swing_direction=1.0
	shutters.restore_state(false)
	check(saves.newest_slot()==2,"Continue did not choose newest slot")
	var saved_position := player.global_position
	player.global_position = Vector3.ZERO
	inventory.items.clear()
	inventory.stored_water_liters = 0
	survival.hydration = 100
	equipment.stowed = true
	saves.pending_slot = 2
	saves.apply_pending(world)
	check(player.global_position.distance_to(saved_position)<0.01,"Player position did not restore")
	check(not door.opened and is_zero_approx(door.swing),"Manual door state did not restore from slot")
	check(shutters.swing_direction == -1.0,"Manual shutter swing direction did not restore from slot")
	check(shutters.opened and is_equal_approx(shutters.swing,1.0),"Manual shutter state did not restore from slot")
	check(absf(world.get_node("GameTimeSystem").total_game_minutes-2200.0)<0.01,"Game time did not restore")
	check(inventory.get_item_count("roti")==4 and inventory.has_water_bag(),"Inventory did not restore")
	check(absf(inventory.stored_water_liters-1.25)<0.01,"Pouch water did not restore")
	check(absf(survival.hydration-43.0)<0.01,"Hydration did not restore")
	check(equipment.selected==1 and not equipment.stowed,"Weapon state did not restore")
	saves.set_option("mouse",1.4)
	saves.options["mouse"] = 1.0
	saves.load_options()
	check(absf(float(saves.options.mouse)-1.4)<0.01,"Mouse setting did not persist")
	check(absf(player.mouse_sensitivity-0.0035)<0.00001,"Mouse setting was not applied")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(2)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.save_root))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.settings_path))
	var report := {"status":"PASS" if failures.is_empty() else "FAIL","slot":2,"restored_position":player.global_position,"restored_water_liters":inventory.stored_water_liters,"door_closed_restored":not door.opened,"shutters_open_restored":shutters.opened,"failures":failures}
	print("SAVE FLOW VALIDATION ",JSON.stringify(report))
	world.queue_free()
	await process_frame
	preload("res://tools/test_audio_cleanup.gd").finish(self,0 if failures.is_empty() else 1)
