extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	var menu: Control = load("res://ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	for i in 3: await process_frame
	_check(menu.page == "main", "Title did not open on main page")
	_check(menu.main_panel.visible and not menu.column.visible, "Title layout is not active")
	var labels: Array[String] = []
	for button in menu.main_panel.find_children("*", "Button", true, false):
		labels.append(button.text)
	_check(labels == ["Play Game", "Continue", "Load Game", "Settings", "Quit"], "Title actions differ from expected order")
	menu.show_settings()
	_check(menu.page == "settings" and menu.column.visible and not menu.main_panel.visible, "Settings page not visible")
	menu.show_main()
	menu.show_slots()
	_check(menu.page == "slots" and menu.column.visible and not menu.main_panel.visible, "Load page not visible")
	menu.show_main()
	_check(menu.main_panel.visible and not menu.page_shade.visible, "Returning to title failed")
	print("TITLE MENU VALIDATION ", JSON.stringify({"status": "PASS" if failures.is_empty() else "FAIL", "failures": failures}))
	quit(0 if failures.is_empty() else 1)
