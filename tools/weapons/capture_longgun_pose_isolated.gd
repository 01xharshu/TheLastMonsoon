extends SceneTree
## Stable side and rear pose check without loading the changing village world.
## godot --path . --rendering-driver metal --script tools/weapons/capture_longgun_pose_isolated.gd -- enfield

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("LONGGUN POSE: display renderer required")
		quit(1)
		return
	var weapon := "double_gun" if "double_gun" in OS.get_cmdline_user_args() else "enfield"
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var clock := Node.new()
	clock.name = "GameTimeSystem"
	clock.set_script(load("res://world/suryagarh/systems/game_time_system.gd"))
	world.add_child(clock)
	var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
	world.add_child(actor)
	actor.set_physics_process(false)
	actor.set_process(false)
	actor.get_node("RifleCombat").set_process(false)
	actor.get_node("DoubleGunCombat").set_process(false)
	actor.get_node("UI").hide()
	var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
	visual.set_process(false)
	actor.inventory.add_item(weapon, 1)
	var gear: Node = visual.equipment
	gear.select_weapon(5 if weapon == "double_gun" else 1)
	gear.stowed = false
	gear._refresh()
	gear.aiming = true
	gear.aim_direction = visual.model.global_basis.z
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -30, 0)
	sun.light_energy = 2.0
	world.add_child(sun)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 43.0
	camera.make_current()
	for i in 24: visual._process(1.0 / 60.0)
	var held: Node3D = gear.double_hand if weapon == "double_gun" else gear.enfield_hand
	var gun_local: Transform3D = visual.skeleton.global_transform.affine_inverse() * held.global_transform
	for side in ["r", "l"]:
		var shoulder: Vector3 = visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("upperarm_" + side)).origin
		var target: Vector3 = gun_local * (gear.rifle_grip if side == "r" else gear.rifle_support)
		print("LONGGUN REACH ", side, " shoulder=", shoulder, " target=", target, " distance=", shoulder.distance_to(target))
	for view in ["side"]:
		camera.global_position = visual.model.to_global(Vector3(-2.35, 1.55, 1.0) if view == "side" else Vector3(-1.15, 1.70, -2.20))
		camera.look_at(visual.model.to_global(Vector3(0, 1.42, .22)))
		await process_frame
		visual._process(1.0 / 60.0)
		await RenderingServer.frame_post_draw
		var path := "/tmp/tlm_longgun_pose_%s_%s.png" % [weapon, view]
		assert(root.get_texture().get_image().save_png(path) == OK)
		print("LONGGUN POSE ", weapon, " ", view, " ", path, " aiming=", gear.aiming, " grip=", gear.grip_errors())
	quit()
