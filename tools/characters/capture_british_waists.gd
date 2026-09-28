extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280, 720)
	var world := load("res://world/suryagarh/suryagarh_world.tscn").instantiate() as Node3D
	root.add_child(world)
	current_scene = world
	root.content_scale_size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	world.get_node("Player").hide()
	world.get_node("Player/UI").hide()
	world.get_node("LandscapeUI").hide()
	var roster := world.get_node("BritishNpcRosterCandidate")
	for actor in roster.get_children():
		actor.set_process(false)
		var player: AnimationPlayer = actor.get("animation_player")
		player.pause()
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 30.0
	camera.make_current()
	for actor_name in ["PrivateWoman", "CaptainWoman", "OfficialWoman"]:
		var actor := roster.get_node(actor_name) as Node3D
		actor.set("_clock", 0.0)
		actor.call("_process", 0.0)
		for step in 45:
			actor.call("_process", 1.0/60.0)
		var direction := actor.basis.z.normalized()
		camera.global_position = actor.global_position + - actor.basis.z * 2.8 + Vector3.UP*1.8
		camera.look_at(actor.global_position + Vector3.UP*0.9)
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var path: String = "res://docs/characters/british/candidates/"+actor_name.to_snake_case()+"_waist_back.png"
		print("BRITISH_CADENCE_CAPTURE ", path, " ", root.get_texture().get_image().save_png(path))
	quit(0)
