extends SceneTree

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Title capture requires a native renderer")
		quit(1)
		return
	var menu: Control = load("res://ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://docs/world/captures/14_title_menu.png"
	var error := root.get_texture().get_image().save_png(path)
	print("TITLE MENU CAPTURE ", path, " status=", error)
	quit(0 if error == OK else 1)
