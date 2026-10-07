extends "res://tools/characters/validate_arjun_step_climb.gd"
## Actual MPFB player, solid geometry, visible layers and real ballistic damage.
var frame_number := 0
var rendered := false
var completed_routes := 0
var airborne_frames := 0
var max_settled_palm := 0.0
var folder := "res://docs/characters/arjun/leap_climb_2026-10-05"

func _run() -> void:
	var time := Node.new()
	time.name = "GameTimeSystem"
	time.set_script(load("res://world/suryagarh/systems/game_time_system.gd"))
	add_child(time)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-25,0)
	light.light_energy = 1.6
	add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.16,.22,.26)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(.7,.75,.8)
	env.environment.ambient_light_energy = .7
	add_child(env)
	_box("Floor",Vector3(0,-.1,10),Vector3(14,.2,80),Color(.3,.32,.25))
	actor = preload("res://player/player.tscn").instantiate()
	add_child(actor)
	actor.set_physics_process(false)
	actor.set_process(false)
	actor.get_node("StairFootContact").set_process(false)
	actor.get_node("UI").hide()
	visual = actor.get_node("VisualRoot/CharacterVisual")
	visual.set_process(false)
	climb = actor.get_node("ClimbComponent")
	climb.set_physics_process(false)
	camera = Camera3D.new()
	camera.fov = 52
	add_child(camera)
	camera.make_current()
	rendered = OS.get_cmdline_user_args().has("--capture") and DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(folder)
	if rendered:
		get_window().mode = Window.MODE_WINDOWED
		DisplayServer.window_set_size(Vector2i(960,540))
		get_viewport().scaling_3d_scale = .55
		DirAccess.make_dir_recursive_absolute("/tmp/tlm_leap_frames")
	for record in [{"height":.75,"z":0.0,"id":"low_wall"},{"height":4.8,"z":8.0,"id":"wall"},{"height":12.8,"z":16.0,"id":"tower"},{"height":8.8,"z":24.0,"id":"building"},{"height":3.2,"z":32.0,"id":"house"},{"height":3.1,"z":40.0,"id":"house_sloped"}]:
		if OS.get_cmdline_user_args().has("--house-only") and not record.id.begins_with("house"): continue
		if OS.get_cmdline_user_args().has("--sloped-only") and record.id != "house_sloped": continue
		if OS.get_cmdline_user_args().has("--lateral-only") and record.id != "building": continue
		var height: float = record.height
		if record.id.begins_with("house"):
			var builder := preload("res://tools/characters/climb_house_fixture.gd").new()
			add_child(builder)
			for field in ["plaster","ochre","brick","wood","tile","stone","iron"]: builder.set(field,builder.material(Color(.52,.41,.29)))
			var house: Node3D = builder.make_building("ClimbOrdinaryHouse",Vector2(4,record.z),Vector2(8,6),false,false,false,true)
			house.position.y = 0
			var detail := preload("res://world/suryagarh/settlements/bhairavpur_house_detail.gd").new()
			var palette: Array[Material] = [builder.ochre]
			detail.configure(builder,palette)
			detail.house(house,Vector2(8,6),0 if record.id == "house_sloped" else 2)
			preload("res://world/suryagarh/settlements/bhairavpur_village.gd").new()._merge_static_geometry(house)
			_check(house.has_meta("climb_architecture"),"merged house retains architectural grips")
		var wall := _box(record.id,Vector3(.7,height*.5,record.z),Vector3(1.4,height,4),Color(.43,.28,.20))
		if record.id.begins_with("house"):
			wall.free()
		elif record.id == "building":
			wall.name = "Building"
			for row in 9:
				_box("ClimbLedge_%d" % row,Vector3(-.06,.9+row*.9,record.z),Vector3(.24,.14,1.2),Color(.58,.57,.46),false)
			_box("RoofCoping",Vector3(.7,height+.04,record.z),Vector3(1.6,.08,4.2),Color(.58,.57,.46))
		elif height > 2.0:
			wall.add_to_group("climbable_walls")
			wall.set_meta("top_y",height)
			wall.set_meta("climb_center_z",record.z)
			wall.set_meta("climb_hold_base_y",.42)
			var rows := floori((height-.42)/.4)+1
			wall.set_meta("climb_hold_rows",rows)
			var missing: Array = []
			for row in rows:
				if row%2 == 1: missing.append(row)
			wall.set_meta("climb_hold_missing_rows",missing)
			for row in range(0,rows,2):
				for col in [1,2]:
					_box("Stone",Vector3(-.08,.42+row*.4,record.z-.72+col*.48+(row%2)*.08),Vector3(.2,.14,.42),Color(.58,.57,.46),false)
		_check(not climb.active,"previous route restores movement")
		await _launch(record.z)
		_check(climb.active,"physical jump catches "+record.id)
		if not climb.active: continue
		var waited := 0.0
		var saved: Vector3 = actor.global_position
		var lateral_checked := false
		for frame in 1800:
			if climb.waiting_for_move:
				if record.id == "building" and not lateral_checked and climb.leap.held_row == climb.layers.size()-1:
					lateral_checked = true
					var side_start: Vector3 = actor.global_position
					Input.action_press("move_right")
					_check(climb.request_move(),"lateral launch uses continuous visible coping")
					Input.action_release("move_right")
					for transfer_frame in 35:
						climb._physics_process(1.0/30.0)
						visual._process(1.0/30.0)
						_sample()
						await _capture("lateral_catch")
					_check(climb.leap.phase == "hang" and actor.global_position.z > side_start.z+.6,"lateral catch settles on coping")
					Input.action_press("move_right")
					_check(climb.request_move(),"second lateral launch follows same continuous edge")
					Input.action_release("move_right")
					for transfer_frame in 35:
						climb._physics_process(1.0/30.0)
						visual._process(1.0/30.0)
						_sample()
						await _capture("lateral_edge_end")
					Input.action_press("move_right")
					_check(not climb.request_move() and climb.leap.phase == "hang","edge end rejects unsupported sideways jump")
					Input.action_release("move_right")
				if waited == 0.0: saved = actor.global_position
				waited += 1.0/30.0
				_check_hang(saved)
				if waited >= .22:
					_check(climb.request_move(),"launch/pull accepted "+record.id)
					waited = 0.0
			else: waited = 0.0
			climb._physics_process(1.0/30.0)
			visual._process(1.0/30.0)
			_sample()
			await _capture(record.id)
			if not climb.active: break
		_check(not climb.active and actor.global_position.y > height+.8,"land on "+record.id)
		if not climb.active:
			completed_routes += 1
			var roof_start: Vector3 = actor.global_position
			for stride in 20:
				actor.velocity = Vector3(0,-.5,-1.0 if record.id == "building" else 1.0)
				actor.move_and_slide()
				await _capture(record.id+"_roof_walk")
			_check(actor.is_on_floor() and absf(actor.global_position.z-roof_start.z) > .1,"solid roof supports walking "+record.id)
			if rendered:
				get_viewport().get_texture().get_image().save_png(folder+"/"+record.id+"_roof_walk.png")
		print("ROUTE ",record.id," root=",actor.global_position)
	if OS.get_cmdline_user_args().has("--house-only") or OS.get_cmdline_user_args().has("--sloped-only") or OS.get_cmdline_user_args().has("--lateral-only"):
		_check(max_settled_palm < .04,"house caught palms reach architectural edges")
		print("HOUSE CLIMB ","PASS" if failures == 0 else "FAIL"," routes=",completed_routes," frames=",frame_number," palm=",max_settled_palm)
		await _finish(1 if failures else 0)
		return
	await _launch(8.0)
	for tick in 20: climb._physics_process(1.0/30.0)
	var health: float = actor.health
	var shooter := Node3D.new()
	shooter.name = "ArmedTestOrigin"
	add_child(shooter) # A test ray origin; no human placeholder geometry.
	var trace := preload("res://combat/ballistic_trace.gd")
	var aim: Vector3 = actor.global_position
	var blocker := _box("SolidCover",Vector3(-2,aim.y,aim.z),Vector3(.2,3,3),Color(.3,.3,.3))
	await get_tree().physics_frame
	trace.shoot(get_world_3d().direct_space_state,get_tree(),aim+Vector3.LEFT*4,aim+Vector3.RIGHT,8,[],shooter)
	_check(actor.health == health and not climb.releasing,"solid cover blocks shot and grip loss")
	blocker.queue_free()
	await get_tree().physics_frame
	trace.shoot(get_world_3d().direct_space_state,get_tree(),aim+Vector3.LEFT*4+Vector3.FORWARD*2,aim+Vector3.RIGHT+Vector3.FORWARD*2,8,[],shooter)
	_check(actor.health == health and not climb.releasing,"miss does not release grip")
	trace.shoot(get_world_3d().direct_space_state,get_tree(),aim+Vector3.LEFT*4,aim+Vector3.RIGHT,8,[],shooter)
	_check(actor.health == health-8 and climb.releasing,"landed firearm hit releases grip")
	for tick in 60:
		climb._physics_process(1.0/30.0)
		if not climb.active:
			actor.velocity.y -= actor.gravity/30.0
			actor.move_and_collide(actor.velocity/30.0)
		visual._process(1.0/30.0)
		await _capture("shot_fall")
	_check(not climb.active and is_equal_approx(actor.get_node("CollisionShape3D").shape.height,1.8),"shot fall restores full body collider")
	await _launch(8.0)
	for tick in 20: climb._physics_process(1.0/30.0)
	var pursuer := preload("res://characters/npcs/thana/thana_officer.gd").new()
	pursuer.name = "ArmedPursuer"
	pursuer.movement_enabled = false
	pursuer.position = Vector3(-4,0,8)
	pursuer.add_child(preload("res://characters/npcs/thana/burkundaz_motion.glb").instantiate())
	add_child(pursuer)
	var firearm := preload("res://combat/climbing_firearm_attack.gd").new()
	firearm.name = "ClimbingFirearm"
	firearm.target = actor
	pursuer.add_child(firearm)
	firearm.set_process(false)
	for tick in 3: await get_tree().physics_frame
	firearm._process(1.0)
	_check(firearm.shots == 0,"non-hostile armed observer does not shoot")
	firearm.hostile = true
	var cover := _box("PursuerCover",Vector3(-2,1.4,8),Vector3(.2,3,3),Color(.35,.35,.3))
	await get_tree().physics_frame
	for tick in 12: firearm._process(.1)
	_check(firearm.shots == 0,"armed pursuer cannot fire through cover")
	cover.queue_free()
	await get_tree().physics_frame
	var before_hit: float = actor.health
	for tick in 12:
		firearm._process(.1)
		visual._process(1.0/30.0)
		await _capture("armed_pursuer")
	_check(firearm.shots == 1 and actor.health == before_hit-18 and climb.releasing,"armed pursuer shoots exposed climber and breaks grip")
	_check(firearm.cartridges == 3 and firearm.cooldown > 0.0,"Enfield consumes cartridge and respects shared reload timing")
	actor.set_meta("climbing",false)
	_check(firearm.can_engage(),"roof and airborne escape remain targetable after releasing grip")
	actor.set_meta("climbing",true)
	for tick in 45:
		climb._physics_process(1.0/30.0)
		if not climb.active:
			actor.velocity.y -= actor.gravity/30.0
			actor.move_and_collide(actor.velocity/30.0)
		visual._process(1.0/30.0)
		await _capture("armed_fall")
	actor.global_position=Vector3(.8,5.74,8)
	for tick in 10:
		actor.velocity=Vector3.DOWN
		actor.move_and_slide()
		await _capture("roof_target")
	_check(actor.is_on_floor() and not climb.active,"roof escape target stands with restored collider")
	firearm.cooldown=0.0
	var roof_health: float=actor.health
	for tick in 12:
		firearm._process(.1)
		visual._process(1.0/30.0)
		await _capture("roof_firearm_hit")
	_check(firearm.shots==2 and actor.health==roof_health-18,"armed pursuer can hit an exposed grounded roof escape target")
	_check(visual.hit_phase>=0.0,"roof hit produces body impact reaction")
	_check(airborne_frames > 0,"leaps release palms and boots in flight")
	_check(max_settled_palm < .04,"caught palms reach visible layers")
	print("LEAP CLIMB ","PASS" if failures == 0 else "FAIL"," routes=",completed_routes," flight_frames=",airborne_frames," settled_palm=",max_settled_palm," frames=",frame_number)
	await _finish(1 if failures else 0)

func _launch(z: float) -> void:
	actor.survival.stamina = 100
	actor.global_position = Vector3(-.75,.94,z)
	actor.visual_root.global_rotation.y = PI/2
	for tick in 15:
		actor.velocity = Vector3.DOWN
		actor.move_and_slide()
		await get_tree().physics_frame
		if actor.is_on_floor(): break
	_check(not climb.try_start(),"grounded entry rejected")
	await get_tree().process_frame
	Input.action_press("jump")
	actor._handle_jump()
	Input.action_release("jump")
	for tick in 30:
		actor.velocity.y -= actor.gravity/30.0
		var destination := actor.global_position+actor.velocity/30.0
		actor.move_and_slide()
		actor.move_and_collide(destination-actor.global_position)
		climb._physics_process(1.0/30.0)
		visual._process(1.0/30.0)
		await _capture("jump")
		if climb.active: break

func _check_hang(at: Vector3) -> void:
	if actor.global_position.distance_to(at) > .002:
		failures += 1
		push_error("Waiting grip moved without launch input")

func _sample() -> void:
	var query := PhysicsShapeQueryParameters3D.new()
	var body: CollisionShape3D = actor.get_node("CollisionShape3D")
	query.shape = body.shape
	query.transform = body.global_transform
	query.exclude = [actor.get_rid()]
	query.collision_mask = actor.collision_mask
	if actor.collision_mask == 0 or not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
		failures += 1
		push_error("Solid climb body overlaps world")
	if climb.leap_active and climb.leap.phase == "flight":
		airborne_frames += 1
		if climb.leap.weight() != 0.0 or climb.leap.weight(true) != 0.0: failures += 1
	if climb.leap_active and climb.leap.phase == "hang":
		for side in ["l","r"]:
			var hand: Transform3D = visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("hand_"+side))
			var palm: Vector3 = visual.skeleton.to_global(hand*visual.equipment.palm_offsets[side])
			var gap: float = palm.distance_to(climb.leap.contact(side,false))
			if OS.get_cmdline_user_args().has("--debug-contact") and gap > .04 and frame_number%5 == 0: print("PALM gap=",gap," root=",actor.global_position," row=",climb.leap.held_row," palm=",palm," target=",climb.leap.contact(side,false)," model=",visual.model.global_position)
			max_settled_palm = maxf(max_settled_palm,gap)

func _capture(label: String) -> void:
	camera.global_position = actor.global_position+Vector3(-3.6,1.0,3.3)
	camera.look_at(actor.global_position+Vector3.UP*.3)
	if rendered:
		await get_tree().process_frame
		RenderingServer.force_draw(false)
		var pixels := get_viewport().get_texture().get_image()
		pixels.resize(960,540)
		pixels.save_png("/tmp/tlm_leap_frames/frame_%04d.png"%frame_number)
		if frame_number%30 == 0: pixels.save_png(folder+"/"+label+".png")
	frame_number += 1
	await get_tree().physics_frame

func _finish(code: int) -> void:
	for node in get_tree().root.get_children(): node.process_mode = Node.PROCESS_MODE_DISABLED
	for type_name in ["AudioStreamPlayer","AudioStreamPlayer3D"]:
		for voice in get_tree().root.find_children("*",type_name,true,false):
			voice.stop()
			voice.stream = null
			voice.queue_free()
	await get_tree().create_timer(.15).timeout
	for tick in 3: await get_tree().physics_frame
	get_tree().quit(code)
