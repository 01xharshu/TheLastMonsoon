extends RefCounted
## Authored stair flights connect independently searched physical floor surfaces.
const Walk = preload("res://world/suryagarh/settlements/resident_walk_route.gd")
const CELLAR_Y := -4.0

static func contains(station: Node3D, at: Vector3) -> bool:
	if not is_instance_valid(station):return false
	var local:=station.to_local(at)
	return absf(local.x)<station.width*.5 and absf(local.z)<station.depth*.5 and local.y>CELLAR_Y-.3 and local.y<station.floor_y+2.0

static func support(actor: Node3D, at: Vector3) -> float:
	return Walk.support(actor,at)

static func goal_floor(actor: Node3D, goal: Vector3) -> Vector3:
	Walk.support(actor,actor.global_position)
	var ray:=PhysicsRayQueryParameters3D.create(goal+Vector3.UP*.2,goal-Vector3.UP*2.0,1,Walk.floor_excluded)
	var hit:=actor.get_world_3d().direct_space_state.intersect_ray(ray)
	return Vector3(goal.x,hit.position.y,goal.z) if not hit.is_empty() else goal

static func find_budgeted(actor: Node3D, goal: Vector3, station: Node3D, budget: Node, excluded: Array[RID], start:=Vector3.INF) -> Array[Vector3]:
	var origin: Vector3=start if start.is_finite() else actor.global_position
	var navigation_excluded: Array[RID]=excluded.duplicate()
	var scene:=actor.get_tree().current_scene
	var player: Node=scene.get_node_or_null("Player") if is_instance_valid(scene) else null
	if player is CollisionObject3D and player.global_position.distance_to(goal)<1.2:
		navigation_excluded.append(player.get_rid())
	var destination:=goal_floor(actor,goal)
	var from:=station.to_local(origin)
	var to:=station.to_local(destination)
	var on_cellar_stairs: bool=absf(from.x-12.0)<1.4 and absf(from.z)<7.8 and from.y<.25
	if from.y<-.8 or to.y<-.8 or on_cellar_stairs:
		return await cellar_route(actor,destination,station,budget,navigation_excluded,origin)
	var upward: bool=to.y>station.floor_y*.5
	var on_stairs: bool=absf(from.x-station.stair_x)<1.4 and from.z<station.stair_front+.4 and from.z>station.stair_back-.4
	if not on_stairs and (from.y>station.floor_y*.5)==upward:
		return await Walk.find_budgeted(actor,destination,budget,navigation_excluded,origin)
	var base:=Vector3(station.stair_x,0,station.stair_front+1.0)
	var top:=Vector3(station.stair_x,station.floor_y,station.stair_back-1.0)
	var entry: Vector3=base if upward else top
	var exit: Vector3=top if upward else base
	var result: Array[Vector3]=[]
	if not on_stairs:
		result=await Walk.find_budgeted(actor,station.to_global(entry),budget,navigation_excluded,origin)
		if result.is_empty():return []
	else:
		entry=from
	var previous: Vector3=result[-1] if not result.is_empty() else origin
	var front:=Vector3(station.stair_x,0,station.stair_front)
	var back:=Vector3(station.stair_x,station.floor_y,station.stair_back)
	var flight: Array[Vector3]=await checked_flight(actor,station,entry,exit,previous,front,back,budget,navigation_excluded)
	if flight.is_empty():return []
	result.append_array(flight)
	var finish: Array[Vector3]=await Walk.find_budgeted(actor,destination,budget,navigation_excluded,result[-1])
	if finish.is_empty():return []
	result.append_array(finish)
	return result

static func cellar_route(actor: Node3D, destination: Vector3, station: Node3D, budget: Node, excluded: Array[RID], origin: Vector3) -> Array[Vector3]:
	var from:=station.to_local(origin)
	var to:=station.to_local(destination)
	var downward:=to.y<-.8
	var on_stairs: bool=absf(from.x-12.0)<1.4 and absf(from.z)<7.8 and from.y<.25
	if from.y<-.8 and downward and not on_stairs:
		return await Walk.find_budgeted(actor,destination,budget,excluded,origin)
	var top:=Vector3(12,0,8.5)
	var bottom:=Vector3(12,CELLAR_Y,-8.5)
	var entry: Vector3=top if downward else bottom
	var exit: Vector3=bottom if downward else top
	var result: Array[Vector3]=[]
	if on_stairs:
		entry=from
	elif from.y>station.floor_y*.5 or (absf(from.x-station.stair_x)<1.4 and from.z<station.stair_front+.4 and from.z>station.stair_back-.4):
		result=await find_budgeted(actor,station.to_global(top),station,budget,excluded,origin)
		if result.is_empty():return []
	else:
		result=await Walk.find_budgeted(actor,station.to_global(entry),budget,excluded,origin)
		if result.is_empty():return []
	var previous: Vector3=result[-1] if not result.is_empty() else origin
	var front:=Vector3(12,0,7.5)
	var back:=Vector3(12,CELLAR_Y,-7.5)
	var flight: Array[Vector3]=await checked_flight(actor,station,entry,exit,previous,front,back,budget,excluded)
	if flight.is_empty():return []
	result.append_array(flight)
	var finish: Array[Vector3]
	if to.y>station.floor_y*.5:
		finish=await find_budgeted(actor,destination,station,budget,excluded,result[-1])
	else:
		finish=await Walk.find_budgeted(actor,destination,budget,excluded,result[-1])
	if finish.is_empty():return []
	result.append_array(finish)
	return result

static func checked_flight(actor: Node3D, station: Node3D, entry: Vector3, exit: Vector3, previous: Vector3, front: Vector3, back: Vector3, budget: Node, excluded: Array[RID]) -> Array[Vector3]:
	var shape: CollisionShape3D=actor.body_collider.get_node("BodyShape")
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=shape.shape
	query.collision_mask=1
	var sweep_excluded: Array[RID]=excluded.duplicate()
	sweep_excluded.append(actor.body_collider.get_rid())
	query.exclude=sweep_excluded
	var relative:=shape.global_position-actor.global_position
	var samples:=maxi(1,ceili(absf(entry.z-exit.z)/.25))
	var result: Array[Vector3]=[]
	for index in range(1,samples+1):
		if not await budget.checkpoint():return []
		var local:=entry.lerp(exit,float(index)/samples)
		var progress:=clampf((front.z-local.z)/(front.z-back.z),0.0,1.0)
		local.y=lerpf(front.y,back.y,progress)
		var at:=station.to_global(local)
		var height:=support(actor,at)
		if not is_finite(height):return []
		at.y=height
		query.transform=Transform3D(actor.global_basis,at+relative+Vector3.UP*.15)
		query.motion=Vector3.ZERO
		if not actor.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return []
		query.transform.origin=previous+relative+Vector3.UP*.15
		query.motion=at-previous
		if actor.get_world_3d().direct_space_state.cast_motion(query)[0]<.99:return []
		if index%4==0 or index==samples:result.append(at)
		previous=at
	return result
