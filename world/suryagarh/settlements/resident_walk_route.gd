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

class Search extends RefCounted:
	var actor_ref: WeakRef
	var goal: Vector3
	var origin: Vector3
	var destination: Vector2i
	var pending: Array[Dictionary]=[]
	var serial:=0
	var attempts:=0
	var done:=false
	var result: Array[Vector3]=[]
	var costs: Dictionary={Vector2i.ZERO:0.0}
	var parents: Dictionary={}
	var points: Dictionary={}
	var query: PhysicsShapeQueryParameters3D
	var relative: Vector3
	var ground_query: Callable
	const SPACING:=.8
	func _init(actor: Node3D, target: Vector3, extra: Array[RID], ground: Callable) -> void:
		ground_query=ground
		actor_ref=weakref(actor);goal=target;origin=actor.global_position
		destination=Vector2i(roundi((goal.x-origin.x)/SPACING),roundi((goal.z-origin.z)/SPACING))
		if absi(destination.x)>90 or absi(destination.y)>90:done=true;return
		points[Vector2i.ZERO]=origin
		var shape: CollisionShape3D=actor.body_collider.get_node("BodyShape")
		query=PhysicsShapeQueryParameters3D.new();query.shape=shape.shape;query.collision_mask=1
		var excluded: Array[RID]=[actor.body_collider.get_rid()];excluded.append_array(extra)
		query.exclude=excluded;query.margin=.02;relative=shape.global_transform.origin-origin
		push(Vector2i.ZERO,0.0)
	func before(a: Dictionary,b: Dictionary) -> bool:
		return a.score<b.score or (a.score==b.score and a.serial<b.serial)
	func push(cell: Vector2i,cost: float) -> void:
		serial+=1
		pending.append({"cell":cell,"cost":cost,"score":cost+Vector2(cell-destination).length(),"serial":serial})
		var i:=pending.size()-1
		while i>0:
			var parent: int=(i-1)/2
			if not before(pending[i],pending[parent]):break
			var swap: Dictionary=pending[i];pending[i]=pending[parent];pending[parent]=swap;i=parent
	func pop() -> Dictionary:
		var first: Dictionary=pending[0]
		var last: Dictionary=pending.pop_back()
		if not pending.is_empty():
			pending[0]=last
			var i:=0
			while i*2+1<pending.size():
				var child:=i*2+1
				if child+1<pending.size() and before(pending[child+1],pending[child]):child+=1
				if not before(pending[child],pending[i]):break
				var swap: Dictionary=pending[i];pending[i]=pending[child];pending[child]=swap;i=child
		return first
	func step() -> void:
		var actor: Node3D=actor_ref.get_ref()
		if not is_instance_valid(actor) or not actor.is_inside_tree() or actor.is_queued_for_deletion() or pending.is_empty() or attempts>=2400:done=true;return
		var entry:=pop();var cell: Vector2i=entry.cell
		if float(entry.cost)>float(costs[cell]):return
		attempts+=1
		if cell==destination:
			result=[goal]
			while cell!=Vector2i.ZERO:result.push_front(points[cell]);cell=parents[cell]
			done=true;return
		var shape: CollisionShape3D=actor.body_collider.get_node("BodyShape")
		var space:=actor.get_world_3d().direct_space_state
		for direction in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1),Vector2i(1,1),Vector2i(-1,1),Vector2i(1,-1),Vector2i(-1,-1)]:
			var next: Vector2i=cell+direction
			if next.x<mini(0,destination.x)-16 or next.x>maxi(0,destination.x)+16 or next.y<mini(0,destination.y)-16 or next.y>maxi(0,destination.y)+16:continue
			var cost:=float(costs[cell])+Vector2(direction).length()
			if costs.has(next) and float(costs[next])<=cost:continue
			var at: Vector3=points[cell];var to:=origin+Vector3(next.x*SPACING,0,next.y*SPACING)
			var height:float=ground_query.call(actor,to)
			if not is_finite(height) or absf(height-at.y)>.30:continue
			to.y=height
			query.transform=shape.global_transform;query.transform.origin=to+relative+Vector3.UP*.15;query.motion=Vector3.ZERO
			if not space.intersect_shape(query,1).is_empty():continue
			query.transform.origin=at+relative+Vector3.UP*.15;query.motion=to-at
			if space.cast_motion(query)[0]<.99:continue
			var clear:=true
			var slices:=ceili(at.distance_to(to)/.20)
			query.motion=Vector3.ZERO
			for slice_index in range(1,slices):
				query.transform.origin=at.lerp(to,float(slice_index)/slices)+relative+Vector3.UP*.15
				if not space.intersect_shape(query,1).is_empty():clear=false;break
			if not clear:continue
			costs[next]=cost;parents[next]=cell;points[next]=to;push(next,cost)

static func find(actor: Node3D,goal: Vector3,extra_excluded: Array[RID]=[]) -> Array[Vector3]:
	var search:=Search.new(actor,goal,extra_excluded,support)
	while not search.done:search.step()
	return search.result

static func find_budgeted(actor: Node3D,goal: Vector3,budget: Node,extra_excluded:Array[RID]=[]) -> Array[Vector3]:
	var search:=Search.new(actor,goal,extra_excluded,support)
	while not search.done:
		if not is_instance_valid(budget) or not budget.is_inside_tree():return []
		if not await budget.checkpoint():return []
		search.step()
	return search.result
