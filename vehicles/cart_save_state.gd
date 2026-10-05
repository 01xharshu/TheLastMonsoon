extends RefCounted

static func collect(world: Node3D) -> Array:
	var states: Array = []
	for cart in world.get_tree().get_nodes_in_group("live_travel_carts"):
		var at: Vector3 = cart.global_position
		var state := {"path": str(world.get_path_to(cart)), "position": [at.x, at.y, at.z], "heading": cart.rotation.y}
		if cart.boarding.rider != null:
			state["seat"] = cart.boarding.seat_name
			state["role"] = cart.boarding.role
			if cart.boarding.travel.payer != null:
				state["paid_destination"] = cart.boarding.travel.destination
		states.append(state)
	return states

static func restore(world: Node3D, states: Array) -> void:
	for state in states:
		if not state is Dictionary: continue
		var cart := world.get_node_or_null(NodePath(str(state.get("path", ""))))
		if cart == null or not cart.is_in_group("live_travel_carts"): continue
		var at: Array = state.get("position", [])
		if at.size() != 3: continue
		var position := Vector3(float(at[0]), float(at[1]), float(at[2]))
		if not position.is_finite(): continue
		cart.global_position = position
		cart.rotation.y = float(state.get("heading", 0.0))
		if state.has("seat"):
			var actor: CharacterBody3D = world.get_node("Player")
			if cart.board_at(actor, str(state.seat), str(state.get("role", "passenger"))):
				if state.has("paid_destination"): _resume_paid(cart,str(state.paid_destination))

static func _resume_paid(cart: Node3D, destination: String) -> void:
	await cart.get_tree().create_timer(cart.boarding.TRANSITION_SECONDS + .1).timeout
	if not is_instance_valid(cart) or cart.boarding.rider == null: return
	if not cart.boarding.travel.resume_trip(destination):
		cart.boarding.rider.inventory.add_item("rupees",cart.boarding.travel.FARE)
