extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await scene_changed
	_check(current_scene.get_script().resource_path == "res://ui/studio_intro.gd", "Configured startup must reach studio intro")
	current_scene._finish()
	await scene_changed
	var menu: Control = current_scene
	_check(menu.get_script().resource_path == "res://ui/main_menu.gd", "Studio intro did not reach implemented Story menu")
	for i in 3: await process_frame
	_check(menu.page == "main", "Title did not open on main page")
	_check(menu.main_panel.visible and not menu.column.visible, "Title layout is not active")
	var labels: Array[String] = []
	for button in menu.main_panel.find_children("*", "Button", true, false):
		labels.append(button.accessibility_name)
	_check(labels == ["Save Game", "Load Game", "New Game", "Exit Game"], "Title actions differ from expected order")
	menu.show_settings()
	_check(menu.page == "settings" and menu.column.visible and not menu.main_panel.visible, "Settings page not visible")
	menu.show_main()
	menu.continuation.pressed.emit()
	_check(menu.page == "slots" and menu.column.visible and not menu.main_panel.visible, "Load page not visible")
	menu.show_main()
	_check(menu.main_panel.visible and not menu.page_shade.visible, "Returning to title failed")
	var cancel := InputEventKey.new()
	cancel.keycode = KEY_ESCAPE
	cancel.pressed = true
	menu.show_settings()
	menu._input(cancel)
	_check(menu.page == "main", "Escape did not return to title")
	menu.continuation.grab_focus()
	_check(menu.action_hint.text.contains("saved journey"), "Focus did not update action description")
	var saves := root.get_node("SaveManager")
	var original_root: String = saves.save_root
	saves.save_root = OS.get_temp_dir().path_join("tlm_title_" + str(OS.get_process_id()))
	DirAccess.make_dir_recursive_absolute(saves.save_root)
	var fixture := FileAccess.open(saves.slot_path(1), FileAccess.WRITE)
	fixture.store_string(JSON.stringify({"version": saves.VERSION, "position": [0,0,0], "saved_at": 1}))
	fixture.close()
	menu.play_button.pressed.emit()
	_check(menu.alert_plate.texture != null, "Reference alert artwork missing")
	_check(menu.tiles[0].disabled, "Save must be locked outside gameplay")
	_check(menu.tiles[2].size == Vector2(572,312), "New Game reference geometry changed")
	_check(menu.page == "new_game" and menu.column.visible, "Existing save did not show new journey confirmation")
	menu._input(cancel)
	_check(menu.page == "main", "Cancel new journey did not return to title")
	_check(not saves.read_slot(1).is_empty(), "Cancelling New Game changed the existing save")
	DirAccess.remove_absolute(saves.slot_path(1))
	DirAccess.remove_absolute(saves.save_root)
	saves.save_root = original_root
	print("TITLE MENU VALIDATION ", JSON.stringify({"status": "PASS" if failures.is_empty() else "FAIL", "failures": failures}))
	root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)
