extends SceneTree
## One jump input at an open window must commit the entire crossing.

func _initialize() -> void:
	_run.call_deferred()

func _box(parent: Node3D, at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	return body

func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var clock := GameTimeSystem.new()
	clock.name = "GameTimeSystem"
	scene.add_child(clock)
	var floor_body := _box(scene,Vector3(0,-.1,0),Vector3(8,.2,8))
	_box(scene,Vector3(0,.67,0),Vector3(.38,1.34,4))
	_box(scene,Vector3(0,3,0),Vector3(.38,1.02,4))
	for side in [-1.0,1.0]:
		_box(scene,Vector3(0,1.915,side*1.55),Vector3(.38,1.15,.9))
	var portal := Node3D.new()
	portal.position = Vector3(0,1.34,0)
	portal.add_to_group("climbable_windows")
	scene.add_child(portal)
	var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
	scene.add_child(actor)
	actor.set_meta("mounted_vehicle", null)
	actor.get_node("UI").hide()
	await _cross(actor,-.9,PI/2,true)
	await _cross(actor,.9,-PI/2,false)
	var shutter := _box(scene,Vector3(0,1.9,0),Vector3(.15,1.15,2.2))
	for side in [-1.0,1.0]:
		actor.global_position = Vector3(side*.9,.94,0)
		actor.visual_root.global_rotation.y = PI/2 if side < 0.0 else -PI/2
		await physics_frame
		assert(not actor.get_node("ClimbComponent").window.try_start(actor), "Closed shutter admitted window crossing")
	shutter.queue_free()
	await physics_frame
	for side in [-1.0,1.0]:
		var landing_blocker := _box(scene,Vector3(-side*.95,.9,0),Vector3(.9,1.8,.9))
		actor.global_position = Vector3(side*.9,.94,0)
		actor.visual_root.global_rotation.y = PI/2 if side < 0.0 else -PI/2
		await physics_frame
		assert(not actor.get_node("ClimbComponent").window.try_start(actor), "Blocked landing admitted window crossing")
		landing_blocker.queue_free()
		await physics_frame
	for side in [-1.0,1.0]:
		for standing_only in [false,true]: await _blocked_during_crossing(scene,actor,side,standing_only)
		for phase in [.25,.72]: await _release_during_crossing(actor,side,phase)
	floor_body.queue_free()
	await physics_frame
	for side in [-1.0,1.0]:
		actor.set_physics_process(false)
		actor.global_position = Vector3(side*.9,.94,0)
		actor.visual_root.global_rotation.y = PI/2 if side < 0.0 else -PI/2
		assert(not actor.get_node("ClimbComponent").window.try_start(actor), "Unsupported landing admitted window crossing")
	print("WINDOW SINGLE PRESS: PASS | both directions; closed/blocked/unsupported landings rejected; moving obstruction returns safely; grip release exits the current side")
	scene.queue_free()
	for frame in 3: await physics_frame
	quit()

func _blocked_during_crossing(scene: Node3D, actor: CharacterBody3D, side: float, standing_only: bool) -> void:
	actor.set_physics_process(false)
	actor.global_position = Vector3(side*.9,.94,0)
	actor.visual_root.global_rotation.y = PI/2 if side < 0.0 else -PI/2
	var window = actor.get_node("ClimbComponent").window
	var original_shape: Shape3D = actor.get_node("CollisionShape3D").shape
	assert(window.try_start(actor))
	for frame in 65: window.advance(actor,1.0/30.0)
	var blocker := _box(scene,Vector3(-side*1.31,1.0,0),Vector3(.1,2.0,.8)) if standing_only else _box(scene,Vector3(-side*.95,1.0,0),Vector3(.5,2.0,.8))
	await physics_frame
	for frame in 280:
		window.advance(actor,1.0/30.0)
		if not window.active: break
	assert(not window.active and actor.global_position.x*side > .8, "Moving landing obstruction left Arjun trapped")
	assert(actor.get_node("CollisionShape3D").shape == original_shape and not actor.get_meta("climbing",false), "Abort did not restore standing collision")
	blocker.queue_free()
	await physics_frame
	actor.set_physics_process(true)
	await _cross(actor,side*.9,PI/2 if side < 0.0 else -PI/2,side < 0.0)

func _release_during_crossing(actor: CharacterBody3D, side: float, phase: float) -> void:
	actor.set_physics_process(false)
	actor.global_position = Vector3(side*.9,.94,0)
	actor.visual_root.global_rotation.y = PI/2 if side < 0.0 else -PI/2
	var climb = actor.get_node("ClimbComponent")
	var original_shape: Shape3D = actor.get_node("CollisionShape3D").shape
	var visual: Node = actor.get_node("VisualRoot/CharacterVisual")
	var tunic := visual.model.find_child("Arjun_Kurta_SplitHem",true,false) as MeshInstance3D
	var original_tunic: Mesh = tunic.mesh
	assert(climb.window.try_start(actor))
	climb.active = true
	climb.set_physics_process(false)
	for frame in roundi(phase*96): climb.window.advance(actor,1.0/30.0)
	visual._process(1.0/30.0)
	assert(tunic.mesh != original_tunic,"Crossing did not apply tunic hip ease")
	var current_side := signf(actor.global_position.x)
	climb.release_grip()
	assert(tunic.mesh == original_tunic,"Released grip retained climbing garment")
	assert(climb.release_velocity.x*current_side > 0.0,"Released grip pushed Arjun toward the window wall")
	for frame in 90:
		climb._physics_process(1.0/60.0)
		if not climb.active: break
	assert(not climb.active and actor.get_node("CollisionShape3D").shape == original_shape and not actor.get_meta("climbing",false),"Grip release did not restore standing collision")
	climb.releasing = false
	climb.set_physics_process(true)
	actor.set_physics_process(true)

func _cross(actor: CharacterBody3D, start_x: float, facing: float, to_positive: bool) -> void:
	actor.global_position = Vector3(start_x,.94,0)
	actor.velocity = Vector3.ZERO
	actor.visual_root.global_rotation.y = facing
	for frame in 8: await physics_frame
	var press := InputEventAction.new()
	press.action = "jump"
	press.pressed = true
	Input.parse_input_event(press)
	await create_timer(0.12).timeout
	var release := InputEventAction.new()
	release.action = "jump"
	release.pressed = false
	Input.parse_input_event(release)
	var started: bool = actor.get_node("ClimbComponent").active
	for frame in 240:
		await physics_frame
		if actor.get_node("ClimbComponent").active: started = true
		if started and not actor.get_node("ClimbComponent").active: break
	assert(started, "Space did not start window traversal")
	assert(not actor.get_node("ClimbComponent").active and (actor.global_position.x > .8 if to_positive else actor.global_position.x < -.8), "One Space press did not complete window crossing")
	assert(not actor.get_meta("climbing",false) and actor.collision_mask != 0, "Window escape did not restore player collision")
	assert(actor.get_node("ClimbComponent").catch_seconds <= 0.0, "Completed crossing left a stale catch request")
