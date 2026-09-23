extends SceneTree
var failures: Array[String] = []
var saves: Node

func _initialize() -> void:
	call_deferred("validate")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func button_with_text(parent: Node, prefix: String) -> Button:
	for child in parent.get_children():
		if child is Button and child.text.begins_with(prefix): return child
	return null

func validate() -> void:
	saves=root.get_node("SaveManager")
	saves.save_root="user://codex_menu_validation"
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene=world
	for i in 3: await process_frame
	var player: CharacterBody3D = world.get_node("Player")
	var expected := Vector3(-245,world.layout.height(-245,185)+1.0,185)
	player.global_position=expected
	var pause_menu: CanvasLayer = world.get_node("GameMenu")
	pause_menu.open()
	check(paused and pause_menu.overlay.visible,"Pause menu did not open")
	var save_button := button_with_text(pause_menu.column,"Save Game")
	check(save_button != null,"Save Game button missing")
	if save_button: save_button.pressed.emit()
	var slot_button := button_with_text(pause_menu.column,"Slot 1")
	check(slot_button != null,"Save slot 1 button missing")
	if slot_button: slot_button.pressed.emit()
	check(not saves.read_slot(1).is_empty(),"Pause menu slot button did not write save")
	pause_menu.close()
	check(not paused,"Pause menu did not resume")
	change_scene_to_file("res://ui/main_menu.tscn")
	for i in 3: await process_frame
	var menu: Control = current_scene
	var continue_button := button_with_text(menu.column,"Continue")
	check(continue_button != null and not continue_button.disabled,"Title Continue was unavailable")
	if continue_button: continue_button.pressed.emit()
	for i in 5: await process_frame
	var loaded: Node = current_scene
	check(loaded != null and loaded.name == "Suryagarh","Continue did not load the world")
	if loaded != null and loaded.name == "Suryagarh":
		var restored: CharacterBody3D = loaded.get_node("Player")
		check(restored.global_position.distance_to(expected)<0.2,"Continue did not restore player position")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(1)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.save_root))
	var report := {"status":"PASS" if failures.is_empty() else "FAIL","expected":expected,"failures":failures}
	var file := FileAccess.open("res://docs/world/menu_navigation_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	print("MENU NAVIGATION VALIDATION ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
