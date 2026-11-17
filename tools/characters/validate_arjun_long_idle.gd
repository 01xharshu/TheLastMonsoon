extends SceneTree
## Actual player/floor regression. No generated files or saved-game changes.
class CaseObserver extends Node:
	var pending := false
	var suspect: Node
	func has_pending_police_case(candidate: Node) -> bool: return pending and candidate == suspect
var failures := 0
var review_dir := OS.get_environment("TLM_TEST_OUTPUT_DIR")
var review_camera: Camera3D
func _initialize() -> void: _run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	if OS.get_environment("TLM_IDLE_REVIEW_SCALE") != "":
		root.scaling_3d_scale = clampf(float(OS.get_environment("TLM_IDLE_REVIEW_SCALE")),.25,1.0)
	var stage := Node3D.new()
	root.add_child(stage)
	var game_clock := Node.new()
	game_clock.name = "GameTimeSystem"
	game_clock.set_script(load("res://world/suryagarh/systems/game_time_system.gd"))
	stage.add_child(game_clock)
	var floor_body := StaticBody3D.new()
	stage.add_child(floor_body)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(12,.4,12)
	collision.shape = box
	collision.position.y = -.2
	floor_body.add_child(collision)
	var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
	stage.add_child(actor)
	actor.position.y = 1.0
	if not review_dir.is_empty():
		actor.get_node("UI").hide()
		var camera := Camera3D.new()
		stage.add_child(camera)
		camera.position = Vector3(2.1,1.2,3.0)
		camera.look_at(Vector3(0,.8,0))
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 2.5
		review_camera = camera
		camera.current = true
		var light := DirectionalLight3D.new()
		stage.add_child(light)
		light.rotation_degrees = Vector3(-45,-30,0)
		light.light_energy = 1.4
		var mesh := MeshInstance3D.new()
		mesh.mesh = PlaneMesh.new()
		mesh.mesh.size = Vector2(12,12)
		stage.add_child(mesh)

	for i in 90: await physics_frame
	var idle: Node = actor.get_node("LongIdle")
	idle.set_process_input(false)
	var visual: Node = actor.get_node("VisualRoot/CharacterVisual")
	preload("res://player/arjun_complete_fit.gd").new().apply(visual)
	check(idle.eligible(),"Idle eligibility on supported unarmed standing player")
	check(idle.safe_ground(),"Flat clear ground supports sitting")
	await capture("neutral")
	idle.idle_ui.set_process_input(false)
	var joint_audit := preload("res://tools/characters/arjun_idle_joint_audit.gd").new()
	var standing_camera: float = actor.get_node("CameraPivot").position.y
	var origin := actor.global_position
	var ground_only := OS.get_environment("TLM_IDLE_GROUND_ONLY") == "1"
	var scratch_only := OS.get_environment("TLM_IDLE_SCRATCH_ONLY") == "1"
	for beat in [{"time":idle.look_after,"name":"look"},{"time":idle.scratch_after,"name":"scratch"},{"time":idle.clothes_after,"name":"clothes"},{"time":idle.stretch_after,"name":"stretch"}]:
		if ground_only or (scratch_only and beat.name != "scratch"): continue
		joint_audit.phase = beat.name
		idle.cancel(true)
		idle.elapsed = beat.time-.02
		for i in 4: await physics_frame
		check(idle.action == beat.name,"Timed action: "+beat.name)
		var head: int = visual.skeleton.find_bone("head")
		var before: Quaternion = visual.skeleton.get_bone_pose_rotation(head)
		for i in 100:
			await physics_frame
			joint_audit.sample(visual,idle)
		check(before.angle_to(visual.skeleton.get_bone_pose_rotation(head)) > .02,"Action changes actual head: "+beat.name)
		await capture(beat.name)
		var event := InputEventMouseMotion.new()
		event.relative = Vector2(4,0)
		idle._input(event)
		check(idle.action == "" and idle.elapsed == 0.0,"Mouse cancels standing beat")
		joint_audit.phase = beat.name+" cancel"
		for i in 20:
			await physics_frame
			joint_audit.sample(visual,idle)
	if scratch_only:
		print("SCRATCH JOINT AUDIT: "+joint_audit.describe())
		check(joint_audit.wrist_angle < .65 and joint_audit.elbow_flex < 2.85,"Scratch joint limits")
		check(joint_audit.hand_gap > .10 and joint_audit.elbow_gap > .18,"Scratch does not cross torso")
		check(joint_audit.pose_step < .35,"Scratch reach/cancel has no snap")
		print("ARJUN SCRATCH: %s" % ("PASS" if failures == 0 else "FAIL"))
		preload("res://tools/test_audio_cleanup.gd").finish(self,0 if failures == 0 else 1)
		return
	# Let each full beat finish naturally as well as interrupting it above.
	for beat in [{"time":idle.look_after,"name":"look"},{"time":idle.scratch_after,"name":"scratch"},{"time":idle.clothes_after,"name":"clothes"},{"time":idle.stretch_after,"name":"stretch"}]:
		if ground_only: continue
		joint_audit.phase = beat.name+" full cycle"
		idle.cancel(true)
		idle.elapsed = beat.time-.02
		for i in 335:
			await physics_frame
			joint_audit.sample(visual,idle)
		check(idle.action == "","Full idle beat returns to neutral: "+beat.name)
	idle.cancel(true)
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 120
	stage.add_child(ui_layer)
	var pulse_label := Label.new()
	pulse_label.text = "UI fade fixture"
	pulse_label.position = Vector2(20,20)
	pulse_label.modulate = Color(.7,.8,.9,.6)
	ui_layer.add_child(pulse_label)
	var button := Button.new()
	button.text = "Restore UI"
	button.position = Vector2(20,50)
	button.size = Vector2(160,40)
	ui_layer.add_child(button)
	var clicks := {"count":0}
	button.pressed.connect(func(): clicks.count += 1)
	idle.elapsed = idle.look_after+.01
	await create_timer(idle.ui_fade_seconds+.15).timeout
	check(idle.idle_ui.opacity < .01 and idle.idle_ui.layers.has(ui_layer),"Idle fades gameplay canvases")
	check(button.visible and not button.disabled and pulse_label.modulate == Color(.7,.8,.9,.6),"Fade preserves button state and local tutorial/pulse alpha")
	idle.idle_ui.set_process_input(true)
	var tiny_mouse := InputEventMouseMotion.new()
	tiny_mouse.relative = Vector2(.1,0)
	root.push_input(tiny_mouse)
	check(idle.idle_ui.opacity == 1 and idle.elapsed == 0,"Any mouse motion restores UI immediately")
	idle.elapsed = idle.look_after+.01
	await create_timer(idle.ui_fade_seconds+.15).timeout
	var press_key := InputEventKey.new()
	press_key.pressed = true
	press_key.physical_keycode = KEY_F10
	root.push_input(press_key)
	check(idle.idle_ui.opacity == 1 and idle.elapsed == 0,"Unbound keyboard press immediately restores UI")
	var key_release := press_key.duplicate() as InputEventKey
	key_release.pressed = false
	root.push_input(key_release)
	idle.elapsed = idle.look_after+.01
	await create_timer(idle.ui_fade_seconds+.15).timeout
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = button.get_global_transform_with_canvas()*(button.size*.5)
	click.pressed = true
	root.push_input(click,true)
	var click_release := click.duplicate() as InputEventMouseButton
	click_release.pressed = false
	root.push_input(click_release,true)
	check(idle.idle_ui.opacity == 1 and clicks.count == 1,"First mouse click restores UI and still activates its button")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	idle.idle_ui.set_process_input(false)
	ui_layer.queue_free()
	await process_frame
	idle.cancel(true)
	idle.elapsed = idle.sit_after
	joint_audit.phase = "ground entry"
	joint_audit.last.clear()
	var milestones := {"entry_quarter":.25,"entry_squat":.45,"entry_transfer":.65,"entry_settle":.85}
	for i in 480:
		await physics_frame
		joint_audit.sample(visual,idle)
		for label in milestones.keys():
			if idle.seat >= milestones[label]:
				await capture(label)
				milestones.erase(label)
		if idle.seat >= 1.0: break
	check(idle.action == "sit" and idle.seat > .99,"Long idle sits fully")
	check(actor.get_node("CameraPivot").position.y < standing_camera-.5,"Third-person camera follows the seated body")
	var sight_y: float = actor.get_node("StealthStance").sight_target().y-idle.floor_world.y
	check(sight_y > .6 and sight_y < 1.1,"Perception target follows seated head height")
	actor.set_first_person(true)
	for i in 2: await process_frame
	check(actor.get_node("CameraPivot").global_position.y > idle.floor_world.y+.4 and actor.get_node("CameraPivot").global_position.y < idle.floor_world.y+1.15,"First-person view follows sitting above the floor")
	actor.set_first_person(false)
	var permissions: Node = actor.get_node("ActionPermissions")
	check(not permissions.domain_free(&"attack") and not permissions.domain_free(&"board"),"Ground idle owns attack/boarding until standing")
	check(not actor.get_node("CombatInput").available(),"Seated combat cannot replace idle pose")
	check(not actor.get_node("StealthStance").can_change(),"Seated stance cannot replace idle pose")
	idle.set_process_input(true)
	var stow := InputEventAction.new()
	stow.action = "stow_weapon"
	stow.pressed = true
	root.push_input(stow)
	await process_frame
	check(idle.rising and visual.equipment.stowed,"Real equipment input requests rise without drawing")
	var release := stow.duplicate() as InputEventAction
	release.pressed = false
	root.push_input(release)
	idle.set_process_input(false)

	check(actor.global_position.distance_to(origin) < .02,"Sitting preserves gameplay root")
	var pelvis: Vector3 = visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("pelvis")).origin)
	check(absf(pelvis.y-.16)<.06,"Ground seat pelvis contact")
	for side in ["l","r"]:
		var foot: int = visual.skeleton.find_bone("foot_"+side)
		var rest: Transform3D = visual.skeleton.get_bone_global_rest(foot)
		var sole: Vector3 = visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(foot)*(rest.basis.inverse()*Vector3(0,-.085,.06)))
		check(absf(sole.y-.015)<.06,"Ground seat boot support "+side)
	check(float(visual.motion_tree.get("parameters/sleep/blend_amount")) == 0.0,"Ground seat excludes lying/sleeping")
	await capture("sit")
	joint_audit.phase = "ground rise"
	Input.action_press("move_backward")
	milestones = {"rise_retract":.82,"rise_squat":.60,"rise_lift":.36,"rise_stand":.10}
	for i in 480:
		await physics_frame
		joint_audit.sample(visual,idle)
		for label in milestones.keys():
			if idle.seat <= milestones[label]:
				await capture(label)
				milestones.erase(label)
		if idle.seat <= 0.0: break
	for i in 30:
		await physics_frame
		joint_audit.sample(visual,idle)
	Input.action_release("move_backward")
	check(idle.seat == 0.0 and idle.action == "","Held movement completes stand recovery")
	check(permissions.domain_free(&"attack") and permissions.domain_free(&"board") and idle.lease < 0,"Rise releases actor action ownership")
	check(actor.global_position.distance_to(origin) > .2,"Movement resumes after rising")
	idle.cancel(true)
	actor.set_meta("map_open",true)
	idle.elapsed = idle.sit_after
	await physics_frame
	check(idle.elapsed == 0.0 and idle.action == "","Map blocks idle")
	actor.remove_meta("map_open")
	actor.set_meta("story_cinematic",true)
	check(not idle.eligible(),"Story cinematic blocks idle")
	actor.remove_meta("story_cinematic")
	visual.equipment.stowed = false
	check(not idle.eligible(),"Drawn weapon blocks idle")
	visual.equipment.stowed = true
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	idle.elapsed = 20.0
	idle._input(touch)
	check(idle.elapsed == 0.0,"Touch resets inactivity")
	var stick := InputEventJoypadMotion.new()
	stick.axis_value = .6
	idle.elapsed = 20.0
	idle._input(stick)
	check(idle.elapsed == 0.0,"Gamepad activity resets inactivity")
	idle.cancel(true)
	actor.position = Vector3(0,.9,0)
	actor.velocity = Vector3.ZERO
	for i in 10: await physics_frame
	idle.elapsed = idle.sit_after
	for i in 8: await physics_frame
	check(idle.lease >= 0,"Second seat reacquires permissions")
	actor.set_meta("story_cinematic",true)
	for i in 2: await physics_frame
	check(idle.seat == 0 and idle.lease < 0 and permissions.domain_free(&"attack"),"Story takeover clears idle pose and leases")
	actor.remove_meta("story_cinematic")
	idle.elapsed = idle.sit_after
	for i in 8: await physics_frame
	check(idle.lease >= 0,"Seat before teleport owns actions")
	actor.position.x += .5
	for i in 2: await physics_frame
	check(idle.seat == 0 and idle.lease < 0,"External position restore cancels transient sitting")
	actor.position = Vector3(0,.9,0)
	actor.velocity = Vector3.ZERO
	for i in 10: await physics_frame
	var case_observer := CaseObserver.new()
	case_observer.suspect = actor
	case_observer.add_to_group("police_crime_observers")
	stage.add_child(case_observer)
	idle.elapsed = idle.sit_after
	for i in 8: await physics_frame
	case_observer.pending = true
	idle.observer_clock = 2.0
	for i in 2: await physics_frame
	check(idle.rising and idle.seat > 0 and idle.lease >= 0,"New police case requests natural rise while keeping pose ownership")
	for i in 90:
		await process_frame
		if idle.seat == 0: break
	check(idle.seat == 0 and idle.lease < 0 and not idle.eligible(),"Standing releases leases but pending case still inhibits idle")
	case_observer.pending = false
	check(idle.eligible(),"Resolved case restores idle eligibility")
	case_observer.queue_free()
	await physics_frame
	var obstacle := StaticBody3D.new()
	stage.add_child(obstacle)
	var obstacle_shape := CollisionShape3D.new()
	var obstruction := BoxShape3D.new()
	obstruction.size = Vector3(.2,.6,.2)
	obstacle_shape.shape = obstruction
	obstacle.add_child(obstacle_shape)
	obstacle.position = Vector3(.45,.3,0)
	for i in 3: await physics_frame
	check(not idle.safe_ground(),"Nearby obstacle rejects seat")
	obstacle.queue_free()
	await physics_frame
	# A small floor must fail the footprint check even if its center supports us.
	box.size = Vector3(.4,.4,.4)
	actor.position = Vector3(0,.9,0)
	for i in 3: await physics_frame
	check(not idle.safe_ground(),"Unsupported ledge rejects seat")
	print("ARJUN IDLE JOINT AUDIT: "+joint_audit.describe())
	check(joint_audit.knee_gap > .08,"Knees must not cross")
	check(joint_audit.hand_gap > .10,"Hands must not cross")
	check(joint_audit.elbow_gap > .18,"Elbows stay outside and separated")
	check(joint_audit.wrist_angle < .65,"Wrist bend/twist bounded")
	check(joint_audit.knee_flex < 2.95 and joint_audit.elbow_flex < 2.85,"Joint flexion remains anatomical")
	check(joint_audit.min_sole > -.035,"Visible boot sole stays out of ground")
	check(joint_audit.planted_drift < .035,"Squat/rise feet stay planted")
	check(joint_audit.pose_step < .35,"No single-frame limb snap")
	print("ARJUN LONG IDLE: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL",failures])
	preload("res://tools/test_audio_cleanup.gd").finish(self,0 if failures == 0 else 1)

func capture(label: String) -> void:
	if review_dir.is_empty(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(review_dir.path_join(label+".png"))
	if not label in ["entry_squat","sit","rise_squat"]: return
	var original := review_camera.transform
	for view in [{"name":"side","point":Vector3(3,1.1,0)},{"name":"rear","point":Vector3(-1.8,1.1,-3)}]:
		review_camera.position = view.point
		review_camera.look_at(Vector3(0,.75,0))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(review_dir.path_join(label+"_"+view.name+".png"))
	review_camera.transform = original
