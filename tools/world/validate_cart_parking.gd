extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); push_error(label)
func frames(count: int) -> void:
	for index in count: await physics_frame
func run() -> void:
	var live := "--live" in OS.get_cmdline_user_args()
	var world: Node3D
	if live:
		world = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	else:
		world = Node3D.new()
		var clock := GameTimeSystem.new()
		clock.name = "GameTimeSystem"
		world.add_child(clock)
		var terrain := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(200,.2,200)
		shape.shape = box
		shape.position = Vector3(-265,-.1,-18)
		terrain.add_child(shape)
		world.add_child(terrain)
		var carts := Node3D.new()
		carts.name = "LiveCarts"
		world.add_child(carts)
		var cart: Node3D = load("res://vehicles/family_carriage_candidate.gd").new()
		cart.name = "GovernmentHouseFamilyCarriage"
		cart.position = Vector3(-265,0,-18)
		cart.rotation.y = PI*.5
		cart.add_to_group("live_travel_carts")
		cart.add_to_group("cart_parking_vehicles")
		carts.add_child(cart)
		var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
		actor.name = "Player"
		world.add_child(actor)
	root.add_child(world)
	current_scene = world
	await frames(3)
	var cart: Node3D = world.get_node("LiveCarts/GovernmentHouseFamilyCarriage")
	var actor: CharacterBody3D = world.get_node("Player")
	actor.set_physics_process(false)
	actor.set_process_unhandled_input(false)
	var bay: Node3D = cart.get_meta("parking_bay") if cart.has_meta("parking_bay") else null
	if bay == null:
		bay = load("res://vehicles/cart_parking_bay.gd").new()
		world.add_child(bay)
		bay.configure(cart,"Public Coach Parking")
	await frames(3)
	check(bay.get_node_or_null("CompactedStanding") != null,"Standing surface missing")
	bay.refresh_occupancy()
	check(bay.occupant == cart,"Initial occupancy missing")
	check(bay.try_dock(cart),"Initial dock clearance failed")
	var initial := cart.global_transform
	# Occupancy is independent of reservation and remains at a fixed world location.
	cart.global_position += Vector3(20,0,0)
	bay.refresh_occupancy()
	check(bay.occupant == null,"Vacated bay remained occupied")
	var intruder := Node3D.new()
	world.add_child(intruder)
	intruder.global_position = bay.global_position
	intruder.add_to_group("cart_parking_vehicles")
	bay.refresh_occupancy()
	check(bay.occupant == intruder,"Other vehicle occupancy missing")
	check(not bay.try_dock(cart),"Occupied bay accepted dock")
	intruder.free()
	cart.global_transform = initial
	check(bay._overlaps_vehicle(cart),"Owner footprint missing")
	cart.global_position = bay.to_global(Vector3(0,0,7))
	check(bay._overlaps_vehicle(cart),"Vehicle body overlaps bay with centre outside")
	cart.global_transform = initial
	# A physical obstacle must reject final docking, preserving the vehicle transform.
	var obstacle := StaticBody3D.new()
	var block := CollisionShape3D.new()
	var block_shape := BoxShape3D.new()
	block_shape.size = Vector3(1,1,1)
	block.shape = block_shape
	obstacle.add_child(block)
	world.add_child(obstacle)
	obstacle.global_position = cart.to_global(Vector3(0,1.7,2.8))
	await frames(2)
	check(not bay.try_dock(cart),"Obstacle accepted dock")
	check(cart.global_transform.is_equal_approx(initial),"Failed dock changed transform")
	obstacle.queue_free()
	await frames(2)
	if not live or "--return" in OS.get_cmdline_user_args():
		actor.global_position = cart.to_global(Vector3(-2,.96,2.79))
		check(cart.board_at(actor,"RearPassengerLeft","passenger"),"Return passenger boarding failed")
		await frames(85)
		cart.boarding.set_physics_process(false)
		cart.global_position += Vector3(10,0,0)
		cart.boarding._sync_rider()
		actor.inventory.add_item("rupees",5)
		check(cart.boarding.travel.request_trip(cart.boarding.travel.STANDING),"Return request failed")
		var steps := 0
		while cart.boarding.travel.payer != null and steps < 12000:
			cart.boarding._physics_process(1.0/60.0)
			cart.boarding.collision_body.force_update_transform()
			steps += 1
			if steps % 8 == 0: await physics_frame
		bay.refresh_occupancy()
		check(cart.boarding.travel.payer == null and bay.docked,"Return failed to dock")
		check(actor.inventory.get_item_count("rupees") == 3,"Return fare mismatch")
		print("RETURN STEPS ",steps," final=",cart.global_position," heading=",cart.rotation.y," docked=",bay.docked)
	var results: Array = []
	for standing in get_nodes_in_group("cart_parking_bays"):
		standing.refresh_occupancy()
		var vehicle: Node3D = standing.owner_cart
		var clear: bool = vehicle.boarding._clearance_at(vehicle.global_position)
		results.append({"label":standing.get_meta("parking_label"),"occupied":standing.occupant != null,"docked":standing.docked,"vehicle_clear":clear,"position":[standing.global_position.x,standing.global_position.y,standing.global_position.z]})
		if live: check(clear,"Live standing blocked: "+str(standing.name))
	var report := {"status":"PASS" if failures.is_empty() else "FAIL","scope":"full-world standing clearance and accelerated road return" if live and "--return" in OS.get_cmdline_user_args() else ("full-world standing clearance" if live else "physical docking, occupancy, road return and fare"),"failures":failures,"bays":results}
	var path := "res://docs/world/cart_parking_live_validation.json" if live else "res://docs/world/cart_parking_validation.json"
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("CART PARKING ",report)
	world.queue_free()
	await frames(3)
	quit(0 if failures.is_empty() else 1)
