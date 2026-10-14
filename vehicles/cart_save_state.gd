extends RefCounted

class PendingCityRestore extends Node:
	var states: Array = []
	var apply_record: Callable
	var population: Node

	var checked_records := 0
	var held_actor: CharacterBody3D
	var previous_physics := false
	var held_inputs: Array[Node] = []
	var occupied_path := ""

	func hold_controls(actor: CharacterBody3D) -> void:
		held_actor = actor
		previous_physics = actor.is_physics_processing()
		actor.velocity = Vector3.ZERO
		actor.set_physics_process(false)
		for node in [actor] + actor.find_children("*", "Node", true, false):
			if node.is_processing_unhandled_input():
				held_inputs.append(node)
				node.set_process_unhandled_input(false)

	func release_controls() -> void:
		if is_instance_valid(held_actor): held_actor.set_physics_process(previous_physics)
		for node in held_inputs:
			if is_instance_valid(node): node.set_process_unhandled_input(true)
		held_inputs.clear()
		held_actor = null

	func _ready() -> void:
		# The loader publishes carts only after groups, journey and visuals exist.
		population.cart_spawned.connect(_refresh)
		population.population_ready.connect(_refresh)
		population.tree_exiting.connect(_retire)
		_refresh()

	func _exit_tree() -> void:
		release_controls()
		if not is_instance_valid(population): return
		for entry in [["cart_spawned",_refresh],["population_ready",_refresh],["tree_exiting",_retire]]:
			if population.is_connected(entry[0],entry[1]): population.disconnect(entry[0],entry[1])

	func _retire() -> void:
		release_controls()
		queue_free()

	func _refresh(_cart: Node3D = null) -> void:
		if is_queued_for_deletion(): return
		var world := get_parent()
		var remaining: Array = []
		for state: Dictionary in states:
			checked_records += 1
			var cart := preload("res://vehicles/cart_save_state.gd")._resolve_cart(world,state)
			if cart != null and not cart.is_queued_for_deletion() and cart.is_in_group("live_travel_carts"):
				apply_record.call(state)
			else:
				remaining.append(state)
		states = remaining
		var waiting_for_rider := false
		for state: Dictionary in states:
			if str(state.get("path", "")) == occupied_path: waiting_for_rider = true
		if not waiting_for_rider: release_controls()
		if states.is_empty() or not is_instance_valid(population) or not population.is_inside_tree() or population.is_queued_for_deletion() or population.ready_population:
			_retire()

static func collect(world: Node3D) -> Array:
	var states: Array = []
	for cart in world.get_tree().get_nodes_in_group("live_travel_carts"):
		if not world.is_ancestor_of(cart): continue
		var at: Vector3 = cart.global_position
		var state := {"path": str(world.get_path_to(cart)), "position": [at.x, at.y, at.z], "heading": cart.rotation.y}
		state.merge(preload("res://systems/vehicle_permissions.gd").export_state(cart))
		state["entity_id"]=preload("res://systems/entity_identity.gd").id_for(world,cart)
		if cart.boarding.rider != null:
			state["seat"] = cart.boarding.seat_name
			state["role"] = cart.boarding.role
			if cart.boarding.travel.payer != null:
				state["paid_destination"] = cart.boarding.travel.destination
			elif cart.has_meta("pending_paid_destination"):
				state["paid_destination"] = str(cart.get_meta("pending_paid_destination"))
		states.append(state)
	var pending := world.get_node_or_null("PendingCityCartRestore")
	if pending != null and not pending.is_queued_for_deletion():
		var collected := {}
		for state: Dictionary in states: collected[str(state.path)] = true
		for state: Dictionary in pending.states:
			if not collected.has(str(state.path)): states.append(state.duplicate(true))
	return states

static func restore(world: Node3D, states: Array) -> void:
	# City carts are spawned incrementally after SaveManager applies the slot.
	# Keep only their missing records with this world, never across scene changes.
	var previous := world.get_node_or_null("PendingCityCartRestore")
	if previous != null:
		world.remove_child(previous)
		previous.queue_free()
	var population := world.get_node_or_null("CityRoutePopulation")
	var pending: Array = []
	var occupied_priority_set := false
	var occupied_path := ""
	if population != null: population.set_saved_cart_priority("")
	for state in states:
		if not state is Dictionary: continue
		var cart := _resolve_cart(world,state)
		if cart == null and str(state.get("path", "")).begins_with("CityRoutePopulation/") and population != null and not population.ready_population:
			pending.append(state.duplicate(true))
			if not occupied_priority_set and not str(state.get("seat","")).is_empty():
				occupied_priority_set=population.set_saved_cart_priority(str(state.path))
				if occupied_priority_set: occupied_path = str(state.path)
			continue
		if cart == null or not cart.is_in_group("live_travel_carts"): continue
		_restore_record(state,world)
	if not pending.is_empty():
		var restorer := PendingCityRestore.new()
		restorer.name = "PendingCityCartRestore"
		restorer.states = pending
		restorer.population = population
		restorer.apply_record = _restore_record.bind(world)
		if occupied_priority_set:
			restorer.occupied_path = occupied_path
			restorer.hold_controls(world.get_node("Player"))
		world.add_child(restorer)

static func _restore_record(state: Dictionary, world: Node3D) -> void:
	var cart := _resolve_cart(world,state)
	if cart == null or cart.is_queued_for_deletion() or not cart.is_in_group("live_travel_carts"): return
	var at: Array = state.get("position", [])
	if at.size() != 3: return
	var position := Vector3(float(at[0]), float(at[1]), float(at[2]))
	if not position.is_finite(): return
	cart.global_position = position
	cart.rotation.y = float(state.get("heading", 0.0))
	cart.set_meta("paid_restore_generation",int(cart.get_meta("paid_restore_generation",0))+1)
	cart.remove_meta("pending_paid_destination")
	preload("res://systems/vehicle_permissions.gd").restore_state(cart,state,state.get("role","")=="driver")
	if state.has("seat"):
		var actor: CharacterBody3D = world.get_node("Player")
		cart.set_meta("restore_in_progress",true)
		var boarded: bool = cart.boarding.rider==actor and cart.boarding.seat_name==str(state.seat) and cart.boarding.role==str(state.get("role","passenger"))
		if not boarded: boarded=cart.board_at(actor, str(state.seat), str(state.get("role", "passenger")))
		cart.remove_meta("restore_in_progress")
		if boarded:
			if state.has("paid_destination"): _resume_paid(cart,str(state.paid_destination))

static func _resolve_cart(world: Node3D, state: Dictionary) -> Node3D:
	return preload("res://systems/entity_identity.gd").resolve(world,state,preload("res://systems/entity_identity.gd").index_group(world,&"live_travel_carts")) as Node3D

static func _resume_paid(cart: Node3D, destination: String) -> void:
	var generation: int = int(cart.get_meta("paid_restore_generation",0))
	var actor: CharacterBody3D = cart.boarding.rider
	cart.set_meta("pending_paid_destination",destination)
	# Cold spawn frames and paused gameplay must not outrun physical boarding.
	if cart.boarding.transition != "": await cart.boarding.transition_finished
	if not is_instance_valid(cart) or int(cart.get_meta("paid_restore_generation",0)) != generation: return
	cart.remove_meta("pending_paid_destination")
	if not is_instance_valid(actor) or cart.boarding.rider != actor: return
	if cart.boarding.travel.payer==actor and cart.boarding.travel.destination==destination: return
	if not cart.boarding.travel.resume_trip(destination):
		actor.inventory.add_item("rupees",cart.boarding.travel.FARE)
