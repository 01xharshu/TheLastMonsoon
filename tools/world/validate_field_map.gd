extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("validate")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func validate() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	var player: CharacterBody3D = world.get_node("Player")
	player.set_physics_process(false)
	var map: Control = player.get_node("UI/WorldMap")
	map.set_open(true)
	for i in 5: await process_frame
	check(map.terrain.get_size().x >= 1024,"High-resolution map raster missing")
	var target := Vector2(320,120)
	check(map.unproject(map.project(target)).distance_to(target)<0.01,"World/screen map projection mismatch")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = map.map_rect.get_center()
	map._gui_input(wheel)
	map._gui_input(wheel)
	map._gui_input(wheel)
	check(map.zoom > 1.9,"Map did not zoom with pointer wheel")
	map.map_center = target
	map.clamp_center()
	for i in 3: await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/world/captures/10_map_zoom.png")
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = map.map_rect.get_center()
	map._gui_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = down.position
	map._gui_input(up)
	check(map.waypoint.distance_to(target)<1.0,"Map click did not place marker at selected location")
	var motion := InputEventMouseMotion.new()
	motion.position = down.position+Vector2(50,20)
	motion.relative = Vector2(50,20)
	map._gui_input(down)
	map._gui_input(motion)
	map._gui_input(up)
	check(map.map_center.distance_to(target)>1.0,"Map drag did not pan")
	map.set_open(false)
	check(not player.get_meta("map_open"),"Map did not release gameplay input")
	print("FIELD MAP VALIDATION ",JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","zoom":map.zoom,"waypoint":map.waypoint,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
