extends Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var player: CharacterBody3D = world.get_node("Player")
	var carts: Node3D = world.get_node("LiveCarts")
	for spec in [
		["VillagePassengerEkka", "DriverSeat", "driver"],
		["VillagePassengerEkka", "PassengerSeat", "passenger"],
		["VillageGoodsCart", "DriverSeat", "driver"],
		["GovernmentHouseFamilyCarriage", "CoachmanSeat", "driver"],
		["GovernmentHouseFamilyCarriage", "RearPassengerRight", "passenger"],
		["GovernmentHouseFamilyCarriage", "RearPassengerLeft", "passenger"]
	]:
		var cart: Node3D = carts.get_node(spec[0])
		assert(cart != null and cart.seat_sockets.has(spec[1]), "Missing cart or seat: %s" % str(spec))
		var socket: Node3D = cart.seat_sockets[spec[1]]
		player.global_position = socket.global_position + cart.global_basis.x * 1.7
		player.velocity = Vector3.ZERO
		await get_tree().physics_frame
		assert(cart.board_at(player, spec[1], spec[2]), "Board failed: %s" % str(spec))
		assert(cart.boarding.transition == "boarding", "Board transition missing")
		await _finish_transition(cart)
		await get_tree().physics_frame
		assert(cart.rider == player and player.get_meta("cart_role", "") == spec[2], "Seat failed: %s" % str(spec))
		assert(cart.boarding.dismount(), "Dismount failed: %s" % str(spec))
		assert(cart.boarding.transition == "exiting", "Exit transition missing")
		await _finish_transition(cart)
		assert(cart.rider == null, "Seat not released: %s" % str(spec))
		print("LIVE CART SEAT PASS: ", spec)
	for label in ["VillagePassengerEkka", "VillageGoodsCart", "GovernmentHouseFamilyCarriage"]:
		var cart: Node3D = carts.get_node(label)
		var seat: String = "CoachmanSeat" if label == "GovernmentHouseFamilyCarriage" else "DriverSeat"
		player.global_position = cart.seat_sockets[seat].global_position + cart.global_basis.x * 1.7
		await get_tree().physics_frame
		assert(cart.board_at(player, seat, "driver"), "Driver board failed: " + label)
		await _finish_transition(cart)
		var start: Vector3 = cart.global_position
		Input.action_press("move_forward")
		for i in 45: await get_tree().physics_frame
		Input.action_release("move_forward")
		assert(cart.global_position.distance_to(start) > .15, "Cart did not move: " + label)
		if label == "VillagePassengerEkka":
			var heading: float = cart.rotation.y
			Input.action_press("move_forward")
			Input.action_press("move_left")
			for i in 60: await get_tree().physics_frame
			Input.action_release("move_left")
			Input.action_release("move_forward")
			assert(absf(angle_difference(heading, cart.rotation.y)) > .1, "Open-road steering failed")
			print("LIVE CART STEERING PASS: heading change=", absf(angle_difference(heading, cart.rotation.y)))
		assert(cart.boarding.dismount(), "Moving cart exit failed: " + label)
		await _finish_transition(cart)
		print("LIVE CART TRAVEL PASS: ", label, " distance=", cart.global_position.distance_to(start))
	var ekka: Node3D = carts.get_node("VillagePassengerEkka")
	var body: AnimatableBody3D = ekka.get_node("CartBodyCollision")
	assert(body.get_child_count() == 4, "Cart, horse and boarding-step collision shapes missing")
	await get_tree().physics_frame
	var body_ray := PhysicsRayQueryParameters3D.create(ekka.to_global(Vector3(-2.2, 1.3, 2.55)), ekka.to_global(Vector3(2.2, 1.3, 2.55)))
	body_ray.exclude = ekka.boarding._cart_handle_exclusions() + [player.get_rid()]
	var body_hit := ekka.get_world_3d().direct_space_state.intersect_ray(body_ray)
	assert(body_hit.get("collider") == body, "Player-side ray passed through cart body")
	print("LIVE CART BODY COLLISION PASS")
	var obstacle := StaticBody3D.new()
	var obstacle_shape := CollisionShape3D.new()
	var obstacle_box := BoxShape3D.new()
	obstacle_box.size = Vector3(.65, 1.5, .65)
	obstacle_shape.shape = obstacle_box
	obstacle.add_child(obstacle_shape)
	world.add_child(obstacle)
	obstacle.global_position = ekka.to_global(Vector3(.65, .75, -4.0))
	player.global_position = ekka.seat_sockets["DriverSeat"].global_position + ekka.global_basis.x * 1.7
	await get_tree().physics_frame
	assert(ekka.board_at(player, "DriverSeat", "driver"))
	await _finish_transition(ekka)
	var before: Vector3 = ekka.global_position
	Input.action_press("move_forward")
	for i in 180: await get_tree().physics_frame
	Input.action_release("move_forward")
	var advance: float = ekka.global_position.distance_to(before)
	assert(advance > .2 and advance < 1.8, "Cart did not stop before side obstacle: %.3f" % advance)
	assert(ekka.boarding.dismount(), "Blocked cart exit failed")
	await _finish_transition(ekka)
	print("LIVE CART SIDE OBSTACLE PASS: advance=", advance)
	print("LIVE CART BOARD/DISMOUNT: PASS")
	get_tree().quit()

func _finish_transition(cart: Node3D) -> void:
	var stopped_at: Vector3 = cart.global_position
	for i in 120:
		if cart.boarding.transition == "": return
		assert(cart.global_position.distance_to(stopped_at) < .001, "Cart moved during boarding or exit")
		if cart.boarding.role == "passenger" and cart.has_method("set_boarding_door"):
			if cart.boarding.transition_progress > .25 and cart.boarding.transition_progress < .75:
				var door: Node3D = cart.boarding_doors[cart.boarding.transition_side]
				assert(door.get_child_count() >= 7 and absf(door.rotation.y) > 1.0, "Passenger door did not open: parts=%d angle=%.3f progress=%.3f" % [door.get_child_count(), door.rotation.y, cart.boarding.transition_progress])
		await get_tree().physics_frame
	assert(false, "Cart transition did not finish")
