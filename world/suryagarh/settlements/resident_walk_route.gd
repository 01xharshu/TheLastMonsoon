extends RefCounted
## Event-driven local navigation over real support and the actor's whole capsule.
static var floor_excluded:Array[RID]=[]
static var floor_space:=RID()
static var floor_refresh:=0

static func support(actor:Node3D,at:Vector3)->float:
	var now:=Time.get_ticks_msec()
	var space:RID=actor.get_world_3d().space
	if space!=floor_space or now-floor_refresh>250:
		floor_space=space;floor_refresh=now;floor_excluded.clear()
		for other in actor.get_tree().get_nodes_in_group("combat_actors"):
			if is_instance_valid(other) and other.is_inside_tree() and other.get("body_collider")!=null:floor_excluded.append(other.body_collider.get_rid())
	var excluded:Array[RID]=floor_excluded
	var ray:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*1.4,at-Vector3.UP*.7,1,excluded)
	var hit:=actor.get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.position.y if not hit.is_empty() else INF

static func find(actor:Node3D,goal:Vector3,extra_excluded:Array[RID]=[])->Array[Vector3]:
	var origin:=actor.global_position
	const SPACING:=.8
	var destination:=Vector2i(roundi((goal.x-origin.x)/SPACING),roundi((goal.z-origin.z)/SPACING))
	if absi(destination.x)>90 or absi(destination.y)>90:return []
	var pending:Array[Vector2i]=[Vector2i.ZERO]
	var costs:Dictionary={Vector2i.ZERO:0.0};var parents:Dictionary={};var points:Dictionary={Vector2i.ZERO:origin}
	var body:CollisionObject3D=actor.body_collider
	var shape:CollisionShape3D=body.get_node("BodyShape")
	var excluded:Array[RID]=[body.get_rid()];excluded.append_array(extra_excluded)
	var space:=actor.get_world_3d().direct_space_state
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape.shape;query.collision_mask=1;query.exclude=excluded;query.margin=.02
	var relative:=shape.global_transform.origin-origin
	for attempt in 2400:
		if pending.is_empty():break
		var best:=0;var score:=INF
		for i in pending.size():
			var cell:Vector2i=pending[i]
			var candidate:float=float(costs[cell])+Vector2(cell-destination).length()
			if candidate<score:score=candidate;best=i
		var cell:Vector2i=pending.pop_at(best)
		if cell==destination:
			var result:Array[Vector3]=[goal]
			while cell!=Vector2i.ZERO:result.push_front(points[cell]);cell=parents[cell]
			return result
		for direction in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1),Vector2i(1,1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(-1,-1)]:
			var next:Vector2i=cell+direction
			if next.x<mini(0,destination.x)-16 or next.x>maxi(0,destination.x)+16 or next.y<mini(0,destination.y)-16 or next.y>maxi(0,destination.y)+16:continue
			var cost:float=float(costs[cell])+Vector2(direction).length()
			if costs.has(next) and float(costs[next])<=cost:continue
			var at:Vector3=points[cell];var to:=origin+Vector3(next.x*SPACING,0,next.y*SPACING)
			var height:=support(actor,to)
			if not is_finite(height) or absf(height-at.y)>.30:continue
			to.y=height
			query.transform=shape.global_transform;query.transform.origin=to+relative+Vector3.UP*.15;query.motion=Vector3.ZERO
			if not space.intersect_shape(query,1).is_empty():continue
			query.transform.origin=at+relative+Vector3.UP*.15;query.motion=to-at
			if space.cast_motion(query)[0]<.99:continue
			# A sweep can ignore a shape already touching the starting capsule.
			# Check intermediate occupancy too, so a grid edge cannot jump a post.
			var clear:=true
			var slices:=ceili(at.distance_to(to)/.20)
			query.motion=Vector3.ZERO
			for slice_index in range(1,slices):
				query.transform.origin=at.lerp(to,float(slice_index)/slices)+relative+Vector3.UP*.15
				if not space.intersect_shape(query,1).is_empty():clear=false;break
			if not clear:continue
			costs[next]=cost;parents[next]=cell;points[next]=to
			if not pending.has(next):pending.append(next)
	return []
