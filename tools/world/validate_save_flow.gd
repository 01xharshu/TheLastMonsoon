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
	saves.save_root = "user://codex_save_validation"
	saves.settings_path = "user://codex_settings_validation.cfg"
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 4: await process_frame
	var player: CharacterBody3D = world.get_node("Player")
	player.set_physics_process(false)
	var inventory: InventoryComponent = player.get_node("InventoryComponent")
	var survival: SurvivalComponent = player.get_node("SurvivalComponent")
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
	check(saves.save_game(world,2),"Could not save slot 2")
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
	check(absf(world.get_node("GameTimeSystem").total_game_minutes-2200.0)<0.01,"Game time did not restore")
	check(inventory.get_item_count("roti")==3 and inventory.has_water_bag(),"Inventory did not restore")
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
	var report := {"status":"PASS" if failures.is_empty() else "FAIL","slot":2,"restored_position":player.global_position,"restored_water_liters":inventory.stored_water_liters,"failures":failures}
	var file := FileAccess.open("res://docs/world/save_flow_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	print("SAVE FLOW VALIDATION ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
