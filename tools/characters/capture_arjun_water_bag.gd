extends SceneTree
## Close target-renderer review of the carried pouch and ordinary movement.
const OUTPUT := "res://docs/characters/arjun/water_bag_fit_2026-09-30/"
var actor: CharacterBody3D
var camera: Camera3D
var bag: Node3D
var equipment: Node3D
var report := {"states": [], "motion": []}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("WATER BAG CAPTURE requires a rendered display")
		quit(1)
		return
	Engine.time_scale = 1.0
	root.size = Vector2i(1280, 900)
	root.content_scale_size = Vector2i(1280, 900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var clock := Node.new()
	clock.name = "GameTimeSystem"
	clock.set_script(load("res://world/suryagarh/systems/game_time_system.gd"))
	stage.add_child(clock)
	var floor_body := StaticBody3D.new()
	stage.add_child(floor_body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(24, 0.4, 24)
	shape.shape = box
	shape.position.y = -0.2
	floor_body.add_child(shape)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(24, 24)
	floor_mesh.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.34, 0.35, 0.32)
	ground_material.roughness = 1.0
	floor_mesh.material_override = ground_material
	floor_body.add_child(floor_mesh)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.20, 0.23, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.8)
	environment.environment = env
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	stage.add_child(sun)
	actor = load("res://player/player.tscn").instantiate()
	stage.add_child(actor)
	actor.position = Vector3(0, 0.95, 0)
	actor.get_node("UI").hide()
	equipment = actor.get_node("VisualRoot/EquipmentVisuals")
	bag = equipment.get_node("WaterBagVisual")
	camera = Camera3D.new()
	camera.fov = 37.0
	stage.add_child(camera)
	camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for frame in 20: await physics_frame
	print("BAG CAPTURE: stage ready")
	actor.set_physics_process(false)
	for state in [["empty", 0.0], ["half", 1.0], ["full", 2.0]]:
		actor.inventory.consume_water(2.0)
		actor.inventory.add_water(state[1])
		for frame in 24: await process_frame
		for view in [["front", Vector3(0.55, 0.08, 0.8)], ["side", Vector3(0.95, 0.05, -0.06)], ["back", Vector3(0.60, 0.06, -0.78)]]:
			_point_camera(view[1])
			await _shot(state[0] + "_" + view[0])
		report.states.append({"state":state[0], "liters":actor.inventory.stored_water_liters, "fullness":bag.fullness, "body_bounds":str(bag.body.mesh.get_aabb()), "belt_error_m":bag.belt_pin_world().distance_to(bag.global_position)})
	actor.set_physics_process(true)
	for segment in [["walk", "move_forward", false], ["run", "move_forward", true], ["turn", "move_left", true], ["stop", "", false]]:
		for action in ["move_forward", "move_left", "sprint"]: Input.action_release(action)
		if segment[1] != "": Input.action_press(segment[1])
		if segment[2]: Input.action_press("sprint")
		var max_pin_error := 0.0
		var max_sway := 0.0
		for frame in 30:
			await physics_frame
			_point_camera(Vector3(0.62, 0.07, -0.80))
			max_pin_error = maxf(max_pin_error, bag.belt_pin_world().distance_to(bag.global_position))
			max_sway = maxf(max_sway, absf(equipment.bag_sway_x) + absf(equipment.bag_sway_z))
		await _shot("motion_" + segment[0])
		report.motion.append({"segment":segment[0], "position":str(actor.global_position), "speed_m_s":actor.velocity.length(), "max_pin_error_m":max_pin_error, "max_sway_radians":max_sway})
	for action in ["move_forward", "move_left", "sprint"]: Input.action_release(action)
	var file := FileAccess.open(OUTPUT + "review.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("WATER BAG CAPTURE: PASS | empty/half/full and normal-speed walk/run/turn/stop; ", OUTPUT)
	quit()

func _point_camera(offset: Vector3) -> void:
	var facing: Basis = actor.get_node("VisualRoot").global_basis.orthonormalized()
	var target := bag.global_position + facing * Vector3(0.075, -0.18, 0.0)
	camera.global_position = target + facing * offset
	camera.look_at(target)
	camera.make_current()

func _shot(label: String) -> void:
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	var path := OUTPUT + label + ".png"
	assert(root.get_texture().get_image().save_png(path) == OK)
	print("BAG CAPTURE ", label)
