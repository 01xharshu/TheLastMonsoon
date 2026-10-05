extends Node
## Shared seat, collision and input contract for live horse carts.
var travel: Node
var cart: Node3D
var rider: CharacterBody3D
var seat_name := ""
var role := ""
var saved_layer := 0
var saved_mask := 0
var speed := 0.0
var rider_acceleration := 0.0
var rider_turn := 0.0
var cart_handle_rids: Array[RID] = []
var collision_body: AnimatableBody3D
var clearance_shapes: Array[CollisionShape3D] = []
var transition := ""
var transition_progress := 0.0
var transition_start := Vector3.ZERO
var transition_ground := Vector3.ZERO
var transition_side := 1.0
# All horse-drawn bodies share the same travel advantage over 4/7 m/s on foot.
const CRUISE_SPEED := 10.0
const FAST_SPEED := 15.0
const REVERSE_SPEED := 3.4
const ACCELERATION := 5.0
const TRANSITION_SECONDS := 1.2

func configure(owner_cart: Node3D) -> void:
	cart = owner_cart

func _ready() -> void:
	_build_collision()
	travel = preload("res://vehicles/paid_coach_travel.gd").new()
	travel.configure(self)
	add_child(travel)

func _build_collision() -> void:
	collision_body = AnimatableBody3D.new()
	collision_body.name = "CartBodyCollision"
	collision_body.sync_to_physics = false
	collision_body.collision_layer = 1
	collision_body.collision_mask = 1
	cart.add_child(collision_body)
	collision_body.add_to_group("cart_clearance_bodies")
	var family: bool = cart.has_method("show_coachman_blockout")
	_add_clearance(Vector3(0, 1.68, 2.8), Vector3(2.25, 2.0, 3.15)) if family else _add_clearance(Vector3(0, 1.30, 2.55), Vector3(1.8, .65, 2.25))
	if family:
		_add_clearance(Vector3(-.79, 1.16, -1.88), Vector3(.8, 1.25, 2.1))
		_add_clearance(Vector3(.79, 1.16, -1.88), Vector3(.8, 1.25, 2.1))
		for side in [-1.0, 1.0]:
			_add_clearance(Vector3(side * 1.27, .84, 2.79), Vector3(.38, .07, .57))
			_add_clearance(Vector3(side * 1.18, .62, .30), Vector3(.38, .09, .50))
	else:
		_add_clearance(Vector3(0, 1.16, -1.15), Vector3(.85, 1.25, 2.1))
		for side in [-1.0, 1.0]:
			_add_clearance(Vector3(side * 1.12, .55, 1.40), Vector3(.38, .09, .50))

func _add_clearance(at: Vector3, size: Vector3) -> void:
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	collision.position = at
	collision_body.add_child(collision)
	clearance_shapes.append(collision)

func _cart_handle_exclusions() -> Array[RID]:
	# Boarding handles are StaticBody3D nodes and must not be mistaken for road.
	if cart_handle_rids.is_empty():
		for child in cart.get_children():
			if child is StaticBody3D and child.name.ends_with("Boarding"):
				cart_handle_rids.append(child.get_rid())
	return cart_handle_rids

func _vehicle_exclusions() -> Array[RID]:
	var exclusions := _cart_handle_exclusions() + [collision_body.get_rid()]
	if is_instance_valid(rider): exclusions.append(rider.get_rid())
	return exclusions

func _clearance_at(next_at: Vector3) -> bool:
	var next_basis := cart.global_basis
	var space := cart.get_world_3d().direct_space_state
	for collision in clearance_shapes:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = collision.shape
		query.transform = Transform3D(next_basis, next_at + next_basis * collision.position)
		query.exclude = _vehicle_exclusions()
		query.collision_mask = 1
		if not space.intersect_shape(query, 1).is_empty(): return false
	return true

func rein_grip_world(side: String) -> Vector3:
	return cart.rein_grip_world(side)

func foot_support_world(side: String) -> Vector3:
	var socket: Node3D = cart.seat_sockets.get(seat_name)
	var x: float = socket.position.x + (-.18 if side == "l" else .18)
	if cart.has_method("show_coachman_blockout"):
		if role == "passenger":
			var on_floor: Vector3 = socket.position + socket.basis * Vector3(-.18 if side == "l" else .18, 0, -.55)
			on_floor.y = 1.369
			return cart.to_global(on_floor)
		return cart.to_global(Vector3(x, 1.17, .50))
	if cart.variant == 1:
		return cart.to_global(Vector3(x, .845, 1.28))
	return cart.to_global(Vector3(x, 1.105, 2.02))

func passenger_hand_world(side: String) -> Vector3:
	var socket: Node3D = cart.seat_sockets.get(seat_name)
	return socket.to_global(Vector3(-.19 if side == "l" else .19, .12, -.28))

func transition_step_world() -> Vector3:
	if cart.has_method("show_coachman_blockout"):
		return cart.to_global(Vector3(transition_side * (1.27 if role == "passenger" else 1.18), .875 if role == "passenger" else .665, 2.79 if role == "passenger" else .30))
	return cart.to_global(Vector3(transition_side * 1.12, .595, 1.40))

func cabin_transfer_foot_world(side: String, progress: float) -> Vector3:
	var leading: bool = (side == "l") == (transition_side < 0.0)
	var plant: Vector3 = cart.to_global(Vector3(transition_side * (.76 if leading else .46), 1.369, 2.80 if leading else 3.02))
	if leading and progress < .62:
		var transfer := smoothstep(.43, .62, progress)
		return transition_step_world().lerp(plant, transfer) + Vector3.UP * sin(transfer * PI) * .14
	return plant.lerp(foot_support_world(side), smoothstep(.82, 1.0, progress))

func transition_hand_world() -> Vector3:
	if role == "passenger" and cart.has_method("show_coachman_blockout"):
		return cart.to_global(Vector3(transition_side * 1.13, 1.95, 2.40))
	var step := cart.to_local(transition_step_world())
	return cart.to_global(Vector3(transition_side * .85, step.y + 1.0, step.z + .30))

func board_at(actor: CharacterBody3D, seat: String, kind: String) -> bool:
	if is_instance_valid(cart) and cart.get_meta("booking_status", "public") != "public": return false
	if kind == "passenger" and cart.has_meta("errand_passenger"): return false
	if kind == "driver" and cart.has_method("can_move") and not cart.can_move(): return false
	if rider != null or actor.get_meta("climbing", false) or (actor.has_meta("mounted_vehicle") and actor.get_meta("mounted_vehicle") != null): return false
	var socket: Node3D = cart.seat_sockets.get(seat)
	if socket == null or actor.global_position.distance_to(socket.global_position) > 5.0: return false
	rider = actor
	seat_name = seat
	role = kind
	saved_layer = actor.collision_layer
	saved_mask = actor.collision_mask
	actor.collision_layer = 0
	actor.collision_mask = 0
	actor.velocity = Vector3.ZERO
	actor.is_swimming = false
	actor.survival.set_sprinting(false)
	actor.set_meta("mounted_vehicle", self)
	actor.set_meta("cart_role", role)
	var visual: Node = actor.get_node("VisualRoot/CharacterVisual")
	visual.equipment.stowed = true
	visual.equipment._refresh()
	transition = "boarding"
	transition_progress = 0.0
	transition_side = -1.0 if cart.to_local(actor.global_position).x < 0.0 else 1.0
	visual.skeleton.force_update_all_bone_transforms()
	transition_start = visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("pelvis")).origin)
	speed = 0.0
	_sync_rider()
	return true

func dismount() -> bool:
	if rider == null or transition != "": return false
	var shape: CollisionShape3D = rider.get_node("CollisionShape3D")
	for side in [transition_side, -transition_side]:
		var exit_at: Vector3 = cart.global_position + cart.global_basis.x * side * 2.35 + cart.global_basis.z * 2.2
		var ground_query := PhysicsRayQueryParameters3D.create(exit_at + Vector3.UP * 3.0, exit_at - Vector3.UP * 4.0)
		ground_query.exclude = _vehicle_exclusions()
		var floor_hit := rider.get_world_3d().direct_space_state.intersect_ray(ground_query)
		if floor_hit.is_empty(): continue
		exit_at = floor_hit.position + Vector3.UP * 0.96
		var clearance := PhysicsShapeQueryParameters3D.new()
		clearance.shape = shape.shape
		clearance.transform = Transform3D(Basis.IDENTITY, exit_at)
		clearance.exclude = _vehicle_exclusions()
		if not rider.get_world_3d().direct_space_state.intersect_shape(clearance, 1).is_empty(): continue
		transition = "exiting"
		transition_progress = 0.0
		transition_side = side
		transition_ground = exit_at
		transition_start = cart.seat_sockets[seat_name].global_position
		speed = 0.0
		return true
	rider.inventory.message_requested.emit("No clear ground beside the cart")
	return false

func _physics_process(delta: float) -> void:
	if rider == null or not is_instance_valid(cart): return
	if transition != "":
		transition_progress = minf(1.0, transition_progress + delta / TRANSITION_SECONDS)
		if role == "passenger" and cart.has_method("set_boarding_door"):
			var door_open := smoothstep(0.0, .18, transition_progress) * (1.0 - smoothstep(.82, 1.0, transition_progress))
			cart.set_boarding_door(transition_side, door_open)
		cart.set_forward_motion(0.0, delta)
		_sync_rider()
		if transition_progress >= 1.0:
			if transition == "exiting":
				var actor := rider
				rider = null
				actor.set_meta("mounted_vehicle", null)
				actor.set_meta("cart_role", "")
				actor.collision_layer = saved_layer
				actor.collision_mask = saved_mask
				actor.global_position = transition_ground
				actor.velocity = Vector3.ZERO
				if cart.has_method("show_coachman_blockout"): cart.show_coachman_blockout()
			transition = ""
		return
	if (role == "driver" or travel.payer != null) and (not cart.has_method("can_move") or cart.can_move()) and not rider.inventory_ui.is_open() and not rider.get_meta("map_open", false):
		var throttle := Input.get_axis("move_backward", "move_forward")
		var steer := Input.get_axis("move_right", "move_left")
		if travel.payer != null:
			var control: Vector2 = travel.controls(delta)
			throttle = control.x
			steer = control.y
			# Road-following turns and final docking stop before rotating.
			if throttle == 0.0: speed = 0.0
			if throttle == 0.0 and steer != 0.0:
				var previous_heading := cart.rotation.y
				cart.rotation.y += steer*delta*.35
				if not _clearance_at(cart.global_position): cart.rotation.y = previous_heading
		if cart.get_meta("errand_transfer",false):
			throttle = 0; steer = 0; speed = 0
		var previous_speed := speed
		var target_speed := REVERSE_SPEED if throttle < 0.0 else (FAST_SPEED if travel.payer != null or (role == "driver" and Input.is_action_pressed("sprint")) else CRUISE_SPEED)
		speed = move_toward(speed, throttle * target_speed, delta * ACCELERATION)
		rider_acceleration = lerpf(rider_acceleration, (speed - previous_speed) / maxf(delta, 0.001), 1.0 - exp(-6.0 * delta))
		rider_turn = lerpf(rider_turn, steer * clampf(absf(speed) / FAST_SPEED, 0.0, 1.0), 1.0 - exp(-6.0 * delta))
		var old_heading: float = cart.rotation.y
		cart.rotation.y += steer * delta * 0.42 * clampf(absf(speed), 0.0, 1.0)
		if not _clearance_at(cart.global_position):
			cart.rotation.y = old_heading
			speed = 0.0
		var next_at: Vector3 = cart.global_position - cart.global_basis.z * speed * delta
		var nose: Vector3 = cart.global_position - cart.global_basis.z * 3.5
		var obstacle := PhysicsRayQueryParameters3D.create(nose + Vector3.UP * 1.0, nose - cart.global_basis.z * signf(speed) * (1.0 + absf(speed) * delta) + Vector3.UP * 1.0)
		obstacle.exclude = _vehicle_exclusions()
		if not cart.get_world_3d().direct_space_state.intersect_ray(obstacle).is_empty():
			speed = 0.0
			_sync_rider()
			return
		var road := PhysicsRayQueryParameters3D.create(next_at + Vector3.UP * 2.0, next_at - Vector3.UP * 3.0)
		road.exclude = _vehicle_exclusions()
		var hit := cart.get_world_3d().direct_space_state.intersect_ray(road)
		if not hit.is_empty() and absf(hit.position.y - cart.global_position.y) < 0.35 and _clearance_at(Vector3(next_at.x, hit.position.y, next_at.z)):
			cart.global_position = Vector3(next_at.x, hit.position.y, next_at.z)
		else:
			speed = 0.0
	else:
		speed = 0.0 if cart.has_method("can_move") and not cart.can_move() else move_toward(speed, 0.0, delta * 2.0)
		rider_acceleration = move_toward(rider_acceleration, 0.0, delta * 6.0)
		rider_turn = move_toward(rider_turn, 0.0, delta * 4.0)
	cart.set_forward_motion(speed, delta)
	_sync_rider()

func _sync_rider() -> void:
	if rider == null: return
	var socket: Node3D = cart.seat_sockets.get(seat_name)
	if socket == null: return
	var visual: Node3D = rider.get_node("VisualRoot/CharacterVisual")
	var pelvis: int = visual.skeleton.find_bone("pelvis")
	if pelvis < 0: return
	var seated_yaw := socket.global_rotation.y + PI
	var cabin_transfer: bool = role == "passenger" and cart.has_method("show_coachman_blockout") and transition != ""
	var u: float = transition_progress if transition == "boarding" else 1.0 - transition_progress
	rider.visual_root.global_rotation.y = lerp_angle(cart.global_rotation.y - transition_side * PI * .5, seated_yaw, smoothstep(.55, .86, u)) if cabin_transfer else seated_yaw
	var hip_world: Vector3 = visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(pelvis).origin)
	var target: Vector3 = socket.global_position
	if transition != "":
		var boarding_progress := transition_progress if transition == "boarding" else 1.0 - transition_progress
		var outside: Vector3 = transition_start if transition == "boarding" else transition_ground
		var step: Vector3 = transition_step_world() + Vector3.UP * .90
		if cabin_transfer:
			var inside: Vector3 = cart.to_global(Vector3(transition_side * .68, 2.23, 2.88))
			if u < .40:
				target = outside.lerp(step, smoothstep(0.0, .40, u))
			elif u < .72:
				target = step.lerp(inside, smoothstep(.40, .72, u))
			else:
				target = inside.lerp(socket.global_position, smoothstep(.72, 1.0, u))
		elif boarding_progress < .55:
			target = outside.lerp(step, smoothstep(0.0, .55, boarding_progress))
		else:
			target = step.lerp(socket.global_position, smoothstep(.55, 1.0, boarding_progress))
	rider.global_position += target - hip_world
	rider.velocity = Vector3.ZERO
