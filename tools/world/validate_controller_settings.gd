extends SceneTree
## Checks settings controls and their fit at the configured 1280x720 viewport.

func _initialize() -> void:
	var menu: Control = load("res://ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu.show_settings()
	await process_frame
	var scroll: ScrollContainer = menu.column.get_child(0)
	var panel: VBoxContainer = scroll.get_child(0)
	var selectors := panel.find_children("*","OptionButton",true,false)
	var buttons := panel.find_children("*","Button",true,false)
	var height := scroll.get_combined_minimum_size().y
	if selectors.size() != 1 or buttons.size() < 3 or height > 600.0 or not scroll.follow_focus:
		push_error("CONTROLLER SETTINGS FAIL: selector=%d buttons=%d viewport_height=%.1f" % [selectors.size(),buttons.size(),height])
		quit(1)
		return
	print("CONTROLLER SETTINGS PASS: selector, feedback controls, minimum height %.1f" % height)
	quit()
