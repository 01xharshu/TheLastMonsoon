extends SceneTree
var failed := false
func _initialize() -> void:
	call_deferred("run")
func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
func run() -> void:
	var world = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	await process_frame
	root.get_node("SaveManager").pending_slot = 0
	root.get_node("SaveManager").apply_pending(world)
	var opening = world.get_node("OpeningSequence")
	check(opening.shade.color == Color.BLACK,"Opening fade must be black before its first update")
	check(is_equal_approx(opening.top_bar.anchor_bottom,0.12) and is_equal_approx(opening.bottom_bar.anchor_top,0.88),"Letterbox bars missing")
	check(is_equal_approx(opening.subtitle.anchor_top,0.88),"Captions outside lower bar")
	check(opening.hint.text == "","Visible skip UI")
	check(not world.player.get_node("UI").visible,"Gameplay HUD visible")
	check(opening.home.get_meta("sleeping_window", "") == "open outward","Window remains closed")
	check(opening.expression.entries.size() >= 2,"Sadness/murmur shapes did not attach")
	check(opening.murmur.stream != null,"Murmur audio missing")
	check(opening.home != null,"Missing story home")
	check(not world.player.is_physics_processing(),"Player movement leaked")
	check(world.player.get_meta("opening_active",false),"Opening ownership missing")
	for t in [0.0,3.0,6.0,11.0,16.0,22.0,27.0]:
		if OS.get_environment("TLM_OPENING_REALTIME") == "1":
			while opening.elapsed < t:
				await process_frame
				if opening.elapsed >= 13.0 and opening.elapsed < 24.0:
					var camera_local: Vector3 = opening.home.to_local(opening.camera.global_position)
					check(camera_local.z < 3.41 and absf(camera_local.x) < 4.56,"Window camera left the room")
		else:
			opening.elapsed = t
		await create_timer(0.15).timeout
		check(not paused,"Cinematic input paused game")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/world/captures/opening_%02d.png" % int(t))
	if OS.get_environment("TLM_OPENING_REALTIME") == "1":
		while opening.state == "night": await process_frame
	else:
		opening.elapsed = 31.95
	await create_timer(0.2).timeout
	check(opening.state == "seated","Natural completion did not seat Arjun")
	check(opening.expression.entries.is_empty(),"Face mesh did not restore after cinematic")
	check(not opening.murmur.playing,"Voice continued into morning")
	check(opening.clock.current_hour == 6 and opening.clock.current_day == 2,"Wrong morning clock")
	var event := InputEventKey.new()
	event.keycode = KEY_W
	event.pressed = true
	opening._input(event)
	check(opening.state == "rising","W did not trigger rise")
	await create_timer(1.7).timeout
	check(opening.state == "done","Rise failed to release")
	check(world.player.is_physics_processing(),"Movement was not restored")
	check(not world.player.has_meta("opening_active"),"Opening lock leaked")
	check(world.player.get_meta("rest_action","") == "","Rest lock leaked")
	check(not paused,"Game remained paused")
	world.queue_free()
	await process_frame
	for key in [KEY_SPACE,KEY_ESCAPE]:
		world = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
		root.add_child(world)
		current_scene = world
		await process_frame
		await process_frame
		opening = load("res://story/opening_sequence.gd").new()
		world.add_child(opening)
		opening.start(world)
		event.keycode = key
		opening._input(event)
		check(opening.state == "seated","Skip failed")
		var minutes: float = opening.clock.total_game_minutes
		opening.morning()
		check(opening.clock.total_game_minutes == minutes,"Repeated skip advanced clock twice")
		await create_timer(0.9).timeout
		check(opening.state == "seated","Skip also stood Arjun up")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/world/captures/opening_morning.png")
		event.keycode = KEY_W
		opening._input(event)
		await create_timer(1.7).timeout
		check(opening.state == "done","Skipped sequence failed release")
		world.queue_free()
		await process_frame
	print("OPENING SEQUENCE: ","FAIL" if failed else "PASS"," | timeline, both skip keys, morning, fresh W, control release; visual approval separate")
	quit(1 if failed else 0)
