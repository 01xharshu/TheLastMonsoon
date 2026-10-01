extends SceneTree
var failures: Array[String] = []
var world: Node3D
var fort: Node3D
var player: CharacterBody3D
var samples: Array[Dictionary] = []
var camera: Camera3D

func _initialize() -> void:
	run.call_deferred()
func check(ok: bool,label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func run() -> void:
	root.size=Vector2i(1280,720)
	world=load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene=world
	for i in 12: await physics_frame
	world.get_node("GameTimeSystem").clock_paused=true
	player=world.get_node("Player")
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.global_position=Vector3(0,30,0)
	await physics_frame
	await physics_frame
	fort=get_nodes_in_group("occupied_command_fort")[0]
	if DisplayServer.get_name() != "headless":
		for layer in world.find_children("*","CanvasLayer",true,false): layer.hide()
		camera=Camera3D.new()
		camera.fov=60
		world.add_child(camera)
		camera.current=true
		await capture("fort_kitchen_realism",Vector3(-42,2.1,-67.5),Vector3(-44,1.6,-76))
		await capture("fort_cook_contact",Vector3(-38.8,1.95,-76.8),Vector3(-41,1.25,-75.1))
		await capture("fort_stores_realism",Vector3(5,2.2,-67.3),Vector3(0,1.8,-77))
		await capture("fort_staff_quarters",Vector3(48,2.1,-67),Vector3(44,1.0,-76))
		await capture("fort_service_court",Vector3(20,7,-53),Vector3(0,1.5,-75))
		await capture("fort_bastion_access",Vector3(74,11,61),Vector3(88,4.5,77))
		await capture("fort_council_detail",Vector3(6,6.8,-36),Vector3(0,5.7,-43))
		await capture("fort_gate_realism",Vector3(8,2.2,98),Vector3(0,2.3,92))
	# Pause unrelated patrol/contact studies; this fixture measures the fort and actual Player.
	for node in world.find_children("*","Node3D",true,false):
		if node.has_method("_make_clip") and not node.is_in_group("fort_staff"): node.set_process(false)
	var cook=fort.get_node("FortCook")
	var steward=fort.get_node("FortSteward")
	check(cook.animation_tree != null and steward.animation_tree != null,"staff have live independent rigged trees")
	check(cook.animation_tree != steward.animation_tree,"staff trees are independent")
	var worst_contact := 0.0
	for sample in 24:
		await physics_frame
		worst_contact=maxf(worst_contact,maxf(cook.get_meta("hand_contact_l",INF),cook.get_meta("hand_contact_r",INF)))
	check(worst_contact < .018,"cook palms remain on vessel and mixing target")
	samples.append({"cook_hand_gap_max_m":worst_contact})
	print("COOK CONTACT ",worst_contact," palms ",cook.palm_world("l")," / ",cook.palm_world("r")," targets ",cook.left_contact.global_position," / ",cook.right_contact.global_position)
	var detail=preload("res://world/suryagarh/settlements/fort_service_detail.gd").new()
	var worst_gap := 0.0
	var count := 0
	for prop in get_nodes_in_group("fort_supported_prop"):
		var box: AABB=detail._bounds(prop)
		var gap: float=absf(box.position.y)
		worst_gap=maxf(worst_gap,gap)
		count+=1
	check(count >= 35 and worst_gap < .012,"reviewed props sit on their authored supports")
	samples.append({"supported_props":count,"max_mesh_base_gap_m":worst_gap})
	var door=fort.get_node("FortKitchen/ServiceDoor")
	door.set_meta("debug_sweep",true)
	door.set_open(false)
	await create_timer(1.4).timeout
	var origin: Vector3=fort.get_node("FortKitchen").to_global(Vector3(0,1.2,9.1))
	var target: Vector3=fort.get_node("FortKitchen").to_global(Vector3(0,1.2,4.6))
	player.global_position=origin
	await physics_frame
	await physics_frame
	player.get_node("VisualRoot").global_rotation.y=PI
	check(player._find_interactable()==door,"normal player prompt finds the closed door at its latch")
	var contact := false
	for i in 75:
		await physics_frame
		player.velocity=(target-origin).normalized()*2.0
		player.move_and_slide()
		for collision in player.get_slide_collision_count():
			contact=contact or player.get_slide_collision(collision).get_collider()==door
	check(contact and fort.get_node("FortKitchen").to_local(player.global_position).z > 7.2,"actual Player body stops at closed door")
	# Release from inside; keep the actor outside the complete leaf sweep.
	player.global_position=fort.get_node("FortKitchen").to_global(Vector3(0,1.2,5.5))
	await physics_frame
	await physics_frame
	player.get_node("VisualRoot").global_rotation.y=0
	print("OPEN SELECTED ",player._find_interactable())
	player._try_primary_interaction()
	check(door.moving,"normal player primary action starts the opening motion")
	await create_timer(1.4).timeout
	check(door.opened and is_equal_approx(door.swing,1.0),"paired leaves complete opening")
	player.global_position=origin
	await physics_frame
	await physics_frame
	player.get_node("VisualRoot").global_rotation.y=PI
	check(player._find_interactable()==door,"normal player prompt remains reachable with leaves open")
	# Exercise the real movement controller and its step assist over the door sill.
	player.set_physics_process(true)
	player.velocity=Vector3.ZERO
	player.get_node("CameraPivot").global_rotation.y=0
	Input.action_press("move_forward")
	for i in 100: await physics_frame
	Input.action_release("move_forward")
	player.set_physics_process(false)
	check(fort.get_node("FortKitchen").to_local(player.global_position).z < 6,"actual Player walks through open doorway")
	player.global_position=origin
	await physics_frame
	await physics_frame
	player.get_node("VisualRoot").global_rotation.y=PI
	player._try_primary_interaction()
	await create_timer(1.4).timeout
	check(not door.opened and is_zero_approx(door.swing),"normal action closes the open door")
	# A body in the leaf sweep must postpone closure rather than get pushed or trapped.
	player.global_position=Vector3(0,30,0)
	await physics_frame
	await physics_frame
	door.set_open(true)
	await create_timer(1.4).timeout
	player.global_position=door.to_global(Vector3(-.65,1.2,.65))
	await physics_frame
	await physics_frame
	door.set_open(false)
	check(door.opened and not door.moving,"door sweep waits for a character occupying its path")
	player.global_position=Vector3(0,30,0)
	await physics_frame
	await physics_frame
	for x in [-88,88]:
		for direction in [-1,1]:
			var points: Array=fort.get_meta("bastion_route_%d_%d"%[x+88,direction+1])
			await walk_route("bastion_%d_%d"%[x,direction],points)
	player.set_physics_process(false)
	player.global_position=Vector3(0,30,0)
	await physics_frame
	await physics_frame
	var report := {"passed":failures.is_empty(),"failures":failures,"samples":samples,"renderer":DisplayServer.get_name(),"scope":"door prompt/action, Player collision/traversal, four bastion climbs, supported props and live cook hand contact; art and cloth approval separate"}
	FileAccess.open("res://docs/world/fort_realism_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func walk_route(label: String,points: Array) -> void:
	player.global_position=fort.to_global(points[0]+Vector3.UP*.95)
	await physics_frame
	await physics_frame
	player.velocity=Vector3.ZERO
	player.set_physics_process(true)
	for i in 12: await physics_frame
	var passed := true
	for index in range(1,points.size()):
		var goal: Vector3=fort.to_global(points[index])
		var delta:=goal-player.global_position
		var direction:=Vector2(delta.x,delta.z).normalized()
		player.get_node("CameraPivot").global_rotation.y=atan2(-direction.x,-direction.y)
		Input.action_press("move_forward")
		var reached := false
		for frame in 240:
			await physics_frame
			if Vector2(player.global_position.x-goal.x,player.global_position.z-goal.z).length()<.28:
				reached=true
				break
		Input.action_release("move_forward")
		if not reached:
			print("ROUTE BLOCKED ",label," point ",index," at ",player.global_position)
			passed=false
			break
	player.set_physics_process(false)
	check(passed,label+" normal Player stair ascent")
	samples.append({"route":label,"pass":passed,"finish":str(player.global_position)})

func capture(label: String,at: Vector3,target: Vector3) -> void:
	camera.global_position=fort.to_global(at)
	camera.look_at(fort.to_global(target))
	for i in 10: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/world/captures/"+label+".png")
