extends Node3D
## Timed climb with visible masonry. --capture-sequence renders fixed 30 Hz
## simulation frames; default playback checks contact, pauses and completion.
var actor: CharacterBody3D
var climb: Node
var visual: Node
var camera: Camera3D
var failures := 0
var previous_position := Vector3.ZERO
var previous_step := -1
var previous_phase := 0.0
var sampled_progress := 0.0
var max_wait_travel := 0.0
var max_hold_travel := 0.0
var max_palm_gap := 0.0
var max_sole_gap := 0.0
var max_wrist_angle := 0.0
var collision_disabled := false
var wall_overlaps := 0
var previous_holds: Dictionary = {}
var finished := false
var started := false
var ticks := 0
var reported_steps: Array[int] = []
var capture_sequence := false
var close_camera := false
var hang_seconds := 0.0
var checked_hang := false
var hang_position := Vector3.ZERO
var recorded_frames := 0
var captured_controls := false

func _ready() -> void:
	_run.call_deferred()

func _box(label: String, position_at: Vector3, size: Vector3, color: Color, solid := true) -> Node3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = position_at
	add_child(body)
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	body.add_child(mesh)
	if solid:
		var collision := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		collision.shape = box
		body.add_child(collision)
	return body

func _run() -> void:
	var clock := Node.new()
	clock.name = "GameTimeSystem"
	clock.set_script(load("res://world/suryagarh/systems/game_time_system.gd"))
	add_child(clock)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.22,.28,.32)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(.8,.85,.9)
	environment.environment.ambient_light_energy = .6
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-25,0)
	light.light_energy = 1.5
	light.shadow_enabled = true
	add_child(light)
	_box("Ground",Vector3(0,-.1,0),Vector3(12,.2,10),Color(.31,.34,.26))
	var wall := _box("ClimbWall",Vector3(.7,2.4,0),Vector3(1.4,4.8,5),Color(.45,.25,.16))
	wall.add_to_group("climbable_walls")
	wall.set_meta("top_y",4.8)
	wall.set_meta("climb_center_z",0.0)
	wall.set_meta("climb_hold_base_y",.42)
	wall.set_meta("climb_hold_center_z",0.0)
	_box("Coping",Vector3(.7,4.80,0),Vector3(1.55,.14,5),Color(.61,.60,.47),false)
	for row in 11:
		for col in 4:
			_box("Stone",Vector3(-.08,.42+row*.40,-.72+col*.48+(row%2)*.08),Vector3(.2,.14,.42),Color(.61,.60,.47),false)
	actor = preload("res://player/player.tscn").instantiate()
	add_child(actor)
	actor.set_physics_process(false)
	actor.get_node("UI").hide()
	actor.global_position = Vector3(-.85,.95,0)
	actor.visual_root.global_rotation.y = PI/2
	visual = actor.get_node("VisualRoot/CharacterVisual")
	visual.set_process(false)
	climb = actor.get_node("ClimbComponent")
	camera = Camera3D.new()
	camera.fov = 48.0
	add_child(camera)
	camera.make_current()
	for i in 3: await get_tree().physics_frame
	if not OS.get_cmdline_user_args().has("--review-movie"):
		get_window().mode = Window.MODE_WINDOWED
		DisplayServer.window_set_size(Vector2i(960,540))
	get_viewport().scaling_3d_scale = .65
	_check(not climb.try_start(),"standing jump press cannot start tall ascent")
	wall.set_meta("climb_blocked",true)
	climb.arm_jump()
	actor.global_position.y += .4
	_check(not climb.try_start(),"protected wall rejects jump catch")
	wall.set_meta("climb_blocked",false)
	wall.set_meta("climb_hold_base_y",3.4)
	_check(not climb.try_start(),"first hold above reach rejects catch")
	wall.set_meta("climb_hold_base_y",.42)
	wall.remove_meta("climb_hold_base_y")
	_check(not climb.try_start(),"smooth tall wall rejects catch")
	wall.set_meta("climb_hold_base_y",.42)
	actor.global_position.z = 1.0
	_check(not climb.try_start(),"blank wall beside hold strip rejects catch")
	actor.global_position.z = 0.0
	actor.global_position.x = -1.10
	_check(not climb.try_start(),"wall outside jump catch distance rejects catch")
	actor.global_position = Vector3(-.85,.95,0)
	capture_sequence = OS.get_cmdline_user_args().has("--capture-sequence")
	if capture_sequence:
		climb.set_physics_process(false)
		DirAccess.make_dir_recursive_absolute("/tmp/tlm_step_climb_frames")
	climb.arm_jump()
	# The body follows a real ballistic jump before the wall catch is queried.
	for tick in 15:
		actor.velocity = Vector3(0,-1,0)
		actor.move_and_slide()
		await get_tree().physics_frame
		if actor.is_on_floor(): break
	await get_tree().process_frame
	Input.action_press("jump")
	print("JUMP INPUT floor=",actor.is_on_floor()," pressed=",Input.is_action_just_pressed("jump")," swimming=",actor.is_swimming," y=",actor.global_position.y)
	actor._handle_jump()
	Input.action_release("jump")
	_check(actor.velocity.y == actor.jump_velocity,"jump input produces physical takeoff")
	var jump_delta: float = 1.0/30.0 if capture_sequence else 1.0/60.0
	for tick in 30:
		actor.velocity.y -= actor.gravity*jump_delta
		var jump_destination := actor.global_position+actor.velocity*jump_delta
		# Refresh floor state, then reconcile travel to the render fixture timestep.
		actor.move_and_slide()
		actor.move_and_collide(jump_destination-actor.global_position)
		if capture_sequence:
			climb._physics_process(jump_delta)
			visual._process(jump_delta)
			camera.global_position = actor.global_position+Vector3(-3.5,1.1,3.2)
			camera.look_at(actor.global_position+Vector3.UP*.15)
			await get_tree().process_frame
			RenderingServer.force_draw(false)
			var pixels := get_viewport().get_texture().get_image()
			pixels.resize(960,540)
			pixels.save_png("/tmp/tlm_step_climb_frames/frame_%04d.png"%recorded_frames)
			recorded_frames += 1
		else:
			await get_tree().physics_frame
		if climb.active: break
	if not climb.active:
		push_error("STEP CLIMB: could not start")
		get_tree().quit(1)
		return
	if OS.get_cmdline_user_args().has("--release-check") or OS.get_cmdline_user_args().has("--exhaustion-check"):
		climb.set_physics_process(false)
		for tick in 60: climb._physics_process(1.0/60.0)
		var original_shape: Shape3D = climb.solid.original_shape
		await get_tree().process_frame
		Input.action_press("jump")
		climb._physics_process(1.0/60.0)
		Input.action_release("jump")
		_check(not climb.waiting_for_move and climb.move_limit == .20,"second jump press requests supported pull")
		for tick in 60: climb._physics_process(1.0/60.0)
		var exhausted := OS.get_cmdline_user_args().has("--exhaustion-check")
		if exhausted:
			actor.survival.stamina = 0.0
		else:
			Input.action_press("move_backward")
		climb._physics_process(1.0/60.0)
		Input.action_release("move_backward")
		for tick in 60:
			climb._physics_process(1.0/60.0)
			if not climb.active: break
		_check(not climb.active,"exhaustion releases wall grip" if exhausted else "backward input releases wall grip")
		_check(actor.get_node("CollisionShape3D").shape == original_shape,"release restores full body collision")
		_check(actor.collision_mask == climb.saved_mask,"release keeps wall collision enabled")
		_check(actor.velocity.y < 0.0,"release returns to falling")
		print("JUMP RELEASE ","PASS" if failures == 0 else "FAIL")
		get_tree().quit(1 if failures else 0)
		return
	previous_position = actor.global_position
	started = true
	print("STEP CLIMB START steps=",climb.ascent_steps," duration_s=",climb.duration)
	if OS.get_cmdline_user_args().has("--capture-sequence"):
		capture_sequence = true
		climb.set_physics_process(false)
		visual.set_process(false)
		await _record_sequence()

func _record_sequence() -> void:
	var folder := "/tmp/tlm_step_climb_frames"
	DirAccess.make_dir_recursive_absolute(folder)
	var frame := recorded_frames
	while climb.active and frame < 950:
		_drive_moves(1.0/30.0)
		climb._physics_process(1.0/30.0)
		visual._process(1.0/30.0)
		camera.global_position = actor.global_position+Vector3(-3.5,1.1,3.2)
		camera.look_at(actor.global_position+Vector3.UP*.15)
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		var pixels := get_viewport().get_texture().get_image()
		pixels.resize(960,540)
		pixels.save_png(folder+"/frame_%04d.png"%frame)
		if climb.waiting_for_move and not captured_controls:
			captured_controls = true
			actor.get_node("UI").show()
			await get_tree().process_frame
			await get_tree().process_frame
			RenderingServer.force_draw(false)
			get_viewport().get_texture().get_image().save_png("/tmp/tlm_jump_controls.png")
			actor.get_node("UI").hide()
		if frame in [120,240,360]:
			for side in ["l","r"]:
				var wrist_index: int = visual.skeleton.find_bone("hand_"+side)
				var wrist_rotation: Quaternion = visual.skeleton.get_bone_pose_rotation(wrist_index)
				print("WRIST ",frame," ",side," rest_angle=",wrist_rotation.angle_to(visual.skeleton.get_bone_rest(wrist_index).basis.get_rotation_quaternion()))
				var actual_palm: Vector3 = visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(wrist_index)*visual.equipment.palm_offsets[side])
				print("GRIP ",frame," ",side," gap=",actual_palm.distance_to(visual.climb_targets[side].global_position)," palm=",actual_palm," target=",visual.climb_targets[side].global_position," shoulder=",visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("upperarm_"+side)).origin))
			close_camera = true
			var saved_camera := camera.global_transform
			var saved_fov := camera.fov
			var hand: Transform3D = visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("hand_l"))
			var palm: Vector3 = visual.skeleton.to_global(hand*visual.equipment.palm_offsets["l"])
			camera.fov = 35.0
			camera.global_position = palm+Vector3(-.65,.20,-.75)
			camera.look_at(palm)
			await get_tree().process_frame
			RenderingServer.force_draw(false)
			get_viewport().get_texture().get_image().save_png("/tmp/tlm_climb_grip_%04d.png"%frame)
			camera.global_transform = saved_camera
			camera.fov = saved_fov
			close_camera = false
		frame += 1
		if frame%90 == 0: print("STEP MOVIE frame=",frame," progress=",climb.progress)
	print("STEP MOVIE FRAMES ",frame)
	get_tree().quit(1 if failures else 0)

func _process(delta: float) -> void:
	if not started or finished: return
	# Sample the final pose, after the tree and contact solve for this frame.
	if not capture_sequence:
		_drive_moves(delta)
		visual._process(delta)
	collision_disabled = collision_disabled or actor.collision_mask != climb.saved_mask
	var query := PhysicsShapeQueryParameters3D.new()
	var collider: CollisionShape3D = actor.get_node("CollisionShape3D")
	query.shape = collider.shape
	query.transform = collider.global_transform
	query.exclude = [actor.get_rid()]
	query.collision_mask = actor.collision_mask
	wall_overlaps += actor.get_world_3d().direct_space_state.intersect_shape(query,1).size()
	if not close_camera:
		camera.global_position = actor.global_position+Vector3(-3.5,1.1,3.2)
		camera.look_at(actor.global_position+Vector3.UP*.15)
	ticks += 1
	if climb.progress >= .20 and climb.progress < .78:
		if previous_step == climb.step_index and sampled_progress >= .20:
			if climb.step_phase < .48 and previous_phase < .48:
				max_wait_travel = maxf(max_wait_travel,actor.global_position.distance_to(previous_position))
			if climb.step_phase > .53 and previous_phase > .53:
				for side in ["l","r"]:
					var hold: Vector3 = climb.step_contact(side,false)
					if previous_holds.has(side): max_hold_travel = maxf(max_hold_travel,hold.distance_to(previous_holds[side]))
		if climb.step_phase > .53:
			for side in ["l","r"]:
				var wrist_index: int = visual.skeleton.find_bone("hand_"+side)
				max_wrist_angle = maxf(max_wrist_angle,visual.skeleton.get_bone_pose_rotation(wrist_index).angle_to(visual.skeleton.get_bone_rest(wrist_index).basis.get_rotation_quaternion()))
				var foot_index: int = visual.skeleton.find_bone("foot_"+side)
				var rest: Transform3D = visual.skeleton.get_bone_global_rest(foot_index)
				var sole: Vector3 = visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(foot_index)*(rest.basis.inverse()*Vector3(0,-.085,.06)))
				max_sole_gap = maxf(max_sole_gap,sole.distance_to(visual.climb_foot_targets[side]))
				if sole.distance_to(visual.climb_foot_targets[side]) > .08 and not reported_steps.has(100+climb.step_index):
					reported_steps.append(100+climb.step_index)
					print("BOOT GAP step=",climb.step_index," side=",side," gap=",sole.distance_to(visual.climb_foot_targets[side]))
				var hand: Transform3D = visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("hand_"+side))
				var palm: Vector3 = visual.skeleton.to_global(hand*visual.equipment.palm_offsets[side])
				max_palm_gap = maxf(max_palm_gap,palm.distance_to(visual.climb_targets[side].global_position))
				if palm.distance_to(visual.climb_targets[side].global_position) > .08 and not reported_steps.has(climb.step_index):
					reported_steps.append(climb.step_index)
					print("STEP CONTACT GAP step=",climb.step_index," phase=",climb.step_phase," side=",side," palm=",palm," target=",visual.climb_targets[side].global_position," body=",actor.global_position)
		for side in ["l","r"]: previous_holds[side] = climb.step_contact(side,false)
	previous_position = actor.global_position
	previous_step = climb.step_index
	previous_phase = climb.step_phase
	sampled_progress = climb.progress
	if not climb.active or (not capture_sequence and ticks > 3000):
		finished = true
		_check(not climb.active,"completed and restored movement")
		_check(max_wait_travel < .002,"body waits for hand and boot placement")
		_check(max_hold_travel < .002,"handholds remain fixed during upward push")
		_check(max_palm_gap < .01,"palms retain holds during pushes")
		_check(max_sole_gap < .01,"boot soles retain holds during pushes")
		_check(max_wrist_angle < .701,"wrists stay within bend limit")
		_check(actor.collision_mask == climb.saved_mask,"collision restored")
		_check(not collision_disabled,"world collision stays enabled throughout climb")
		_check(wall_overlaps == 0,"body collision shape never overlaps masonry")
		print("STEP CLIMB ","PASS" if failures == 0 else "FAIL", " wait_travel=",max_wait_travel," hold_travel=",max_hold_travel," max_palm_gap=",max_palm_gap," max_sole_gap=",max_sole_gap," max_wrist_angle=",max_wrist_angle)
		if not capture_sequence: get_tree().quit(1 if failures else 0)

func _check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures += 1

func _drive_moves(delta: float) -> void:
	if not climb.waiting_for_move:
		hang_seconds = 0.0
		hang_position = actor.global_position
		return
	if hang_seconds == 0.0: hang_position = actor.global_position
	hang_seconds += delta
	if not checked_hang and hang_seconds >= .35:
		_check(actor.global_position.distance_to(hang_position)<.002,"catch hangs without automatic ascent")
		var saved_rows: Array = climb.route_missing_rows
		climb.route_missing_rows = [climb.first_hand_row+1]
		_check(not climb.request_move(),"missing next hold blocks advance")
		climb.route_missing_rows = saved_rows
		checked_hang = true
	if hang_seconds >= .40: climb.request_move()
