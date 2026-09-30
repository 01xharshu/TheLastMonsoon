extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	var world := load("res://world/suryagarh/suryagarh_world.tscn").instantiate() as Node3D
	root.add_child(world)
	current_scene = world
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	world.get_node("Player").hide()
	world.get_node("Player/UI").hide()
	world.get_node("LandscapeUI").hide()
	var roster := world.get_node("BritishNpcRosterCandidate")
	for actor in roster.get_children():
		actor.set_process(false)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 38.0
	camera.make_current()
	var actor_name := "PrivateWoman" if "--female-only" in OS.get_cmdline_user_args() else "PrivateMan"
	var actor := roster.get_node(actor_name) as Node3D
	var axis: Vector3 = actor.get("patrol_axis")
	var home: Vector3 = actor.get("_home")
	actor.position = home + axis.normalized() * float(actor.get("patrol_distance"))
	actor.rotation.y = atan2(axis.x,axis.z)
	actor.set("_clock",4.0)
	actor.call("_set_animation", &"idle", 0.2)
	var initial_basis := actor.basis
	camera.global_position = actor.global_position + initial_basis.x * 3.2 + initial_basis.z * 1.4 + Vector3.UP*1.35
	camera.look_at(actor.global_position + Vector3.UP*0.8)
	for phase in [25,75]:
		for step in (15 if phase == 25 else 30):
			actor.call("_process",1.0/120.0)
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://docs/characters/british/candidates/%s_stepping_turn_%02d.png" % [actor_name.to_snake_case(),phase]
		var err := root.get_texture().get_image().save_png(path)
		print("BRITISH_STEPPING_TURN_CAPTURE ",path," ",err)
		if err != OK:
			quit(1)
			return
	if "--face" in OS.get_cmdline_user_args():
		var skeleton := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var focus := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("head")).origin) + Vector3.UP * 0.10
		camera.fov = 28.0
		camera.global_position = focus + actor.basis.z * 0.8 + Vector3.UP * 0.02
		camera.look_at(focus)
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://docs/characters/british/candidates/%s_iris_review.png" % actor_name.to_snake_case()
		var err := root.get_texture().get_image().save_png(path)
		print("BRITISH_IRIS_CAPTURE ",path," ",err)
		if err != OK:
			quit(1)
			return
	quit(0)
