extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("DEV IDLE CAPTURE requires rendered display")
		quit(1)
		return
	root.size = Vector2i(900, 900)
	root.content_scale_size = Vector2i(900, 900)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(900, 900)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.19, .20, .22)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .55
	stage.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, -30, 0)
	key.light_energy = 1.6
	stage.add_child(key)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8, 8)
	ground.mesh = plane
	stage.add_child(ground)
	var figure := load("res://characters/npcs/dev/dev_idle_candidate.glb").instantiate() as Node3D
	stage.add_child(figure)
	var walking := "--walk" in OS.get_cmdline_user_args()
	var clip := "Dev_walk_study" if walking else "Dev_idle_study"
	var player := figure.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null or not player.has_animation(clip):
		printerr("DEV CAPTURE missing imported animation: ", clip)
		quit(1)
		return
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.fov = 37.0
	camera.position = Vector3(4.2, 1.6, 0) if walking else Vector3(0, 1.6, 4.2)
	camera.look_at(Vector3(0, .9, 0))
	camera.make_current()
	player.play(clip)
	player.pause()
	var duration := player.get_animation(clip).length
	if "--record" in OS.get_cmdline_user_args():
		var folder := "/tmp/tlm_dev_walk_frames"
		DirAccess.make_dir_recursive_absolute(folder)
		for frame in 72:
			player.seek(fmod(float(frame) / 30.0, duration), true)
			await process_frame
			RenderingServer.force_draw(false)
			var error := viewport.get_texture().get_image().save_png(folder + "/%04d.png" % frame)
			if error != OK:
				quit(1)
				return
		print("DEV_WALK_RECORD 72 frames at fixed 30 Hz; in-place studio study")
		quit(0)
		return
	for phase in [0.0, .25, .5, .75]:
		player.seek(duration * phase, true)
		for frame in 4:
			await process_frame
		RenderingServer.force_draw(false)
		var label := "walk" if walking else "idle"
		var path := "res://docs/characters/npcs/dev_%s_%02d.png" % [label, roundi(phase * 100)]
		var error := viewport.get_texture().get_image().save_png(path)
		print("DEV_CAPTURE ", path, " ", error)
		if error != OK:
			quit(1)
			return
	quit(0)
