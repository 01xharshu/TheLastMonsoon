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
	print("RENDER REVIEW ",label," | viewport ",root.size," scale ",root.scaling_3d_scale)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--review-dir="):
			var directory := argument.trim_prefix("--review-dir=")
			# Only the runner's disposable OS directory may receive review views.
			if not directory.is_absolute_path() or not directory.get_file().begins_with("tlm-performance-"):
				push_error("Review output requires a disposable performance directory")
				return
			var pixels := root.get_texture().get_image()
			pixels.resize(1280,720,Image.INTERPOLATE_LANCZOS)
			check(pixels.save_png(directory.path_join(label+".png"))==OK,"Temporary review view could not be written")
func _run() -> void:
	var saves = root.get_node("SaveManager")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--quality="):
			saves.options.graphics_quality = clampi(argument.trim_prefix("--quality=").to_int(),0,2)
	var started := Time.get_ticks_msec()
	saves.start_new_game()
	for frame in 3: await process_frame
	print("GAME ERROR ROUTE READY | ",Time.get_ticks_msec()-started," ms | quality ",saves.options.graphics_quality)
	var world: Node3D = current_scene
	var opening = world.get_node("OpeningSequence")
	var actor: CharacterBody3D = world.get_node("Player")
	print("PHYSICS BODY BUDGET | limit ",ProjectSettings.get_setting("physics/jolt_physics_3d/limits/max_bodies"))
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
	var pixels: Vector2i=root.size
	print(JSON.stringify({"status":"FAIL" if failed else "PASS","renderer":RenderingServer.get_current_rendering_method(),"physical_viewport":str(pixels),"scale_3d":root.scaling_3d_scale,"render_3d_pixels":str(Vector2(pixels)*root.scaling_3d_scale),"routes":routes,"limit":"short native smoke route; shared desktop contention; no controlled FPS comparison"}))
	print("GAME ERROR ROUTE: ","FAIL" if failed else "PASS")
	preload("res://tools/test_audio_cleanup.gd").stop(root)
	await preload("res://tools/test_audio_cleanup.gd").settle(self)
	quit(1 if failed else 0)
