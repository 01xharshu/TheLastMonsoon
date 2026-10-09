extends SceneTree
## Verify configured startup and the actual Game -> Main Menu callback.
class EmptyInventory extends Node:
	func is_open() -> bool: return false
class ReviewPlayer extends CharacterBody3D:
	var inventory_ui := EmptyInventory.new()
	func _exit_tree() -> void: inventory_ui.free()
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)
func run() -> void:
	var startup: String = ProjectSettings.get_setting("application/run/main_scene")
	check(startup == "res://ui/studio_intro.tscn", "Configured startup bypasses studio intro")
	change_scene_to_file(startup)
	for i in 4: await process_frame
	check(current_scene.get_script().resource_path == "res://ui/studio_intro.gd", "Startup uses wrong studio script")
	current_scene._finish()
	await create_timer(0.75).timeout
	check(current_scene.get_script().resource_path == "res://ui/main_menu.gd", "Startup uses wrong menu script")
	check(current_scene.main_panel.get_child(0).text == "THE LAST\nMONSOON", "Startup does not use revised title")
	current_scene.show_settings()
	check(current_scene.page == "settings", "Settings unavailable")
	current_scene.show_main()
	var old_scene := current_scene
	current_scene = null
	old_scene.queue_free()
	await process_frame
	var world := Node3D.new()
	var player := ReviewPlayer.new()
	player.name = "Player"
	var ui := CanvasLayer.new()
	ui.name = "UI"
	player.add_child(ui)
	var hud := Control.new()
	hud.name = "HUDRoot"
	ui.add_child(hud)
	var map := Control.new()
	map.name = "WorldMap"
	map.set_script(load("res://player/world_map.gd"))
	ui.add_child(map)
	world.add_child(player)
	root.add_child(world)
	current_scene = world
	var menu := CanvasLayer.new()
	menu.name = "GameMenu"
	menu.set_script(load("res://ui/game_menu.gd"))
	world.add_child(menu)
	menu.open()
	menu.select_tab("game")
	menu.show_return_confirmation()
	var return_button: Button
	for child in menu.column.get_children():
		if child is Button and child.text == "Return without Saving": return_button = child
	check(return_button != null, "Return confirmation action missing")
	if return_button: return_button.pressed.emit()
	for i in 5: await process_frame
	check(current_scene != world and current_scene.get_script().resource_path == "res://ui/main_menu.gd", "Return action did not load live menu")
	check(not paused and current_scene.page == "main", "Return left menu paused or hidden")
	check(current_scene.main_panel.get_child(0).text == "THE LAST\nMONSOON", "Return uses stale title")
	await create_timer(0.9).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var capture := OS.get_environment("TLM_MENU_CAPTURE")
		if not capture.is_empty(): root.get_texture().get_image().save_png(capture)
	print("MENU INTEGRATION ", JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL", "failures":failures}))
	root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)
