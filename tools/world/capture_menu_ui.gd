extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("capture")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func capture() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Menu captures require a renderer")
		quit(1)
		return
	var menu: Control = load("res://ui/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	for i in 5: await process_frame
	var labels: Array[String] = []
	for button in menu.find_children("*","Button",true,false): labels.append(button.text)
	for expected in ["Play Game","Continue","Load Game","Settings"]:
		check(labels.has(expected),"Missing title action "+expected)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/world/captures/14_title_menu.png")
	root.remove_child(menu)
	menu.queue_free()
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 5: await process_frame
	var pause: CanvasLayer = world.get_node("GameMenu")
	pause.open()
	check(paused and pause.overlay.visible,"Pause menu did not stop the world")
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/world/captures/15_pause_menu.png")
	pause.close()
	check(not paused,"Pause menu did not resume the world")
	print("MENU UI VALIDATION ",JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","title_actions":labels,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
