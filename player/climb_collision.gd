extends RefCounted
## Solid-body climb travel. Contact animation never disables world collision.
var collider: CollisionShape3D
var original_shape: Shape3D
var original_position := Vector3.ZERO
var capsule: CapsuleShape3D

func can_move(actor: CharacterBody3D, from: Vector3, to: Vector3, height: float, centre: Vector3 = Vector3.ZERO) -> bool:
	var probe := CapsuleShape3D.new()
	probe.radius = .28
	probe.height = height
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.transform = Transform3D(Basis.IDENTITY,from+centre)
	query.motion = to-from
	query.exclude = [actor.get_rid()]
	query.collision_mask = actor.collision_mask
	var travel := actor.get_world_3d().direct_space_state.cast_motion(query)
	return travel[0] > .995

func begin(actor: CharacterBody3D, height: float = 1.6, centre: Vector3 = Vector3.ZERO) -> void:
	collider = actor.get_node("CollisionShape3D")
	original_shape = collider.shape
	original_position = collider.position
	capsule = CapsuleShape3D.new()
	capsule.radius = .28
	capsule.height = height
	collider.position = centre
	collider.shape = capsule

func move_to(actor: CharacterBody3D, destination: Vector3, height: float) -> bool:
	capsule.height = maxf(.56,height)
	actor.move_and_collide(destination-actor.global_position)
	return actor.global_position.distance_to(destination) < .025

func finish(actor: CharacterBody3D) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = original_shape
	query.transform = actor.global_transform*Transform3D(Basis.IDENTITY,original_position)
	query.exclude = [actor.get_rid()]
	query.collision_mask = actor.collision_mask
	if not actor.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return false
	collider.shape = original_shape
	collider.position = original_position
	return true
