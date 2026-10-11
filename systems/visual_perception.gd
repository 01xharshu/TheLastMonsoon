extends RefCounted
## Shared identification rules. Hearing/touch are separate incident evidence.
static func sees(observer: Node3D, subject: CharacterBody3D, range_m := 28.0) -> bool:
	if not is_instance_valid(observer) or not is_instance_valid(subject): return false
	if observer.get_meta("dead",false) or observer.get_meta("knocked_out",false) or observer.get_meta("sleeping",false): return false
	var from := observer.global_position+Vector3.UP*1.4
	var stance := subject.get_node_or_null("StealthStance")
	var target: Vector3 = stance.sight_target() if stance != null else subject.global_position+Vector3.UP*.4
	var toward := target-from
	var horizontal := target-observer.global_position
	horizontal.y=0
	var forward := observer.global_basis.z
	forward.y=0
	if horizontal.length_squared()>.000001 and horizontal.normalized().dot(forward.normalized())<.2: return false
	var limit: float = stance.visible_range(from,range_m) if stance != null else range_m
	if toward.length_squared()>limit*limit: return false
	if preload("res://combat/escape_smoke.gd").obscures(observer.get_tree(),from,target): return false
	var query := PhysicsRayQueryParameters3D.create(from,target,1)
	query.exclude=[subject.get_rid()]
	var body: CollisionObject3D = observer.get("body_collider")
	if is_instance_valid(body): query.exclude.append(body.get_rid())
	return observer.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
