extends SceneTree
## Metal/Forward+ capture of the saved third-person camera while the real player walks.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	var player: CharacterBody3D = world.get_node("Player")
	var camera: Camera3D = player.get_node("CameraPivot/SpringArm3D/Camera3D")
	camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.global_position = Vector3(-230, 10, 180)
	player.camera_pitch = deg_to_rad(-10.0)
	player.camera_pivot.rotation = Vector3(player.camera_pitch, 0, 0)
	player.get_node("VisualRoot").rotation.y = PI
	for i in 40:
		await physics_frame
	var start: Vector3 = player.global_position
	Input.action_press("move_forward")
	for i in 100:
		await physics_frame
	Input.action_release("move_forward")
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var moved := Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()
	var outdoor_path := "/tmp/tlm_reference_camera_walk.png"
	var outdoor_error := root.get_texture().get_image().save_png(outdoor_path)
	print("REFERENCE CAMERA WALK ", "PASS" if moved > 0.75 and outdoor_error == OK else "FAIL", " moved=", moved, " player=", player.global_position, " camera=", camera.global_position, " capture=", outdoor_path)
	player.set_physics_process(false)
	var house: Node3D = world.get_node("Settlement/GovernmentHouse/MainHouse")
	player.global_position = house.to_global(Vector3(20, 0.95, 8.0))
	player.camera_pivot.rotation = Vector3(player.camera_pitch, 0, 0)
	player.get_node("VisualRoot").rotation.y = PI
	for i in 25:
		await physics_frame
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var indoor_path := "/tmp/tlm_reference_camera_indoor.png"
	var indoor_error := root.get_texture().get_image().save_png(indoor_path)
	var ray := PhysicsRayQueryParameters3D.create(player.get_node("CameraPivot/SpringArm3D").global_position, camera.global_position)
	ray.exclude = [player.get_rid()]
	var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
	print("REFERENCE CAMERA INDOOR ", "PASS" if indoor_error == OK and hit.is_empty() else "FAIL", " capture=", indoor_path, " camera_hit=", hit.get("collider", null))
	quit(0 if moved > 0.75 and outdoor_error == OK and indoor_error == OK and hit.is_empty() else 1)
