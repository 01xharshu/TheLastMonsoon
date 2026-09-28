extends Node
## Shared seat, collision and input contract for live horse carts.
var cart: Node3D
var rider: CharacterBody3D
var seat_name := ""
var role := ""
var saved_layer := 0
var saved_mask := 0
var speed := 0.0
var cart_handle_rids: Array[RID] = []
var collision_body: AnimatableBody3D
var clearance_shapes: Array[CollisionShape3D] = []

func configure(owner_cart: Node3D) -> void:
	cart = owner_cart

func _ready() -> void:
	_build_collision()

func _build_collision() -> void:
	collision_body = AnimatableBody3D.new()
	collision_body.name = "CartBodyCollision"
	collision_body.sync_to_physics = false
	collision_body.collision_layer = 1
	collision_body.collision_mask = 1
	cart.add_child(collision_body)
	var family: bool = cart.has_method("show_coachman_blockout")
	_add_clearance(Vector3(0, 1.68, 2.8), Vector3(2.25, 2.0, 3.15)) if family else _add_clearance(Vector3(0, 1.30, 2.55), Vector3(1.8, .65, 2.25))
	if family:
		_add_clearance(Vector3(-.79, 1.16, -1.88), Vector3(.8, 1.25, 2.1))
		_add_clearance(Vector3(.79, 1.16, -1.88), Vector3(.8, 1.25, 2.1))
	else:
		_add_clearance(Vector3(0, 1.16, -1.15), Vector3(.85, 1.25, 2.1))

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
	return _cart_handle_exclusions() + [collision_body.get_rid(), rider.get_rid()]

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

func board_at(actor: CharacterBody3D, seat: String, kind: String) -> bool:
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
	_sync_rider()
	return true

func dismount() -> bool:
	if rider == null: return false
	var shape: CollisionShape3D = rider.get_node("CollisionShape3D")
	for side in [-1.0, 1.0]:
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
		var actor := rider
		rider = null
		actor.set_meta("mounted_vehicle", null)
		actor.set_meta("cart_role", "")
		actor.collision_layer = saved_layer
		actor.collision_mask = saved_mask
		actor.global_position = exit_at
		actor.velocity = Vector3.ZERO
		if cart.has_method("show_coachman_blockout"): cart.show_coachman_blockout()
		return true
	rider.inventory.message_requested.emit("No clear ground beside the cart")
	return false

func _physics_process(delta: float) -> void:
	if rider == null or not is_instance_valid(cart): return
	if role == "driver" and not rider.inventory_ui.is_open() and not rider.get_meta("map_open", false):
		var throttle := Input.get_axis("move_backward", "move_forward")
		var steer := Input.get_axis("move_right", "move_left")
		speed = move_toward(speed, throttle * 3.4, delta * 1.5)
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
		speed = move_toward(speed, 0.0, delta * 2.0)
	cart.set_forward_motion(speed, delta)
	_sync_rider()

func _sync_rider() -> void:
	if rider == null: return
	var socket: Node3D = cart.seat_sockets.get(seat_name)
	if socket == null: return
	var visual: Node3D = rider.get_node("VisualRoot/CharacterVisual")
	var pelvis: int = visual.skeleton.find_bone("pelvis")
	if pelvis < 0: return
	rider.visual_root.global_rotation.y = socket.global_rotation.y + PI
	var hip_world: Vector3 = visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(pelvis).origin)
	rider.global_position += socket.global_position - hip_world
	rider.velocity = Vector3.ZERO
