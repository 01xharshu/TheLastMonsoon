extends SceneTree
## Native new-game intro, skip/release and normal controller smoke route.
const Snapshot = preload("res://tools/world/performance_snapshot.gd")
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
	print("PERFORMANCE SNAPSHOT before_world ",JSON.stringify(Snapshot.capture()))
	# Use the same staged loader as the title's Begin New Journey callback.
	var loading := preload("res://ui/journey_loading.gd").new()
	root.add_child(loading)
	check(await loading.begin(0),"New Journey loader failed")
	if failed:
		await saves.quit_game(1)
		return
	var loader_timings: Dictionary = loading.timings.duplicate()
	for frame in 3: await process_frame
	print("GAME ERROR ROUTE READY | ",Time.get_ticks_msec()-started," ms | quality ",saves.options.graphics_quality)
	print("PERFORMANCE SNAPSHOT ready ",JSON.stringify(Snapshot.capture())," loader_phases ",JSON.stringify(loader_timings))
	var world: Node3D = current_scene
	var opening = world.get_node("OpeningSequence")
	var actor: CharacterBody3D = world.get_node("Player")
	print("PHYSICS BODY BUDGET | limit ",ProjectSettings.get_setting("physics/jolt_physics_3d/limits/max_bodies"))
	if "--skip-intro" in OS.get_cmdline_user_args():
		var skip := InputEventKey.new()
		skip.keycode = KEY_ESCAPE;skip.pressed = true
		opening._input(skip)
		await process_frame
		opening._input(skip)
	else:
		for moment in [5.0,16.0,27.0]:
			while opening.elapsed < moment: await process_frame
			await capture("intro_"+str(int(moment)))
	while opening.state in ["prologue","cart_passage","night"]: await process_frame
	check(opening.state in ["dawn","rising","departing","done"],"Intro did not reach morning")
	await capture("morning")
	var event := InputEventKey.new()
	event.keycode=KEY_W
	event.pressed=true
	opening._input(event)
	while opening.state != "done": await process_frame
	check(opening.state == "done" and actor.is_physics_processing(),"Intro did not release controls")
	print("PERFORMANCE SNAPSHOT playable ",JSON.stringify(Snapshot.capture()))
	var routes: Dictionary = {}
	var area := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--area="): area = argument.trim_prefix("--area=")
	for spec in [["village",Vector2(-230,180),Vector2(-310,230)],["civil_lines",Vector2(680,285),Vector2(680,245)],["cantonment",Vector2(500,470),Vector2(500,445)],["forest",Vector2(343,-105),Vector2(360,-103)]]:
		if not area.is_empty() and spec[0] != area: continue
		var at: Vector2 = spec[1]
		actor.global_position=Vector3(at.x,world.layout.height(at.x,at.y)+1.1,at.y)
		actor.velocity=Vector3.ZERO
		var direction: Vector2 = spec[2]-at
		actor.get_node("CameraPivot").global_rotation.y = atan2(-direction.x,-direction.y)
		actor.camera_pitch = deg_to_rad(-10.0)
		actor.get_node("CameraPivot").rotation.x = actor.camera_pitch
		await create_timer(1.0).timeout
		print("PERFORMANCE SNAPSHOT entered ",spec[0]," ",JSON.stringify(Snapshot.capture()))
		var before := actor.global_position
		Input.action_press("move_forward")
		var frames: Array[float] = []
		var stop := Time.get_ticks_msec()+3000
		while Time.get_ticks_msec()<stop:
			var tick := Time.get_ticks_usec()
			await process_frame
			frames.append((Time.get_ticks_usec()-tick)/1000.0)
		Input.action_release("move_forward")
		check(actor.global_position.distance_to(before)>1.0,"Walking route blocked in "+str(spec[0]))
		frames.sort()
		routes[spec[0]]={"movement_m":actor.global_position.distance_to(before),"frame_ms_p50":frames[frames.size()/2],"frame_ms_p95":frames[int(frames.size()*.95)],"frame_ms_p99":frames[mini(frames.size()-1,int(frames.size()*.99))],"frame_ms_max":frames.back(),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"cpu_process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"cpu_physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000}
		await capture(spec[0])
		print("PERFORMANCE SNAPSHOT leaving ",spec[0]," ",JSON.stringify(Snapshot.capture()))
	var pixels: Vector2i=root.size
	print(JSON.stringify({"status":"FAIL" if failed else "PASS","renderer":RenderingServer.get_current_rendering_method(),"physical_viewport":str(pixels),"scale_3d":root.scaling_3d_scale,"render_3d_pixels":str(Vector2(pixels)*root.scaling_3d_scale),"routes":routes,"limit":"short native smoke route; shared desktop contention; no controlled FPS comparison"}))
	print("GAME ERROR ROUTE: ","FAIL" if failed else "PASS")
	preload("res://tools/test_audio_cleanup.gd").stop(root)
	await preload("res://tools/test_audio_cleanup.gd").settle(self)
	quit(1 if failed else 0)
