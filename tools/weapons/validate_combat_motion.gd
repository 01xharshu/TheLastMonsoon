extends SceneTree
## Mechanical regression only; the current Arjun appearance is owner-rejected.
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, label: String) -> void:
	print(("PASS " if value else "FAIL ")+label)
	if not value: failures += 1
func run() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 5: await physics_frame
	var actor: CharacterBody3D = world.get_node("Player")
	var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
	var combat: Node = actor.get_node("CombatInput")
	var slash: Node = actor.get_node("TalwarSlash")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	actor.inventory.add_item("talwar",1)
	visual.equipment.stowed = false
	visual.equipment.selected = 0
	visual.equipment._refresh()
	check(slash.available(),"land combat is available")
	check(visual.equipment.owns(0),"sword in inventory")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	combat._unhandled_input(click)
	check(combat.pending_single and slash.elapsed >= slash.DURATION,"first click waits for double-click window")
	combat._unhandled_input(click)
	check(not combat.pending_single and combat.kick_time >= 0.0 and slash.elapsed >= slash.DURATION,"double click kicks without slashing")
	check(not combat.kick_landed,"kick has no contact at windup")
	combat._process(.20)
	check(not combat.kick_landed,"kick has no contact before extension")
	combat._process(.04)
	check(combat.kick_landed,"kick contact occurs during extension")
	combat.kick_time = -1.0
	visual.kick_phase = -1.0
	visual.equipment.stowed = true
	combat.punch()
	check(combat.punch_time >= 0.0 and not combat.punch_landed,"punch begins without contact")
	combat._process(.18)
	check(combat.punch_landed,"punch contact occurs during extension")
	combat.punch_time = -1.0
	visual.punch_phase = -1.0
	visual.equipment.stowed = false
	combat._unhandled_input(click)
	combat._process(combat.DOUBLE_CLICK_SECONDS+.01)
	check(slash.elapsed < slash.DURATION,"single click starts sword slash")
	slash._process(.35)
	check(visual.slash_phase >= 0.0,"sword strike phase reaches visual")
	actor.set_physics_process(false)
	slash.set_process(false)
	visual.set_process(false)
	slash.elapsed=slash.DURATION
	visual.slash_phase=-1.0
	actor.global_basis=Basis.IDENTITY
	actor.visual_root.global_rotation=Vector3.ZERO
	var marker := StaticBody3D.new()
	marker.set_script(load("res://world/suryagarh/cuttable_flag.gd"))
	world.add_child(marker)
	marker.global_position = actor.global_position+Vector3(0,-.9,1.05)
	var flag: Node3D = load("res://assets/props/flags/eic/prop_eic_checkpoint_flag_01.glb").instantiate()
	marker.add_child(flag)
	flag.scale = Vector3.ONE*.55
	marker.bind_visual()
	var pole_collision := CollisionShape3D.new()
	var pole_shape := CylinderShape3D.new()
	pole_shape.radius = .05
	pole_shape.height = 2.475
	pole_collision.shape = pole_shape
	pole_collision.position.y=1.2375
	marker.add_child(pole_collision)
	var camera: Camera3D=actor.get_node("CameraPivot/SpringArm3D/Camera3D")
	camera.global_position=actor.global_position+Vector3(0,1,-3)
	camera.look_at(marker.global_position+Vector3.UP*1.25)
	check(slash.strike() and slash.target==marker,"nearby aimed flag becomes strike target")
	var review_camera: Camera3D
	if DisplayServer.get_name()!="headless":
		review_camera=Camera3D.new()
		world.add_child(review_camera)
		review_camera.global_position=actor.global_position+Vector3(-2.8,1.4,2.6)
		review_camera.look_at(actor.global_position+Vector3(0,.5,.65))
		review_camera.make_current()
		actor.get_node("UI").hide()
		world.get_node("LandscapeUI").hide()
	for i in 45:
		visual._process(1.0/60.0)
		slash._process(1.0/60.0)
		if i==26 and review_camera != null:
			for frame in 3: await process_frame
			await RenderingServer.frame_post_draw
			check(not root.get_texture().get_image().is_empty(),"native blade contact rendered")
	check(marker.cut,"animated blade contact splits pole")
	check(marker.fallen_top != null and marker.fallen_top is RigidBody3D,"upper pole becomes falling rigid body")
	check(marker.find_child("BrokenPoleStump",false,false) != null,"lower stump remains")
	check(not marker.cut_flag(),"flag cannot award a second cut")
	var distant := StaticBody3D.new()
	distant.set_script(load("res://world/suryagarh/cuttable_flag.gd"))
	world.add_child(distant)
	distant.global_position=actor.global_position+Vector3(0,-.9,3.5)
	camera.look_at(distant.global_position+Vector3.UP*1.25)
	check(slash.strike() and slash.target==null,"out-of-reach pole is not targeted")
	for i in 45:
		visual._process(1.0/60.0)
		slash._process(1.0/60.0)
	check(not distant.cut,"distant pole remains intact after slash")
	for i in 15: await physics_frame
	check(marker.fallen_top.global_position.y < marker.global_position.y+1.9,"severed upper pole falls")
	marker.fallen_top.queue_free()
	marker.queue_free()
	var blocked := StaticBody3D.new()
	blocked.set_script(load("res://world/suryagarh/cuttable_flag.gd"))
	world.add_child(blocked)
	blocked.global_position=actor.global_position+Vector3(0,-.9,1.05)
	var wall := StaticBody3D.new()
	world.add_child(wall)
	wall.global_position=actor.global_position+Vector3(0,.3,.72)
	var wall_collision := CollisionShape3D.new()
	var wall_shape := BoxShape3D.new()
	wall_shape.size=Vector3(2,2,.15)
	wall_collision.shape=wall_shape
	wall.add_child(wall_collision)
	for i in 3: await physics_frame
	camera.look_at(blocked.global_position+Vector3.UP*1.25)
	check(slash.strike() and slash.target==blocked,"blocked nearby pole can be aimed at")
	for i in 45:
		visual._process(1.0/60.0)
		slash._process(1.0/60.0)
	check(not blocked.cut,"wall prevents sword from breaking pole")
	wall.queue_free()
	await process_frame # Flush removal before checking physics clearance.
	for i in 3: await physics_frame
	check(slash.strike(),"strike resumes after obstacle removed")
	for i in 45:
		visual._process(1.0/60.0)
		slash._process(1.0/60.0)
	print("FINAL BLADE MIN CONTACT ",slash.closest_target_contact)
	check(blocked.cut,"same reachable pole breaks after obstacle removed")
	print("COMBAT MOTION ","PASS" if failures==0 else "FAIL "+str(failures))
	preload("res://tools/test_audio_cleanup.gd").stop(root)
	world.queue_free()
	await process_frame
	await process_frame
	await preload("res://tools/test_audio_cleanup.gd").settle(self)
	await root.get_node("SaveManager").quit_game(1 if failures else 0)
