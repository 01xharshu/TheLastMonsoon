extends RefCounted
## Broad cart clearance volumes do not represent shot-blocking cabin walls.
static func exclusions(tree: SceneTree, initial: Array[RID]) -> Array[RID]:
	var result: Array[RID] = initial.duplicate()
	for body in tree.get_nodes_in_group("cart_clearance_bodies"):
		if body is CollisionObject3D: result.append(body.get_rid())
	for body in tree.get_nodes_in_group("cart_boarding_handles"):
		if body is CollisionObject3D: result.append(body.get_rid())
	return result

static func sight(space: PhysicsDirectSpaceState3D, tree: SceneTree, from: Vector3, to: Vector3, initial: Array[RID]) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from,to)
	query.exclude = exclusions(tree,initial)
	for pane in tree.get_nodes_in_group("carriage_glass"):
		query.exclude.append(pane.get_rid())
	return space.intersect_ray(query)

static func shoot(space: PhysicsDirectSpaceState3D, tree: SceneTree, from: Vector3, to: Vector3, damage: float, initial: Array[RID]) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from,to)
	query.exclude = exclusions(tree,initial)
	var remaining := damage
	var direction := (to-from).normalized()
	for crossing in 8:
		var hit := space.intersect_ray(query)
		if hit.is_empty(): return {}
		var body: Object = hit.collider
		if body.has_method("penetrate_shot"):
			remaining = body.penetrate_shot(remaining)
			query.exclude.append(body.get_rid())
			query.from = hit.position + direction*.02
			if remaining <= 0.0 or (to-query.from).dot(direction) <= 0.0: return hit
			continue
		if body.has_method("take_damage"): body.take_damage(remaining)
		return hit
	return {}
