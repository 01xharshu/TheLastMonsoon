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
	var title_settings: Node=current_scene.column.find_child("SettingsPanel",true,false)
	title_settings.show_category("Audio")
	var cancel:=InputEventAction.new();cancel.action="ui_cancel";cancel.pressed=true
	current_scene._input(cancel)
	check(current_scene.page=="settings" and title_settings.category=="", "Title Back leaves submenu instead of returning to categories")
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
	var document := Control.new()
	ui.add_child(document)
	var hidden_prompt := Control.new()
	hidden_prompt.hide()
	ui.add_child(hidden_prompt)
	var gameplay_overlay := CanvasLayer.new()
	gameplay_overlay.layer = 80
	world.add_child(gameplay_overlay)
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
	check(not hud.visible and not document.visible and not gameplay_overlay.visible, "Pause leaves gameplay UI visible")
	check(ui.visible and map.visible and menu.overlay.visible, "Pause hides its own shared map or menu")
	menu.select_tab("game")
	check(not hud.visible and not gameplay_overlay.visible, "Game tab restores gameplay UI")
	menu.select_tab("settings")
	check(not hud.visible and not gameplay_overlay.visible, "Settings tab restores gameplay UI")
	var pause_settings: Node=menu.column.find_child("SettingsPanel",true,false)
	pause_settings.show_category("Audio")
	var pause_cancel:=InputEventAction.new();pause_cancel.action="pause";pause_cancel.pressed=true
	menu._input(pause_cancel)
	check(menu.overlay.visible and pause_settings.category=="", "Pause Back closes game instead of returning to settings categories")
	menu.close()
	check(hud.visible and document.visible and gameplay_overlay.visible and not hidden_prompt.visible, "Resume does not preserve prior UI visibility")
	hud.hide()
	menu.open()
	menu.close()
	check(not hud.visible, "Resume shows a HUD that was already hidden")
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
