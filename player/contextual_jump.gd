extends RefCounted
## Space takeoff is justified by nearby static geometry or a supported gap.
## Queries run on a press, never as a background world scan.
func available(actor: CharacterBody3D, forward: Vector3, step_height: float, jump_height: float) -> bool:
	forward.y=0.0
	if forward.length_squared()<.001:return false
	forward=forward.normalized()
	if preload("res://player/window_climb.gd").new().try_start(actor,true):return true
	if actor.test_move(actor.global_transform,Vector3.UP*jump_height):return false
	var space:=actor.get_world_3d().direct_space_state
	var feet:=actor.global_position-Vector3.UP*.9
	for height in [step_height+.08,.9,1.4]:
		var query:=PhysicsRayQueryParameters3D.create(feet+Vector3.UP*height,feet+Vector3.UP*height+forward*1.5,actor.collision_mask)
		query.exclude=[actor.get_rid()]
		var hit:=space.intersect_ray(query)
		if hit.is_empty() or not hit.collider is StaticBody3D or absf(hit.normal.y)>.65:continue
		if hit.collider.get_meta("climb_blocked",false):continue
		if hit.collider.is_in_group("climbable_walls"):return true
		var beyond:Vector3=hit.position-hit.normal*.12
		query.from=Vector3(beyond.x,feet.y+2.2,beyond.z)
		query.to=Vector3(beyond.x,feet.y+step_height,beyond.z)
		var top:=space.intersect_ray(query)
		if not top.is_empty() and top.collider==hit.collider and top.normal.y>.65:return true
	# Clear ground is not a jump opportunity. A nearby gap needs a reachable,
	# approximately level landing, rather than permission to jump off a cliff.
	var near_query:=PhysicsRayQueryParameters3D.create(feet+forward*.9+Vector3.UP*.2,feet+forward*.9-Vector3.UP*.45,actor.collision_mask)
	near_query.exclude=[actor.get_rid()]
	if not space.intersect_ray(near_query).is_empty():return false
	for distance in [1.5,2.0,2.5]:
		near_query.from=feet+forward*distance+Vector3.UP*.3
		near_query.to=feet+forward*distance-Vector3.UP*.45
		var landing:=space.intersect_ray(near_query)
		if not landing.is_empty() and landing.normal.y>.7:return true
	return false
