extends SceneTree
## Isolated native player-camera sequence. Run without --headless.
const OUTPUT := "res://docs/characters/arjun/pistol_motion_review_2026-10-05"
const FRAMES := 114
const STEP := 1.0 / 30.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("PISTOL REVIEW requires the native renderer")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	var stage := Node3D.new()
	root.add_child(stage)
	var clock := Node.new()
	clock.name = "GameTimeSystem"
	clock.set_script(load("res://world/suryagarh/systems/game_time_system.gd"))
	stage.add_child(clock)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.37, 0.41, 0.39)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.8, 0.8, 0.8)
	environment.ambient_light_energy = 0.8
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)
	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-40, -20, 0)
	stage.add_child(sunlight)
	var floor := StaticBody3D.new()
	stage.add_child(floor)
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(40, 0.2, 40)
	floor_shape.shape = floor_box
	floor_shape.position.y = -0.1
	floor.add_child(floor_shape)
	var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
	stage.add_child(actor)
	var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
	var pistol: Node = actor.get_node("PistolCombat")
	var camera: Camera3D = actor.get_node("CameraPivot/SpringArm3D/Camera3D")
	actor.set_process(false)
	actor.set_process_unhandled_input(false)
	visual.set_process(false)
	pistol.set_process(false)
	actor.get_node("UI").hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.action_press("aim")
	actor.inventory.add_item("pistol", 1)
	actor.inventory.add_item("pistol_ball", 5)
	visual.equipment.select_weapon(3)
	visual.equipment.stowed = false
	visual.equipment._refresh()
	visual.equipment.aiming = true
	pistol.aiming = true
	actor.aim_camera_distance = 0.55
	actor.get_node("CameraPivot").rotation = Vector3.ZERO
	actor.aim_blend = 1.0
	actor._update_weapon_camera(STEP)
	camera.make_current()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for frame in FRAMES:
		if frame == 15:
			if not pistol.fire():
				push_error("PISTOL REVIEW shot failed")
				quit(1)
				return
		if frame == 32:
			if not pistol.start_reload():
				push_error("PISTOL REVIEW reload failed")
				quit(1)
				return
		pistol._process(STEP)
		visual.equipment.aiming = frame < 32
		visual.equipment.aim_direction = -camera.global_basis.z
		visual._process(STEP)
		await process_frame
		await RenderingServer.frame_post_draw
		if frame in [0, 15, 17, 24, 32, 54, 75, 96, 113]:
			var path := "%s/frame_%03d.png" % [OUTPUT, frame]
			assert(root.get_texture().get_image().save_png(path) == OK)
			print("PISTOL REVIEW FRAME ", path)
	print("PISTOL REVIEW complete, contact=", visual.equipment.held_contact_errors(), " rounds=", pistol.rounds)
	Input.action_release("aim")
	quit()
