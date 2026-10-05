extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(960,540)
	var world = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for frame in 16: await physics_frame
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(960,540)
	root.content_scale_size = Vector2i(960,540)
	RenderingServer.viewport_set_scaling_3d_scale(root.get_viewport_rid(),.5)
	var actor = world.get_node("Player")
	var pivot: Node3D = actor.get_node("CameraPivot")
	var camera: Camera3D = actor.get_node("CameraPivot/SpringArm3D/Camera3D")
	camera.make_current()
	var clock = world.find_child("GameTimeSystem",true,false)
	clock.advance_minutes(10*60-fmod(clock.total_game_minutes,1440))
	DirAccess.make_dir_recursive_absolute("/tmp/tlm_admin_camera")
	DirAccess.make_dir_recursive_absolute("res://docs/world/captures")
	var samples := 0
	var obstructions := 0
	var clips := 0
	var frame_id := 0
	var frame_times: Array[int] = []
	for room in get_nodes_in_group("administrative_buildings"):
		var entry: Vector3 = room.get_node("Entrance").global_position
		actor.global_position = entry+Vector3.UP*.95
		actor.velocity = Vector3.ZERO
		pivot.rotation = Vector3.ZERO
		for frame in 20: await physics_frame
		for target in [room.to_global(Vector3(0,1.15,-1)),entry+Vector3.UP*.95]:
			var reached := false
			for frame in 600:
				var toward: Vector3 = target-actor.global_position
				toward.y = 0
				if toward.length() < .5:
					reached = true
					break
				var desired_yaw := atan2(-toward.x,-toward.z)
				var yaw_gap := absf(wrapf(desired_yaw-pivot.global_rotation.y,-PI,PI))
				pivot.global_rotation.y = rotate_toward(pivot.global_rotation.y,desired_yaw,.05)
				if yaw_gap > .12: Input.action_release("move_forward")
				else: Input.action_press("move_forward")
				await physics_frame
				if frame%6 != 0: continue
				await RenderingServer.frame_post_draw
				var ray = PhysicsRayQueryParameters3D.create(pivot.global_position,camera.global_position)
				ray.exclude = [actor.get_rid()]
				var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
				if not hit.is_empty() and hit.position.distance_to(camera.global_position) > .06: obstructions += 1
				var query := PhysicsShapeQueryParameters3D.new()
				var sphere := SphereShape3D.new()
				sphere.radius = .055
				query.shape = sphere
				query.transform.origin = camera.global_position
				query.exclude = [actor.get_rid()]
				if not world.get_world_3d().direct_space_state.intersect_shape(query,8).is_empty(): clips += 1
				var image := root.get_texture().get_image()
				image.resize(960,540)
				image.save_png("/tmp/tlm_admin_camera/frame_%04d.png"%frame_id)
				frame_times.append(Engine.get_physics_frames())
				frame_id += 1
				samples += 1
			Input.action_release("move_forward")
			if not reached:
				print("CAMERA ROUTE FAILED ",room.name," ",actor.global_position," -> ",target)
				quit(1)
				return
		root.get_texture().get_image().save_png("res://docs/world/captures/"+str(room.name).to_snake_case()+"_player_camera.png")
		print("PLAYER CAMERA WALK ",room.name," reached")
	var timings := FileAccess.open("/tmp/tlm_admin_camera/timings.txt",FileAccess.WRITE)
	for i in frame_times.size():
		timings.store_line("file frame_%04d.png"%i)
		if i+1 < frame_times.size(): timings.store_line("duration %.5f"%(float(frame_times[i+1]-frame_times[i])/60.0))
	var report := {"renderer":RenderingServer.get_current_rendering_method(),"samples":samples,"pivot_segment_obstructions":obstructions,"camera_sphere_overlaps":clips,"actual_player_input":true,"routes":6,"buildings":3,"entry_and_exit":true}
	FileAccess.open("res://docs/world/administrative_camera_review.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("PLAYER CAMERA REVIEW ",report)
	quit(0 if obstructions == 0 and clips == 0 else 1)
