extends SceneTree
## Native renderer composition check against the owner's over-shoulder reference.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("AIM CAMERA CAPTURE: display renderer required")
		quit(1)
		return
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 12: await physics_frame
	var actor: CharacterBody3D = world.get_node("Player")
	actor.set_physics_process(false)
	actor.set_process(false)
	actor.aim_camera_distance = 0.55
	actor.set_process_unhandled_input(false)
	actor.get_node("UI").hide()
	var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
	visual.set_process(false)
	actor.inventory.add_item("pistol", 1)
	visual.equipment.select_weapon(3)
	visual.equipment.stowed = false
	visual.equipment._refresh()
	visual.equipment.aiming = true
	var camera: Camera3D = actor.get_node("CameraPivot/SpringArm3D/Camera3D")
	camera.make_current()
	actor.get_node("PistolCombat").aiming = true
	actor.camera_pivot.rotation = Vector3(0.0, PI, 0.0)
	visual.equipment.aim_direction = -camera.global_basis.z
	actor.aim_blend = 1.0
	actor._update_weapon_camera(1.0 / 60.0)
	print("AIM SETUP selected=", visual.equipment.selected, " stowed=", visual.equipment.stowed, " combat=", actor.get_node("PistolCombat").aiming, " blend=", actor.aim_blend)
	for i in 6:
		visual._process(1.0 / 60.0)
		await process_frame
	var grip_error: float = visual.equipment.held_contact_errors()["pistol_palm_m"]
	var barrel_direction: Vector3 = visual.equipment.pistol_hand.global_basis.x.normalized()
	print("AIM GRIP palm_m=", grip_error, " barrel_dot_camera=", barrel_direction.dot(-camera.global_basis.z))
	await RenderingServer.frame_post_draw
	var path := "/tmp/tlm_aim_camera_reference.png"
	assert(root.get_texture().get_image().save_png(path) == OK)
	print("AIM CAMERA CAPTURE ", path, " arm=", actor.get_node("CameraPivot/SpringArm3D").spring_length, " lateral=", actor.get_node("CameraPivot/SpringArm3D").position.x, " fov=", camera.fov)
	quit()
