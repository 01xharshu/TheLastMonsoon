extends RefCounted
## Camera selects the visible aim point; projectiles still start at the weapon.
static func point(actor: CharacterBody3D, camera: Camera3D, reach := 180.0) -> Vector3:
	var end := camera.global_position-camera.global_basis.z*reach
	var query := PhysicsRayQueryParameters3D.create(camera.global_position,end,9,[actor.get_rid()])
	query.exclude=preload("res://combat/ballistic_trace.gd").exclusions(actor.get_tree(),query.exclude)
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.position if not hit.is_empty() else end

static func launch_direction(origin: Vector3, target: Vector3, speed: float, gravity: float) -> Vector3:
	var offset := target-origin
	var flat := Vector3(offset.x,0,offset.z)
	var distance := flat.length()
	if distance<.001 or speed<=0.0 or gravity<=0.0:return offset.normalized()
	var speed2 := speed*speed
	var discriminant := speed2*speed2-gravity*(gravity*distance*distance+2.0*offset.y*speed2)
	if discriminant<0.0:return offset.normalized()
	var tangent := (speed2-sqrt(discriminant))/(gravity*distance)
	return (flat.normalized()+Vector3.UP*tangent).normalized()
