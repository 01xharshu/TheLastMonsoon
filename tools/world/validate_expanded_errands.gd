extends SceneTree
var world: Node3D
var actor: CharacterBody3D
var jobs: Node
func _initialize() -> void: _run.call_deferred()
func _visit(id: String) -> void:
	actor.global_position = jobs.targets[id].global_position + Vector3(0,0,1)
	await physics_frame
func _run() -> void:
	world = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world); current_scene = world
	for frame in 25: await physics_frame
	actor = world.get_node("Player"); jobs = world.get_node("ErrandSystem")
	actor.set_physics_process(false)
	actor.inventory.items.erase("rupees")
	for id in ["port_delivery","urgent_medicine","emergency_money"]:
		await _visit("board"); jobs.use_endpoint("board",actor); assert(jobs.accept(id))
		var job: Dictionary = jobs.JOBS[id]
		await _visit(job.goal); jobs.use_endpoint(job.goal,actor)
		assert(jobs.active == id) # Receiver cannot pay before collection.
		jobs.close_panel()
		await _visit(job.pickup); jobs.use_endpoint(job.pickup,actor)
		assert(jobs.stages[id] == "carrying" and jobs.next_endpoint() == job.goal)
		var saved: Dictionary = jobs.export_state(); jobs.restore_state(saved)
		assert(jobs.active == id and jobs.stages[id] == "carrying")
		await _visit(job.goal); jobs.use_endpoint(job.goal,actor)
		assert(jobs.active.is_empty())
	assert(actor.inventory.get_item_count("rupees") == 40)
	await _visit("board"); jobs.use_endpoint("board",actor); assert(jobs.accept("family_cart"))
	await _visit("passenger"); jobs.use_endpoint("passenger",actor)
	assert(jobs.stages.family_cart == "accepted") # No distant cart boarding.
	var cart: Node3D = jobs.expanded.borrowed
	cart.global_position = jobs.expanded.passenger.global_position + Vector3(-2,0,0)
	jobs.use_endpoint("passenger",actor)
	assert(jobs.expanded.seated and jobs.stages.family_cart == "carrying")
	await _transfer_review(cart,"boarding")
	var skeleton: Skeleton3D = jobs.expanded.passenger.get("_skeleton")
	var hip: Vector3 = skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("pelvis")).origin)
	assert(hip.distance_to(cart.seat_sockets.PassengerSeat.global_position) < .1)
	actor.global_position = cart.seat_sockets.DriverSeat.global_position
	assert(not cart.board_at(actor,"PassengerSeat","passenger"))
	assert(cart.board_at(actor,"DriverSeat","driver"))
	for frame in 90: await physics_frame
	# Real disk save while occupied: preserve vehicle transform, passenger and wage.
	var saves: Node = root.get_node("SaveManager")
	var original_root: String = saves.save_root
	saves.save_root = "user://codex_errand_passenger_trip"
	var saved_position := cart.global_position
	var saved_heading := cart.rotation.y
	assert(saves.save_game(world,1))
	jobs.restore_state({})
	cart.boarding.rider = null
	actor.remove_meta("mounted_vehicle")
	cart.global_position += Vector3(30,0,20)
	saves.pending_slot = 1; saves.apply_pending(world)
	for frame in 90: await physics_frame
	assert(cart.boarding.rider == actor and cart.boarding.role == "driver")
	if DisplayServer.get_name() != "headless":
		var review := Camera3D.new(); world.add_child(review)
		review.global_position = cart.global_position + Vector3(5,3,7)
		review.look_at(cart.seat_sockets.PassengerSeat.global_position); review.current = true
		for frame in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/world/captures/errand_cart_resume.png")
	cart.boarding.rider = null; actor.remove_meta("mounted_vehicle")
	assert(jobs.active == "family_cart" and jobs.stages.family_cart == "carrying")
	assert(jobs.expanded.seated and jobs.expanded.cart == cart)
	assert(cart.global_position.distance_to(saved_position) < .01 and absf(cart.rotation.y-saved_heading) < .01)
	assert(jobs.next_endpoint() == "family_home" and actor.inventory.get_item_count("rupees") == 40)
	# Invalid/old occupied records fall back to pickup, with no wage.
	var valid_trip: Dictionary = jobs.export_state()
	var invalid_trip: Dictionary = valid_trip.duplicate(true)
	invalid_trip.passenger_trip.occupied.path = "../Player"
	jobs.restore_state(invalid_trip)
	assert(jobs.stages.family_cart == "accepted" and not jobs.expanded.seated)
	jobs.restore_state(valid_trip)
	assert(jobs.expanded.seated)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(1)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.save_root)); saves.save_root = original_root
	await _visit("family_home"); jobs.use_endpoint("family_home",actor)
	assert(jobs.active == "family_cart")
	cart.global_position = jobs.targets.family_home.person.global_position + Vector3(-2,0,0)
	for frame in 3: await physics_frame
	cart.boarding.speed = 2; jobs.use_endpoint("family_home",actor)
	assert(jobs.active == "family_cart")
	cart.boarding.speed = 0
	var blockers: Array[Node3D] = []
	for side in [1.0,-1.0]:
		var obstacle := StaticBody3D.new(); world.add_child(obstacle)
		obstacle.global_position = cart.to_global(Vector3(side*2.35,1,1.4))
		var collision := CollisionShape3D.new(); var box := BoxShape3D.new()
		box.size = Vector3(1.5,2,1.5); collision.shape = box; obstacle.add_child(collision)
		blockers.append(obstacle)
	for frame in 3: await physics_frame
	jobs.use_endpoint("family_home",actor)
	assert(jobs.expanded.transfer.is_empty() and actor.inventory.get_item_count("rupees") == 40)
	for obstacle in blockers: obstacle.queue_free()
	for frame in 3: await physics_frame
	jobs.use_endpoint("family_home",actor)
	assert(jobs.active == "family_cart" and actor.inventory.get_item_count("rupees") == 40)
	await _transfer_review(cart,"exiting")
	assert(jobs.active.is_empty() and not jobs.expanded.seated)
	assert(actor.inventory.get_item_count("rupees") == 60)
	jobs.use_endpoint("family_home",actor)
	assert(actor.inventory.get_item_count("rupees") == 60)
	jobs.close_panel()
	print("EXPANDED ERRANDS: PASS | port/medicine/money ordered pickup, saved cargo, separate wages, passenger cart proximity, seated hip, stopped/blocked arrival, continuous transfers/delayed wages, occupied disk save/load, invalid cart fallback, no duplicate payment")
	quit()

func _transfer_review(cart: Node3D, kind: String) -> void:
	var previous: Vector3 = jobs.expanded.passenger.global_position
	var max_palm_error := 0.0
	for frame in 150:
		await physics_frame
		var at: Vector3 = jobs.expanded.passenger.global_position
		if at.distance_to(previous) >= .25: print("TRANSFER_JUMP ",kind," frame ",frame," delta ",at.distance_to(previous)," from ",previous," to ",at)
		assert(at.distance_to(previous) < .25) # Reject a root teleport during transfer.
		previous = at
		if not jobs.expanded.transfer.is_empty() and jobs.expanded.passenger.get_meta("passenger_grip_weight",0.0) > .999:
			max_palm_error = maxf(max_palm_error,jobs.expanded.passenger.get_meta("passenger_palm_error_m",0.0))
		if frame == 45 and DisplayServer.get_name() != "headless":
			var old_camera := root.get_camera_3d()
			var review := Camera3D.new(); world.add_child(review)
			var subject: Vector3 = jobs.expanded.passenger.global_position+Vector3.UP*.85
			for offset in [Vector3(jobs.expanded.transfer_side*3,1.5,2),Vector3(jobs.expanded.transfer_side*3,1.5,-2),Vector3(0,2,-4),Vector3(0,2,4)]:
				var candidate: Vector3 = jobs.expanded.passenger.global_position+cart.global_basis*offset
				var query := PhysicsRayQueryParameters3D.create(candidate,subject,1)
				query.exclude = [jobs.expanded.passenger.get_node("BodyCollider").get_rid(),jobs.targets.passenger.get_rid(),actor.get_rid()]
				if world.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
					review.global_position = candidate; break
			review.look_at(subject); review.current = true
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/world/captures/errand_"+kind+"_step.png")
			old_camera.current = true; review.queue_free()
			previous = jobs.expanded.passenger.global_position

	print("PALM_CONTACT ",kind," max_error_m ",max_palm_error)
