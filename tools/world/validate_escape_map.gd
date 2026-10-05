extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)
func run() -> void:
	if DisplayServer.get_name() == "headless":
		root.size = Vector2i(1280,720)
		root.content_scale_size = Vector2i(1280,720)
	var saves: Node = root.get_node("SaveManager")
	saves.settings_path = "user://escape_map_test.cfg"
	saves.save_root = "user://escape_map_test_saves"
	var original: Dictionary = saves.options.duplicate(true)
	var original_events: Dictionary = saves._original_input_events.duplicate(true)
	var world: Node3D = load(saves.WORLD).instantiate()
	root.add_child(world)
	current_scene = world
	for i in 5: await process_frame
	var menu: Node = world.get_node("GameMenu")
	var map: Control = world.get_node("Player/UI/WorldMap")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	for i in 3: await process_frame
	check(paused and map.visible and menu.page == "map","Escape menu must open paused on map")
	check(menu.navigation.get_child_count() == 3,"Three icon tabs required")
	map._update_map_area()
	print("FIXED MAP AREA ",map.map_rect," viewport ",map.size)
	var fixed_area: Rect2 = map.map_rect
	check(map.map_rect.size.x > map.map_rect.size.y,"Map must be wide")
	check(map.map_canvas.clip_contents,"Map content must clip inside fixed area")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = map.map_rect.get_center()
	map._gui_input(wheel)
	check(map.zoom > 1.0,"Pointer zoom")
	for i in 2: await process_frame
	check(map.map_rect == fixed_area,"Zoom must not resize map frame")
	check(is_equal_approx(map.project(Vector2(10,0)).distance_to(map.project(Vector2.ZERO)),map.project(Vector2(0,10)).distance_to(map.project(Vector2.ZERO))),"Map aspect must preserve world distance")
	var target := Vector2(-650,250)
	check(map.unproject(map.project(target)).distance_to(target)<0.01,"Map projection round trip")
	map.select_point(map.project(target))
	check(map.waypoint.distance_to(target)<1,"Random land click")
	menu.select_tab("settings")
	check(paused and not map.visible and menu.centre.visible,"Settings tab lifecycle")
	saves.set_option("graphics_quality",0)
	check(is_equal_approx(root.scaling_3d_scale,0.65),"Low resolution scale not applied")
	check(world.get_node("Sun").directional_shadow_max_distance == 40,"Low shadow distance not applied")
	saves.set_option("graphics_quality",2)
	check(root.msaa_3d == Viewport.MSAA_4X,"High antialiasing not applied")
	check(saves.bind_key("jump",KEY_F8),"Keyboard binding failed")
	saves.load_options()
	check(int(saves.options.key_bindings.get("jump",0)) == KEY_F8,"Binding persistence")
	check(not saves.bind_key("interact",KEY_F8),"Conflicting binding accepted")
	menu.select_tab("game")
	check(menu.page == "main" and paused,"Game tab lifecycle")
	check(saves.save_game(world,1),"Save slot write")
	check(saves.newest_slot() == 1,"Latest save lookup")
	check(saves.read_slot(1).has("waypoint_site"),"Site identity save compatibility")
	if DisplayServer.get_name() != "headless": saves.set_option("graphics_quality",0)
	menu.select_tab("map")
	map.map_center = target
	map.zoom = 2.5
	map.clamp_center()
	map.queue_redraw()
	for i in 3: await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/world/captures/escape_map_world.png")
	menu.close()
	check(not paused and not map.visible and not world.get_node("Player").get_meta("map_open"),"Resume lifecycle")
	for i in 10: await physics_frame
	print("WAYPOINT STATE ",map.waypoint," / ",map.marker.global_position," / ",map.marker.visible)
	check(map.marker.visible and absf(map.marker.global_position.x-target.x)<0.01,"World marker placement")
	check(map.minimap.is_inside_tree() and map.minimap.is_visible_in_tree(),"Gameplay minimap visible after resume")
	check(map.minimap.map.waypoint == map.waypoint,"Main/minimap shared waypoint")
	check(not map.marker.label.no_depth_test,"Marker distance must respect character depth")
	world.get_node("Player").set_physics_process(false)
	if DisplayServer.get_name() != "headless":
		var actor: CharacterBody3D = world.get_node("Player")
		map.waypoint = Vector2(actor.global_position.x+12,actor.global_position.z)
		map.selected_site = ""
		for i in 10: await physics_frame
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.global_position = map.marker.global_position+Vector3(3,3,14)
		camera.look_at(map.marker.global_position+Vector3(0,1,0))
		camera.make_current()
		actor.global_position = map.marker.global_position+Vector3(-2,0.95,8)
		for i in 4: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/world/captures/waypoint_grounded.png")
		actor.global_position = map.marker.global_position+Vector3(0,0.95,4)
		camera.global_position = map.marker.global_position+Vector3(0,1.7,9)
		camera.look_at(map.marker.global_position+Vector3(0,1.1,0))
		for i in 4: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/world/captures/waypoint_character_occlusion.png")
	world.get_node("Player").global_position = map.marker.global_position
	await create_timer(1.0).timeout
	check(not map.waypoint.is_finite(),"Arrival must clear waypoint after fade")
	saves.options = original
	saves._original_input_events = original_events
	saves._input_map_applied = false
	saves._set_active_input_device(saves.active_input_device)
	saves.apply_options(world)
	paused = false
	world.queue_free()
	for i in 3: await process_frame
	print("ESCAPE MAP VALIDATION ",JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","failures":failures}))
	quit(0 if failures.is_empty() else 1)
