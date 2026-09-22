extends SceneTree
## Run without --headless to capture the actual Forward+/Metal renderer at 1280x720.
var frame_ms: Array[float] = []
var results: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	DisplayServer.window_set_size(Vector2i(1280,720))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.get_node("GameTimeSystem").clock_paused = true
	var player: CharacterBody3D = world.get_node("Player")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 90: await process_frame
	player.set_process_unhandled_input(false)
	var camera := Camera3D.new()
	camera.far = 4000
	world.add_child(camera)
	var layout = load("res://world/suryagarh/landscape_layout.gd").new()
	var views: Array[Dictionary] = [
		{"name":"01_overview", "position":Vector3(-670,540,740), "target":Vector3(70,15,-80)},
		{"name":"02_river", "position":Vector3(90,8,175), "target":Vector3(175,4,-50)},
		{"name":"03_hills", "position":Vector3(395,layout.height(395,-240)+3,-240), "target":Vector3(630,95,-470)},
		{"name":"04_plains", "position":Vector3(-450,layout.height(-450,-150)+3,-150), "target":Vector3(-150,20,-390)},
		{"name":"05_player", "position":Vector3.ZERO, "target":Vector3.ZERO}
	]
	DirAccess.make_dir_recursive_absolute("res://docs/world/captures")
	for view in views:
		var player_view: bool = view.name == "05_player"
		player.get_node("UI").visible = player_view
		world.get_node("LandscapeUI").visible = player_view
		player.visible = player_view
		player.set_physics_process(player_view)
		if player_view:
			world.move_to_review_point(0)
			world.player_camera.make_current()
		else:
			camera.position = view.position
			camera.look_at(view.target)
			camera.make_current()
		for i in 90: await process_frame
		var samples: Array[float] = []
		var tick: int = Time.get_ticks_usec()
		for i in 240:
			await process_frame
			var now: int = Time.get_ticks_usec()
			samples.append((now-tick)/1000.0)
			tick = now
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		img.save_png("res://docs/world/captures/" + view.name + ".png")
		samples.sort()
		var total: float = 0.0
		for ms in samples: total += ms
		var result: Dictionary = {"view":view.name,"average_fps":1000.0/(total/samples.size()),
			"p95_frame_ms":samples[int(samples.size()*0.95)], "draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
			"render_memory_mib":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0,
			"static_memory_mib":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0}
		results.append(result)
		print("CAPTURE ",JSON.stringify(result))
	var report: Dictionary = {"renderer":RenderingServer.get_current_rendering_method(),
		"adapter":RenderingServer.get_video_adapter_name(),"driver":RenderingServer.get_current_rendering_driver_name(),
		"resolution":[1280,720],"vsync":false,"frames_per_view":240,"views":results,
		"limitation":"Measured on host hardware, not an actual 8 GB device. Excludes future buildings, NPCs, weather and gameplay systems."}
	var file := FileAccess.open("res://docs/world/render_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	print("LANDSCAPE RENDER CAPTURE PASS")
	quit()
