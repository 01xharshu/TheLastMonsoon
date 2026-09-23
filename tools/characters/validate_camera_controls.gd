extends SceneTree
## Godot --path . --script tools/characters/validate_camera_controls.gd
## Requires a display for captured-mouse input and view captures.
var failed := false

func _initialize() -> void:
	call_deferred("validate")

func check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)

func validate() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var clock := Node.new()
	clock.name = "GameTimeSystem"
	clock.set_script(load("res://world/suryagarh/systems/game_time_system.gd"))
	world.add_child(clock)
	var player = load("res://player/player.tscn").instantiate()
	world.add_child(player)
	player.rotation.y = -0.85
	player.get_node("RideComponent").set_process(false)
	player.set_physics_process(false)
	world.set_physics_process(false)
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var actor_basis: Basis = player.global_basis
	var body_basis: Basis = player.visual_root.global_basis
	var position: Vector3 = player.global_position
	var camera_basis: Basis = player.camera_pivot.global_basis
	var mouse := InputEventMouseMotion.new()
	mouse.relative = Vector2(350, 130)
	player._handle_mouse_look(mouse)
	check(player.global_basis.is_equal_approx(actor_basis), "Mouse rotated player root")
	check(player.visual_root.global_basis.is_equal_approx(body_basis), "Mouse rotated body")
	check(player.global_position.is_equal_approx(position), "Mouse moved player")
	check(not player.camera_pivot.global_basis.is_equal_approx(camera_basis), "Mouse did not rotate camera")
	player._handle_movement(0.1)
	check(player.visual_root.global_basis.is_equal_approx(body_basis), "No-input movement rotated body")
	for action in ["move_forward", "move_backward", "move_left", "move_right"]:
		player.velocity = Vector3.ZERO
		Input.action_press(action)
		for i in 60: player._handle_movement(1.0 / 60.0)
		Input.action_release(action)
		var local: Vector3 = {"move_forward": Vector3.FORWARD, "move_backward": Vector3.BACK, "move_left": Vector3.LEFT, "move_right": Vector3.RIGHT}[action]
		var expected := Basis(Vector3.UP, player.camera_pivot.global_rotation.y) * local
		check(player.velocity.normalized().dot(expected) > 0.99, action + " has incorrect direction")
		check(player.visual_root.global_basis.z.dot(expected) > 0.99, action + " body does not face movement")
		check(player.global_basis.is_equal_approx(actor_basis), action + " rotated actor root")
	for pair in [["move_forward", KEY_UP], ["move_backward", KEY_DOWN], ["move_left", KEY_LEFT], ["move_right", KEY_RIGHT]]:
		var key := InputEventKey.new()
		key.physical_keycode = pair[1]
		check(InputMap.event_is_action(key, pair[0]), "Arrow key missing: " + pair[0])
	# Mounted/climbing systems own body orientation; mouse must leave that intact.
	for mode in ["mounted_vehicle", "climbing"]:
		player.set_meta(mode, world if mode == "mounted_vehicle" else true)
		body_basis = player.visual_root.global_basis
		player._handle_mouse_look(mouse)
		check(player.visual_root.global_basis.is_equal_approx(body_basis), "Mouse changed body while " + mode)
		player.remove_meta(mode)
	var light := DirectionalLight3D.new()
	world.add_child(light)
	light.rotation_degrees = Vector3(-35, -20, 0)
	light.light_energy = 2.0
	player.camera_pivot.rotation = Vector3.ZERO
	player.set_first_person(true)
	check(not player.visual_root.visible, "First-person body blocks camera")
	check(player.first_person_view.arm_mesh_count > 0, "First-person arms are missing")
	check(is_zero_approx(player.get_node("CameraPivot/SpringArm3D").spring_length), "First-person camera is not at eye position")
	var equipment = player.get_node("VisualRoot/CharacterVisual").equipment
	equipment.stowed = false
	for selection in [0, 1]:
		equipment.select_weapon(selection)
		for i in 10: await process_frame
		player.first_person_view._process(0.016)
		check(player.first_person_view.equipment.selected == selection, "First-person weapon selection out of sync")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/arjun-first-person-%s.png" % selection)
	body_basis = player.visual_root.global_basis
	player._handle_mouse_look(mouse)
	check(player.visual_root.global_basis.is_equal_approx(body_basis), "First-person mouse rotated world body")
	player.is_swimming = true
	player.get_node("VisualRoot/CharacterVisual")._process(0.016)
	player.first_person_view._process(0.016)
	check(not player.first_person_view.equipment.enfield_hand.visible, "Swimming kept first-person weapon drawn")
	player.is_swimming = false
	player.set_meta("map_open", true)
	var toggle := InputEventAction.new()
	toggle.action = "toggle_view"
	toggle.pressed = true
	player._unhandled_input(toggle)
	check(player.first_person, "Map did not block view toggle")
	player.set_meta("map_open", false)
	player._unhandled_input(toggle)
	check(player.visual_root.visible and not player.first_person_view.visible, "Third-person visuals not restored")
	check(is_equal_approx(player.get_node("CameraPivot/SpringArm3D").spring_length, player.third_person_distance), "Third-person distance not restored")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	camera_basis = player.camera_pivot.global_basis
	player._handle_mouse_look(mouse)
	check(player.camera_pivot.global_basis.is_equal_approx(camera_basis), "Released mouse still rotates camera")
	print("CAMERA / MOVEMENT CONTROLS: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
