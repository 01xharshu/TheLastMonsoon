extends RefCounted
## Discover usable architectural edges from nearby visible meshes, in wall space.
## No grips on blank wall faces or clothing; the source must be static architecture.
const FEATURES := ["ledge","sill","beam","coping","cornice","balcony","lintel","roof","header"]
var cached_owner: Node
var cached_meshes: Array[MeshInstance3D] = []

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
		for mesh in owner.find_children("*","MeshInstance3D",true,false):
			if cached_meshes.size() >= 1500: break
			var label: String = (str(mesh.name)+" "+str(mesh.get_parent().name)).to_lower()
			for feature in FEATURES:
				if feature in label:
					cached_meshes.append(mesh)
					break
	var normal: Vector3 = Vector3(hit.normal.x,0,hit.normal.z).normalized()
	var tangent := Vector3.UP.cross(normal).normalized()
	var layers: Array[Vector3] = []
	for mesh in cached_meshes:
		if not is_instance_valid(mesh) or mesh.mesh == null or not mesh.is_visible_in_tree(): continue
		var bounds := mesh.get_aabb()
		var low := Vector3(INF,INF,INF)
		var high := Vector3(-INF,-INF,-INF)
		for corner in 8:
			var world: Vector3 = mesh.to_global(bounds.get_endpoint(corner))-hit.position
			var p := Vector3(world.dot(normal),world.y,world.dot(tangent))
			low = low.min(p)
			high = high.max(p)
		if high.y-low.y > .60 or high.z-low.z < .62: continue
		if high.x < -.12 or high.x > 1.20: continue
		var along: float = (actor.global_position-hit.position).dot(tangent)
		if along < low.z-1.0 or along > high.z+1.0: continue
		along = clampf(along,low.z+.30,high.z-.30)
		var grip: Vector3 = hit.position+normal*high.x+tangent*along+Vector3.UP*(high.y+.03)
		if grip.y < actor.global_position.y-.8 or grip.y > actor.global_position.y+35: continue
		var duplicate := false
		for existing in layers:
			if existing.distance_to(grip)<.15: duplicate = true; break
		if not duplicate: layers.append(grip)
	layers.sort_custom(func(a: Vector3,b: Vector3): return a.y < b.y)
	if OS.get_cmdline_user_args().has("--debug-opportunities"): print("OPPORTUNITIES meshes=",cached_meshes.size()," layers=",layers)
	# Find a real supported platform rather than assuming the highest decoration is a roof.
	var space := actor.get_world_3d().direct_space_state
	for index in range(layers.size()-1,-1,-1):
		var lip := layers[index]
		for depth in [.65,.90,1.20]:
			var landing: Vector3 = lip-normal*depth
			var ray := PhysicsRayQueryParameters3D.create(landing+Vector3.UP*.20,landing-Vector3.UP*.35)
			ray.exclude = [actor.get_rid()]
			var support := space.intersect_ray(ray)
			if support.is_empty() or support.normal.y < .7: continue
			landing.y = support.position.y+.94
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = actor.get_node("CollisionShape3D").shape
			query.transform = Transform3D(Basis.IDENTITY,landing)
			query.exclude = [actor.get_rid()]
			query.collision_mask = actor.collision_mask
			if not space.intersect_shape(query,1).is_empty(): continue
			layers.resize(index+1)
			return {"layers":layers,"top":support.position.y,"landing":landing}
	return {}
