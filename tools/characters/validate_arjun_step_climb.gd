extends Node3D
## Real timed climb with visible masonry. Records normal-speed movie frames
## when launched with Godot --write-movie; headless checks contact and pauses.
var actor: CharacterBody3D
var climb: Node
var visual: Node
var camera: Camera3D
var failures := 0
var previous_position := Vector3.ZERO
var previous_step := -1
var previous_phase := 0.0
var max_wait_travel := 0.0
var max_hold_travel := 0.0
var max_palm_gap := 0.0
var previous_holds: Dictionary = {}
var finished := false
var started := false
var ticks := 0
var reported_steps: Array[int] = []
var capture_sequence := false

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
	for row in 8:
		for col in 4:
			_box("Stone",Vector3(-.08,.42+row*.55,-.72+col*.48+(row%2)*.08),Vector3(.2,.14,.42),Color(.61,.60,.47),false)
	actor = preload("res://player/player.tscn").instantiate()
	add_child(actor)
	actor.set_physics_process(false)
	actor.get_node("UI").hide()
	actor.global_position = Vector3(-.85,.95,0)
	actor.visual_root.global_rotation.y = PI/2
	visual = actor.get_node("VisualRoot/CharacterVisual")
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
	if not climb.try_start():
		push_error("STEP CLIMB: could not start")
		get_tree().quit(1)
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
	var frame := 0
	while climb.active and frame < 600:
		climb._physics_process(1.0/30.0)
		visual._process(1.0/30.0)
		camera.global_position = actor.global_position+Vector3(-3.5,1.1,3.2)
		camera.look_at(actor.global_position+Vector3.UP*.15)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var pixels := get_viewport().get_texture().get_image()
		pixels.resize(960,540)
		pixels.save_png(folder+"/frame_%04d.png"%frame)
		frame += 1
		if frame%90 == 0: print("STEP MOVIE frame=",frame," progress=",climb.progress)
	print("STEP MOVIE FRAMES ",frame)
	get_tree().quit(1 if failures else 0)

func _process(_delta: float) -> void:
	if not started or finished: return
	camera.global_position = actor.global_position+Vector3(-3.5,1.1,3.2)
	camera.look_at(actor.global_position+Vector3.UP*.15)
	ticks += 1
	if climb.progress >= .14 and climb.progress < .78:
		if previous_step == climb.step_index:
			if climb.step_phase < .48 and previous_phase < .48:
				max_wait_travel = maxf(max_wait_travel,actor.global_position.distance_to(previous_position))
			if climb.step_phase > .53 and previous_phase > .53:
				for side in ["l","r"]:
					var hold: Vector3 = climb.step_contact(side,false)
					if previous_holds.has(side): max_hold_travel = maxf(max_hold_travel,hold.distance_to(previous_holds[side]))
		if climb.step_phase > .53:
			for side in ["l","r"]:
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
	if not climb.active or ticks > 3000:
		finished = true
		_check(not climb.active,"completed and restored movement")
		_check(max_wait_travel < .002,"body waits for hand and boot placement")
		_check(max_hold_travel < .002,"handholds remain fixed during upward push")
		_check(max_palm_gap < .08,"palms retain holds during pushes")
		_check(actor.collision_mask == climb.saved_mask,"collision restored")
		print("STEP CLIMB ","PASS" if failures == 0 else "FAIL", " wait_travel=",max_wait_travel," hold_travel=",max_hold_travel," max_palm_gap=",max_palm_gap)
		if not capture_sequence: get_tree().quit(1 if failures else 0)

func _check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures += 1
