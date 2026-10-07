extends RefCounted
## Discover usable architectural edges from nearby visible meshes, in wall space.
## No grips on blank wall faces or clothing; the source must be static architecture.
const FEATURES := ["ledge","sill","beam","coping","cornice","balcony","lintel","roof","header","windowrail","windowframerail","windowframe","parapet","eave"]
var cached_owner: Node
var cached_meshes: Array[Dictionary] = []

static func retain_edge(root: Node3D, mesh: MeshInstance3D) -> void:
	var label := (str(mesh.name)+" "+str(mesh.get_parent().name)+" "+str(mesh.get_parent().get_parent().name)).to_lower()
	for feature in FEATURES:
		if feature in label:
			var records: Array = root.get_meta("climb_architecture",[])
			records.append({"label":label,"bounds":mesh.get_aabb(),"transform":root.global_transform.affine_inverse()*mesh.global_transform})
			root.set_meta("climb_architecture",records)
			return

func survey(actor: CharacterBody3D, hit: Dictionary) -> Dictionary:
	if not hit.collider is StaticBody3D: return {}
	var owner: Node = hit.collider.get_parent()
	for step in 3:
		if owner.get_parent() == null or owner.get_parent() == actor.get_tree().current_scene: break
		var label := owner.name.to_lower()
		if "house" in label or "building" in label or "tower" in label or "compound" in label or "hall" in label: break
		owner = owner.get_parent()
	if owner != cached_owner:
		cached_owner = owner
		cached_meshes.clear()
		for record in owner.get_meta("climb_architecture",[]):
			cached_meshes.append({"label":record.label,"bounds":record.bounds,"transform":owner.global_transform*record.transform})
		for mesh in owner.find_children("*","MeshInstance3D",true,false):
			if cached_meshes.size() >= 1500: break
			var label: String = (str(mesh.name)+" "+str(mesh.get_parent().name)+" "+str(mesh.get_parent().get_parent().name)).to_lower()
			for feature in FEATURES:
				if feature in label:
					cached_meshes.append({"label":label,"bounds":mesh.get_aabb(),"transform":mesh.global_transform})
					break
	var normal: Vector3 = Vector3(hit.normal.x,0,hit.normal.z).normalized()
	var tangent := Vector3.UP.cross(normal).normalized()
	var layers: Array[Vector3] = []
	var roof_points: Array[Vector3] = []
	for record in cached_meshes:
		var bounds: AABB = record.bounds
		var transform: Transform3D = record.transform
		var low := Vector3(INF,INF,INF)
		var high := Vector3(-INF,-INF,-INF)
		for corner in 8:
			var world: Vector3 = transform*bounds.get_endpoint(corner)-hit.position
			var p := Vector3(world.dot(normal),world.y,world.dot(tangent))
			low = low.min(p)
			high = high.max(p)
		var is_roof: bool = "roof" in record.label or "parapet" in record.label
		if high.z-low.z < .62: continue
		if high.y-low.y > .60 and not is_roof and not "sill" in record.label: continue
		if high.x < -.12 or high.x > 1.20: continue
		var along: float = (actor.global_position-hit.position).dot(tangent)
		if along < low.z-1.0 or along > high.z+1.0: continue
		along = clampf(along,low.z+.30,high.z-.30)
		var edge_y := high.y
		if is_roof:
			edge_y = -INF
			for corner in 8:
				var vertex: Vector3 = transform*bounds.get_endpoint(corner)-hit.position
				if vertex.dot(normal) >= high.x-.04: edge_y = maxf(edge_y,vertex.y)
		var grip: Vector3 = hit.position+normal*high.x+tangent*along+Vector3.UP*(edge_y+.03)
		if grip.y < actor.global_position.y-.8: continue
		var duplicate := false
		for existing in layers:
			if existing.distance_to(grip)<.15: duplicate = true; break
		if not duplicate:
			layers.append(grip)
			if is_roof: roof_points.append(grip)
	var facade := -INF
	for point in layers:
		if not point in roof_points: facade = maxf(facade,(point-hit.position).dot(normal))
	for index in range(layers.size()-1,-1,-1):
		if not layers[index] in roof_points and (layers[index]-hit.position).dot(normal) < facade-.05: layers.remove_at(index)
	layers.sort_custom(func(a: Vector3,b: Vector3): return a.y < b.y)
	if OS.get_cmdline_user_args().has("--debug-opportunities"): print("OPPORTUNITIES hit=",hit.position," normal=",normal," meshes=",cached_meshes.size()," layers=",layers)
	# Find a real supported platform rather than assuming the highest decoration is a roof.
	var space := actor.get_world_3d().direct_space_state
	for index in range(layers.size()-1,-1,-1):
		var lip := layers[index]
		for depth in [.65,.90,1.20]:
			var landing: Vector3 = lip-normal*depth
			var ray := PhysicsRayQueryParameters3D.create(landing+Vector3.UP*1.4,landing-Vector3.UP*.70)
			ray.exclude = [actor.get_rid()]
			var support := space.intersect_ray(ray)
			if support.is_empty() or support.normal.y < .7: continue
			landing.y = support.position.y+.94+(.12 if support.normal.y < .99 else 0.0)
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = actor.get_node("CollisionShape3D").shape
			query.transform = Transform3D(Basis.IDENTITY,landing)
			query.exclude = [actor.get_rid()]
			query.collision_mask = actor.collision_mask
			if not space.intersect_shape(query,1).is_empty(): continue
			layers.resize(index+1)
			return {"layers":layers,"top":support.position.y,"landing":landing}
	return {}

func side_grip(component: Node, direction: float) -> Dictionary:
	if component.layers.is_empty() or absf(direction) < .5: return {}
	var held: Vector3 = component.layers[component.leap.held_row]
	var tangent: Vector3 = Vector3.UP.cross(component.wall_normal).normalized()
	var target := held+tangent*signf(direction)*.65
	for record in cached_meshes:
		var bounds: AABB = record.bounds
		var transform: Transform3D = record.transform
		var low := INF
		var high := -INF
		var edge_y := -INF
		var front := -INF
		for corner in 8:
			var point: Vector3 = transform*bounds.get_endpoint(corner)
			low = minf(low,point.dot(tangent))
			high = maxf(high,point.dot(tangent))
			edge_y = maxf(edge_y,point.y)
			front = maxf(front,point.dot(component.wall_normal))
		if "roof" in record.label:
			edge_y = -INF
			for corner in 8:
				var vertex: Vector3 = transform*bounds.get_endpoint(corner)
				if vertex.dot(component.wall_normal) >= front-.04: edge_y = maxf(edge_y,vertex.y)
		if absf(edge_y+.03-held.y) > .10 or absf(front-held.dot(component.wall_normal)) > .06: continue
		if target.dot(tangent) < low+.30 or target.dot(tangent) > high-.30: continue
		var landing: Vector3 = component.landing+target-held
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = component.solid.original_shape
		query.transform = Transform3D(Basis.IDENTITY,landing)
		query.exclude = [component.actor.get_rid()]
		query.collision_mask = component.actor.collision_mask
		if not component.actor.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): continue
		return {"point":target}
	return {}
