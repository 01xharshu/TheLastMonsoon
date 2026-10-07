extends SceneTree
## Native new-game intro, skip/release and normal controller smoke route.
var failed := false
func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
func _initialize() -> void: _run.call_deferred()
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/world/captures/error_route_"+label+".png")
func _run() -> void:
	var saves = root.get_node("SaveManager")
	saves.start_new_game()
	for frame in 3: await process_frame
	var world: Node3D = current_scene
	var opening = world.get_node("OpeningSequence")
	var actor: CharacterBody3D = world.get_node("Player")
	for moment in [5.0,16.0,27.0]:
		while opening.elapsed < moment: await process_frame
		await capture("intro_"+str(int(moment)))
	while opening.state == "night": await process_frame
	check(opening.state == "seated","Intro did not reach morning")
	await capture("morning")
	var event := InputEventKey.new()
	event.keycode=KEY_W
	event.pressed=true
	opening._input(event)
	await create_timer(1.7).timeout
	check(opening.state == "done" and actor.is_physics_processing(),"Intro did not release controls")
	var routes: Dictionary = {}
	for spec in [["village",Vector2(-230,180)],["civil_lines",Vector2(640,235)],["cantonment",Vector2(500,465)]]:
		var at: Vector2 = spec[1]
		actor.global_position=Vector3(at.x,world.layout.height(at.x,at.y)+1.1,at.y)
		actor.velocity=Vector3.ZERO
		await create_timer(1.0).timeout
		var before := actor.global_position
		Input.action_press("move_forward")
		var frames: Array[float] = []
		var stop := Time.get_ticks_msec()+3000
		while Time.get_ticks_msec()<stop:
			var tick := Time.get_ticks_usec()
			await process_frame
			frames.append((Time.get_ticks_usec()-tick)/1000.0)
		Input.action_release("move_forward")
		frames.sort()
		routes[spec[0]]={"movement_m":actor.global_position.distance_to(before),"frame_ms_p50":frames[frames.size()/2],"frame_ms_p95":frames[int(frames.size()*.95)],"cpu_process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"cpu_physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000}
		await capture(spec[0])
	var pixels: Vector2i=root.get_texture().get_size()
	var file:=FileAccess.open("res://docs/world/game_error_route_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"FAIL" if failed else "PASS","renderer":RenderingServer.get_current_rendering_method(),"physical_viewport":str(pixels),"scale_3d":root.scaling_3d_scale,"render_3d_pixels":str(Vector2(pixels)*root.scaling_3d_scale),"routes":routes,"limit":"short native smoke route; shared desktop contention; no controlled FPS comparison"},"\t"))
	file.close()
	print("GAME ERROR ROUTE: ","FAIL" if failed else "PASS")
	preload("res://tools/test_audio_cleanup.gd").stop(root)
	await preload("res://tools/test_audio_cleanup.gd").settle(self)
	quit(1 if failed else 0)
