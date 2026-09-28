extends SceneTree
## Capture the ordinary third-person camera from behind the player.

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	var player: CharacterBody3D = world.get_node("Player")
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.global_position = Vector3(-230, 10, 180)
	player.get_node("VisualRoot").rotation.y = PI
	player.camera_pitch = deg_to_rad(-10.0)
	player.camera_pivot.rotation = Vector3(player.camera_pitch, 0, 0)
	var camera: Camera3D = player.get_node("CameraPivot/SpringArm3D/Camera3D")
	camera.make_current()
	for i in 70:
		await physics_frame
	# The local user:// settings may contain an intentionally longer custom distance.
	# Pin this capture to the new default so it is comparable across machines.
	player.third_person_distance = 1.25
	player.get_node("CameraPivot/SpringArm3D").spring_length = 1.25
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var path := "/tmp/tlm_reference_camera_rear.png"
	var error := root.get_texture().get_image().save_png(path)
	print("REFERENCE CAMERA CAPTURE ", error, " ", path, " player=", player.global_position, " camera=", camera.global_position)
	quit(0 if error == OK else 1)
