extends SceneTree
var samples: Array[float] = []
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_size(Vector2i(1280,720))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var start := Time.get_ticks_msec()
	var viewport := SubViewport.new()
	viewport.size=Vector2i(1280,720)
	viewport.own_world_3d=false
	root.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for frame in 12: await process_frame
	var startup_ms := Time.get_ticks_msec()-start
	var actor: CharacterBody3D = world.get_node("Player")
	actor.set_physics_process(false)
	actor.get_node("UI").hide()
	actor.get_node("CameraPivot/SpringArm3D/Camera3D").set_process(false)
	actor.get_node("VisualRoot").hide()
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.make_current()
	var views: Dictionary = {}
	for spec in [["village",Vector3(-310,9,245),Vector3(-310,9,230)], ["civil_lines",Vector3(665,12,275),Vector3(640,12,235)], ["cantonment",Vector3(500,11,510),Vector3(500,10,465)]]:
		actor.global_position = spec[1]
		camera.global_position = spec[1]
		camera.look_at(spec[2])
		for frame in 30: await process_frame
		samples.clear()
		var draws: Array[float] = []
		for frame in 120:
			var before := Time.get_ticks_usec()
			await process_frame
			samples.append(float(Time.get_ticks_usec()-before)/1000)
			draws.append(float(RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)))
		samples.sort()
		draws.sort()
		views[spec[0]] = {"frame_wall_ms_p50":samples[60],"frame_wall_ms_p95":samples[114],"draw_calls_p50":draws[60],"cpu_process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"cpu_physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,"objects":RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_OBJECTS_IN_FRAME),"primitives":RenderingServer.viewport_get_render_info(viewport.get_viewport_rid(),RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"static_memory_bytes":Performance.get_monitor(Performance.MEMORY_STATIC)}
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png("res://docs/world/captures/ordered_"+spec[0]+".png")
		print("RUNTIME VIEW ",spec[0]," ",views[spec[0]])
	var path := "res://docs/world/runtime_profile_ordered_2026-10-06.json"
	if "--after" in OS.get_cmdline_user_args(): path = "res://docs/world/runtime_profile_lighting_after.json"
	if "--door-batch" in OS.get_cmdline_user_args(): path = "res://docs/world/runtime_profile_door_batch.json"
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"date":Time.get_date_string_from_system(),"renderer":RenderingServer.get_current_rendering_method(),"requested_window_size":"1280x720","resolution":str(viewport.get_texture().get_width())+"x"+str(viewport.get_texture().get_height()),"device":RenderingServer.get_video_adapter_name(),"vsync":"disabled","startup_ms":startup_ms,"views":views,"scope":"live resident world, static cameras and active world simulation; desktop contention possible; not gameplay FPS or target-hardware approval"},"\t"))
	file.close()
	if "--after" in OS.get_cmdline_user_args():
		var clock = world.get_node("GameTimeSystem")
		var sun = world.get_node("Sun")
		clock.set_process(false)
		camera.global_position = Vector3(665,12,275)
		camera.look_at(Vector3(640,12,235))
		for spec in [["day",540.0],["night",1320.0]]:
			clock.total_game_minutes = spec[1]
			sun._process(0.016)
			for frame in 32: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/world/captures/optimisation_" + spec[0] + ".png")
	quit()
