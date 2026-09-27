extends SceneTree
## Native runtime recording: do not manually update the rig or mount while sampling.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world: Node3D=load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene=world
	for i in 5: await physics_frame
	# Keep review rendering bounded without changing the user's persisted display settings.
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(960,540)
	root.content_scale_size=Vector2i(960,540)
	root.scaling_3d_scale=.75
	var actor: CharacterBody3D=world.get_node("Player")
	var boat: Node3D=world.get_node("RiverBoat")
	var visual: Node3D=actor.get_node("VisualRoot/CharacterVisual")
	actor.global_position=boat.global_position+Vector3(-2,1.2,0)
	if not boat.board(actor):
		push_error("Boat recording could not board")
		quit(1)
		return
	actor.get_node("UI").hide()
	world.get_node("LandscapeUI").hide()
	var camera:=Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	var worst:=0.0
	var errors: Array[float]=[]
	for frame in 300:
		match frame:
			30: Input.action_press("move_forward")
			100: Input.action_release("move_forward")
			130: Input.action_press("move_backward")
			200: Input.action_press("move_left")
			240:
				Input.action_release("move_backward")
				Input.action_release("move_left")
		await physics_frame
		camera.global_position=boat.global_position-boat.global_basis.x*3.1+Vector3.UP*1.5+boat.global_basis.z*1.5
		camera.look_at(boat.seat_world()+Vector3.UP*.4)
		await RenderingServer.frame_post_draw
		if frame>=15:
			for side in ["l","r"]:
				var rig: Skeleton3D=visual.skeleton
				var hand: Transform3D=rig.get_bone_global_pose(rig.find_bone("hand_"+side))
				var palm:=rig.to_global(hand*visual.equipment.palm_offsets[side])
				var error:=palm.distance_to(boat.paddle_grip_world(side))
				worst=maxf(worst,error)
				errors.append(error)
		if frame in [60,170,220,280]:
			root.get_texture().get_image().save_png("res://docs/world/captures/boat_runtime_%03d.png" % frame)
	errors.sort()
	var report: Dictionary={"frames":300,"max_palm_error_m":worst,"p95_palm_error_m":errors[int(errors.size()*.95)],"native_runtime":true,"passed":worst<.04}
	var file:=FileAccess.open("res://docs/world/boat_runtime_motion.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("BOAT NATIVE RUNTIME ","PASS" if worst<.04 else "FAIL"," maximum palm error m=",worst)
	quit(0 if worst<.04 else 1)
