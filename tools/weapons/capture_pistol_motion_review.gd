extends SceneTree
## Isolated native player-camera sequence. Run without --headless.
var output := OS.get_environment("TLM_PISTOL_REVIEW_OUTPUT")
const STEP := 1.0 / 30.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("PISTOL REVIEW requires the native renderer")
		quit(1)
		return
	if output.is_empty():
		push_error("Set TLM_PISTOL_REVIEW_OUTPUT to an OS temporary directory; remove it after review")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	Engine.max_fps = 30
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
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = Vector2i(640,360)
	create_timer(120.0).timeout.connect(func():
		push_error("PISTOL REVIEW timed out")
		quit(1))
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
	for warmup in 20:
		Input.action_press("aim")
		pistol._process(STEP)
		visual._process(STEP)
		await process_frame
	print("PISTOL REVIEW warmup complete")
	var charges := clampi(int(OS.get_environment("TLM_PISTOL_REVIEW_CHARGES")),1,5)
	var frames := 32+int(ceil(preload("res://player/pistol_loading_sequence.gd").duration(charges)/STEP))+16
	var review_camera: Camera3D
	if OS.get_environment("TLM_PISTOL_REVIEW_SIDE") == "1":
		review_camera = Camera3D.new()
		stage.add_child(review_camera)
		review_camera.fov = 38.0
		review_camera.make_current()
	DirAccess.make_dir_recursive_absolute(output)
	var playback_start := Time.get_ticks_msec()
	for frame in frames:
		Input.action_press("aim")
		if frame == 15:
			if not pistol.fire():
				push_error("PISTOL REVIEW shot failed")
				quit(1)
				return
		if frame == 32:
			pistol.rounds = 5-charges
			if not pistol.start_reload():
				push_error("PISTOL REVIEW reload failed")
				quit(1)
				return
		pistol._process(STEP)
		visual.equipment.aiming = pistol.aiming
		actor._update_weapon_camera(STEP)
		visual.equipment.aim_direction = -camera.global_basis.z
		visual._process(STEP)
		if review_camera != null:
			review_camera.global_position = visual.equipment.pistol_hand.to_global(Vector3(0.0,0.10,0.70))
			review_camera.look_at(visual.equipment.pistol_hand.to_global(Vector3(-0.08,0.02,0.0)))
		await process_frame
		if frame in [0, 15, 17, 24, 32, 54, 75, 96, 113, 146, 159] or frame == frames-1:
			RenderingServer.force_draw(false)
			var path := "%s/frame_%03d.png" % [output, frame]
			var frame_image := root.get_texture().get_image()
			frame_image.resize(1280,720)
			assert(frame_image.save_png(path) == OK)
			print("PISTOL REVIEW FRAME ", path)
	print("PISTOL REVIEW complete, contact=", visual.equipment.held_contact_errors(), " rounds=", pistol.rounds," simulated_seconds=",frames*STEP," elapsed_seconds=",float(Time.get_ticks_msec()-playback_start)/1000.0)
	Input.action_release("aim")
	quit()
