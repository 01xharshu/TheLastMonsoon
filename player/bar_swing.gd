extends RefCounted
## A swing runs around a fixed horizontal bar with the player capsule intact.
const RADIUS := 1.14
const LIMIT := 1.02
var bar: Node3D
var last_bar: Node3D
var direction := Vector3.ZERO
var angle := 0.0
var rate := 0.0

static func nearby(actor: CharacterBody3D, forward: Vector3, jump_height: float) -> Node3D:
	var best: Node3D
	var nearest := INF
	for candidate in actor.get_tree().get_nodes_in_group("traversal_swing_bars"):
		var offset: Vector3 = candidate.global_position - actor.global_position
		var along := offset.dot(forward)
		var cross := (Vector3(offset.x, 0, offset.z) - forward * along).length()
		if along < .02 or along > 1.35 or cross > .35:
			continue
		if absf(candidate.global_basis.x.normalized().dot(forward)) > .25:
			continue
		if offset.y < .65 or offset.y > jump_height + 1.25:
			continue
		var distance := offset.length_squared()
		if distance < nearest:
			nearest = distance
			best = candidate
	return best

func grab(actor: CharacterBody3D, forward: Vector3) -> bool:
	var candidate := nearby(actor, forward, .18)
	if candidate == null or candidate == last_bar:
		return false
	var query := PhysicsRayQueryParameters3D.create(actor.global_position, candidate.global_position, actor.collision_mask)
	query.exclude = [actor.get_rid()]
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider.get_parent() != candidate:
		return false
	direction = candidate.global_basis.z.normalized() * signf(candidate.global_basis.z.dot(forward))
	var offset: Vector3 = actor.global_position - candidate.global_position
	angle = clampf(atan2(offset.dot(direction), -offset.y), -LIMIT, -.08)
	var target := candidate.global_position + (direction * sin(angle) - Vector3.UP * cos(angle)) * RADIUS
	var travel: Vector3 = target - actor.global_position
	if travel.length() > .64 or actor.test_move(actor.global_transform, travel):
		return false
	bar = candidate
	actor.move_and_collide(travel)
	rate = clampf(actor.velocity.dot(direction) / RADIUS + 1.2, 1.35, 3.5)
	actor.velocity = Vector3.ZERO
	actor.visual_root.global_rotation.y = atan2(direction.x, direction.z)
	return true

func advance(actor: CharacterBody3D, delta: float, drive: float) -> bool:
	rate += (-sin(angle) * 5.8 + drive * 3.0 - rate * .28) * delta
	var next := clampf(angle + rate * delta, -LIMIT, LIMIT)
	var target := bar.global_position + (direction * sin(next) - Vector3.UP * cos(next)) * RADIUS
	var travel: Vector3 = target - actor.global_position
	if actor.test_move(actor.global_transform, travel):
		return false
	actor.move_and_collide(travel)
	if absf(next) >= LIMIT:
		rate *= -.30
	angle = next
	return true

func release(launch: bool) -> Vector3:
	var tangent := direction * cos(angle) + Vector3.UP * sin(angle)
	var momentum := tangent * rate * RADIUS
	last_bar = bar
	bar = null
	if not launch:
		return momentum
	return direction * clampf(momentum.dot(direction) + 2.8, 2.0, 6.5) + Vector3.UP * clampf(momentum.y + 3.0, 2.5, 5.4)
