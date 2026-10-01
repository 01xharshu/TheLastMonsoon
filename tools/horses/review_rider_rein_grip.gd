extends SceneTree
## Actual input-driven rider: seated geometry, jump response and native motion.
var horse: CharacterBody3D
var actor: CharacterBody3D
var camera: Camera3D
var samples: Array[Dictionary] = []
var frame_number := 0
var capture_frames := false

func _initialize() -> void: _run.call_deferred()

func _sample(stage: String) -> void:
	var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
	var skeleton: Skeleton3D = visual.skeleton
	var pelvis := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("pelvis")).origin)
	var chest := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("head")).origin)
	var torso := chest-pelvis
	var lean := rad_to_deg(atan2(torso.dot(-horse.global_basis.z),torso.dot(Vector3.UP)))
	var knees: Array[float] = []
	var sole_error := 0.0
	var palm_error := 0.0
	for side in ["l","r"]:
		var hip := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("thigh_"+side)).origin)
		var knee := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("calf_"+side)).origin)
		var ankle_pose := skeleton.get_bone_global_pose(skeleton.find_bone("foot_"+side))
		var ankle := skeleton.to_global(ankle_pose.origin)
		knees.append(rad_to_deg(acos(clampf((hip-knee).normalized().dot((ankle-knee).normalized()),-1.0,1.0))))
		var rest := skeleton.get_bone_global_rest(skeleton.find_bone("foot_"+side))
		var sole_local := rest.basis.inverse()*Vector3(0,-0.085,0.06)
		sole_error = maxf(sole_error,skeleton.to_global(ankle_pose*sole_local).distance_to(horse.stirrup_world(side)))
		var hand := skeleton.get_bone_global_pose(skeleton.find_bone("hand_"+side))
		palm_error = maxf(palm_error,skeleton.to_global(hand*visual.equipment.palm_offsets[side]).distance_to(horse.riding_rein_world(side)))
	samples.append({"physics_tick":Engine.get_physics_frames(),"stage":stage,"knees_deg":knees,"forward_lean_deg":lean,"seat_error_m":pelvis.distance_to(horse.seat_world()),"sole_error_m":sole_error,"palm_error_m":palm_error,"airborne":not horse.is_on_floor(),"vertical_velocity":horse.velocity.y})

func _stage(label: String, frames: int) -> void:
	for index in frames:
		for tick in 4: await physics_frame
		var grip: Vector3 = (horse.riding_rein_world("l")+horse.riding_rein_world("r"))*.5
		camera.global_position = grip+horse.global_basis*Vector3(.72,.32,-.35)
		camera.look_at(grip)
		if capture_frames:
			await process_frame
			RenderingServer.force_draw(false)
			if index == 2:
				assert(root.get_texture().get_image().save_png("res://docs/world/captures/rein_grip_"+label+".png")==OK)
		else:
			await process_frame
		_sample(label)
		frame_number += 1

func _run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	capture_frames = DisplayServer.get_name() != "headless"
	if capture_frames:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		DirAccess.make_dir_recursive_absolute("/tmp/tlm_rider_motion")
	var world := Node3D.new()
	root.add_child(world)
	var clock := Node.new()
	clock.name = "GameTimeSystem"
	clock.set_script(load("res://world/suryagarh/systems/game_time_system.gd"))
	world.add_child(clock)
	var floor_ := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(250,0.2,250)
	collision.shape = box
	floor_.add_child(collision)
	var mesh := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = box.size
	mesh.mesh = floor_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.23,0.28,0.19)
	mesh.material_override = material
	floor_.add_child(mesh)
	world.add_child(floor_)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45,-35,0)
	light.shadow_enabled = true
	world.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.34,0.40,0.45)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.8,0.85,0.9)
	environment.environment.ambient_light_energy = 0.5
	world.add_child(environment)
	horse = load("res://horses/stable_horse.gd").new()
	world.add_child(horse)
	actor = load("res://player/player.tscn").instantiate()
	actor.position = Vector3(1.2,1,0)
	world.add_child(actor)
	actor.get_node("UI").hide()
	camera = Camera3D.new()
	camera.fov = 48
	world.add_child(camera)
	camera.make_current()
	await create_timer(0.3).timeout
	assert(horse.board(actor))
	await create_timer(1.2).timeout
	await _stage("seated",12)
	Input.action_press("move_forward")
	await _stage("walk",30)
	Input.action_press("sprint")
	await _stage("gallop",30)
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	await _stage("jump",18)
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await _stage("recovery",12)
	var max_knee := 0.0
	var seat_error := 0.0
	var sole_error := 0.0
	var palm_error := 0.0
	var seated_lean := 0.0
	var jump_lean := -100.0
	var gallop_lean := -100.0
	for sample in samples:
		for knee in sample.knees_deg: max_knee = maxf(max_knee,knee)
		seat_error = maxf(seat_error,sample.seat_error_m)
		sole_error = maxf(sole_error,sample.sole_error_m)
		palm_error = maxf(palm_error,sample.palm_error_m)
		if sample.stage == "seated": seated_lean = sample.forward_lean_deg
		if sample.stage == "gallop": gallop_lean = maxf(gallop_lean,sample.forward_lean_deg)
		if sample.stage == "jump" and sample.airborne: jump_lean = maxf(jump_lean,sample.forward_lean_deg)
	var checks := {"bent_knees":max_knee<150.0,"seat_follows_back":seat_error<0.04,"stirrups":sole_error<0.04,"rein_grip":palm_error<0.08,"gallop_forward_response":gallop_lean>seated_lean+5.0,"jump_forward_response":jump_lean>gallop_lean+5.0,"landed":horse.landing_events>0}
	var passed := true
	for value in checks.values(): passed = passed and value
	var suffix := "metal" if capture_frames else "headless"
	var report := {"status":"PASS" if passed else "FAIL","checks":checks,"max_knee_deg":max_knee,"max_seat_error_m":seat_error,"max_sole_error_m":sole_error,"max_palm_error_m":palm_error,"seated_lean_deg":seated_lean,"gallop_lean_deg":gallop_lean,"jump_lean_deg":jump_lean,"samples":samples,"physics_hz":60,"recorded_fps":15}
	FileAccess.open("res://docs/world/rein_grip_motion_"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("RIDER SEATED MOTION ",report.status," ",checks)
	world.queue_free()
	await process_frame
	quit(0 if passed else 1)
