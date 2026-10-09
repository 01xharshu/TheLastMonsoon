extends SceneTree
## Caller owns temporary output directory and must delete it after review.
var output := ""
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.content_scale_size = Vector2i(1280,720)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	print("SKY WORLD LOADED")
	var opening: Node = world.get_node_or_null("OpeningSequence")
	if opening:
		var skip := InputEventKey.new()
		skip.keycode = KEY_ESCAPE
		skip.pressed = true
		for i in range(2):
			opening._input(skip)
			await process_frame
		while opening.state != "done": await process_frame
	var player: Node3D = world.get_node("Player")
	player.set_physics_process(false)
	player.hide()
	player.get_node("UI").hide()
	world.get_node("LandscapeUI").hide()
	var clock: GameTimeSystem = world.get_node("GameTimeSystem")
	clock.set_process(false)
	var sun: DirectionalLight3D = world.get_node("Sun")
	var flock: Node3D = world.get_node("SkyBirds")
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	camera.fov = 65.0
	camera.far = 2200.0
	var layout := preload("res://world/suryagarh/landscape_layout.gd").new()
	for spec in [["day_village",12.0,Vector2(-260,150)],["dusk_fields",18.0,Vector2(-440,-200)],["night_river",22.0,Vector2(12,155)],["dawn_fields",6.0,Vector2(-440,-200)]]:
		clock.total_game_minutes = float(spec[1]) * 60.0
		sun._update_day_night_lighting()
		flock._update_activity()
		var point: Vector2 = spec[2]
		player.position = Vector3(point.x,layout.height(point.x,point.y)+1.7,point.y)
		camera.position = player.position
		var nearest: Node3D = flock.birds[0]
		for bird in flock.birds:
			if bird.position.distance_to(camera.position) < nearest.position.distance_to(camera.position): nearest = bird
		var target: Vector3 = world.get_node("Moon").global_basis.z if float(spec[1]) == 22.0 else (nearest.position-camera.position).normalized()
		camera.look_at(camera.position + target)
		for i in range(10): await process_frame
		var first_position: Vector3 = nearest.position
		var first_phase: float = flock.elapsed
		var start := Time.get_ticks_msec()
		var frames := 0
		var costs: Array[float] = []
		while Time.get_ticks_msec()-start < 3000:
			var before := Time.get_ticks_usec()
			await process_frame
			costs.append((Time.get_ticks_usec()-before)/1000.0)
			frames += 1
		if float(spec[1]) == 22.0:
			assert(not flock.visible and flock.elapsed == first_phase)
		else:
			assert(flock.visible and nearest.position.distance_to(first_position) > 0.1)
		await RenderingServer.frame_post_draw
		if output != "":
			var capture := root.get_texture().get_image()
			capture.resize(1280,720)
			capture.save_png(output+"/"+str(spec[0])+".png")
		costs.sort()
		print("SKY WORLD ",spec[0]," frames=",frames," p50_ms=",costs[costs.size()/2]," p95_ms=",costs[int((costs.size()-1)*0.95)]," birds=",flock.visible)
	print("SKY WORLD ROUTE PASS")
	preload("res://tools/test_audio_cleanup.gd").stop(root)
	world.queue_free()
	await process_frame
	await preload("res://tools/test_audio_cleanup.gd").settle(self)
	quit()
