extends RefCounted
## Lower woody trunk profiles, shared by saved and runtime instanced broadleaf trees.
const Startup = preload("res://systems/world_startup.gd")
const TERRAIN_SUPPORT_LAYER := 1 << 30

static func configure_terrain_support(node: Node) -> void:
	# This is exactly the old allowed set: GroundCollision bodies only.
	# Keep layer 1 intact for gameplay; a spare layer avoids thousands of excludes.
	var world := node
	while world.get_parent() != null and world.get_parent() != node.get_tree().root:
		world = world.get_parent()
	if world.has_meta("terrain_support_configured"): return
	var terrain_rids: Array[RID] = []
	for body in world.find_children("*", "CollisionObject3D", true, false):
		if body.name == "GroundCollision":
			body.collision_layer |= TERRAIN_SUPPORT_LAYER
			terrain_rids.append(body.get_rid())
	world.set_meta("terrain_support_rids", terrain_rids)
	world.set_meta("terrain_support_cache", {"rids":terrain_rids,"revision":0})
	world.set_meta("terrain_support_configured", true)

static func terrain_exclusions(node: Node) -> Array[RID]:
	configure_terrain_support(node)
	var world := node
	while world.get_parent() != null and world.get_parent() != node.get_tree().root:
		world = world.get_parent()
	var result: Array[RID] = world.get_meta("terrain_support_rids", [])
	return result

static func terrain_cache(node: Node) -> Dictionary:
	configure_terrain_support(node)
	var world := node
	while world.get_parent() != null and world.get_parent() != node.get_tree().root:
		world = world.get_parent()
	return world.get_meta("terrain_support_cache")

static func register_terrain_support(node: Node, body: CollisionObject3D) -> void:
	# Runtime terrain additions must update the existing shared support set.
	var cache := terrain_cache(node)
	var rids: Array[RID] = cache.rids
	body.collision_layer |= TERRAIN_SUPPORT_LAYER
	if not rids.has(body.get_rid()):
		rids.append(body.get_rid())
		cache.revision += 1

static func unregister_terrain_support(node: Node, body: CollisionObject3D) -> void:
	# Call before removing/freeing a terrain body; do not leave stale RIDs.
	var cache := terrain_cache(node)
	if cache.rids.has(body.get_rid()):
		cache.rids.erase(body.get_rid())
		cache.revision += 1

static func copy_instances(source: MultiMesh) -> MultiMesh:
	# Allocate the destination layout before assigning packed instance data.
	# Resource.duplicate can otherwise assign buffer before instance_count.
	var copy := MultiMesh.new()
	copy.transform_format = source.transform_format
	copy.use_colors = source.use_colors
	copy.use_custom_data = source.use_custom_data
	copy.mesh = source.mesh
	copy.instance_count = source.instance_count
	copy.visible_instance_count = source.visible_instance_count
	copy.custom_aabb = source.custom_aabb
	copy.physics_interpolation_quality = source.physics_interpolation_quality
	var stride := 12 if source.transform_format == MultiMesh.TRANSFORM_3D else 8
	if source.use_colors: stride += 4
	if source.use_custom_data: stride += 4
	var buffer := source.buffer
	if buffer.size() == source.instance_count * stride:
		copy.buffer = buffer
	else:
		# Some headless storage backends do not expose packed GPU buffers.
		for index in source.instance_count:
			if source.transform_format == MultiMesh.TRANSFORM_3D:
				copy.set_instance_transform(index,source.get_instance_transform(index))
			else:
				copy.set_instance_transform_2d(index,source.get_instance_transform_2d(index))
			if source.use_colors: copy.set_instance_color(index,source.get_instance_color(index))
			if source.use_custom_data: copy.set_instance_custom_data(index,source.get_instance_custom_data(index))
	for key in source.get_meta_list(): copy.set_meta(key,source.get_meta(key))
	return copy

static func instance_transforms(source: MultiMesh) -> Array[Transform3D]:
	var result: Array[Transform3D] = []
	var stride := 12 + (4 if source.use_colors else 0) + (4 if source.use_custom_data else 0)
	var buffer := source.buffer
	if source.transform_format != MultiMesh.TRANSFORM_3D or buffer.size() != source.instance_count * stride:
		for index in source.instance_count: result.append(source.get_instance_transform(index))
		return result
	for index in source.instance_count:
		var offset := index*stride
		result.append(Transform3D(Basis(
			Vector3(buffer[offset],buffer[offset+4],buffer[offset+8]),
			Vector3(buffer[offset+1],buffer[offset+5],buffer[offset+9]),
			Vector3(buffer[offset+2],buffer[offset+6],buffer[offset+10])),
			Vector3(buffer[offset+3],buffer[offset+7],buffer[offset+11])))
	return result

static func profile(mesh: Mesh) -> Array[Dictionary]:
	var bounds := mesh.get_aabb()
	var height := minf(1.2,bounds.size.y*.36)
	var result: Array[Dictionary] = []
	for band in 3:
		var bottom: float = bounds.position.y+height*float(band)/3.0
		var top: float = bounds.position.y+height*float(band+1)/3.0
		var points: Array[Vector3] = []
		var low := Vector3(INF,INF,INF)
		var high := Vector3(-INF,-INF,-INF)
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface)
			var label := material.resource_name.to_lower() if material else ""
			if "leav" in label or "branch" in label: continue
			for point: Vector3 in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				if point.y < bottom-.02 or point.y > top+.02: continue
				points.append(point)
				low = low.min(point)
				high = high.max(point)
		if points.is_empty(): continue
		var centre := (low+high)*.5
		centre.y = (bottom+top)*.5
		var radius := .0
		for point in points: radius = maxf(radius,Vector2(point.x-centre.x,point.z-centre.z).length())
		result.append({"centre":centre,"radius":radius,"height":top-bottom})
	return result

static func add_batch(parent: Node3D, transforms: Array[Transform3D], segments: Array[Dictionary], label: String = "SolidTreeTrunks") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.set_meta("tree_trunk_geometry",true)
	parent.add_child(body)
	var shapes: Dictionary = {}
	for tree in transforms:
		var size := tree.basis.get_scale()
		if is_zero_approx(tree.basis.determinant()): continue
		for segment in segments:
			var radius: float = segment.radius*maxf(size.x,size.z)
			var height: float = segment.height*size.y+.015
			var key := Vector2(snappedf(radius,.01),snappedf(height,.01))
			if not shapes.has(key):
				var cylinder := CylinderShape3D.new()
				cylinder.radius = radius
				cylinder.height = height
				shapes[key] = cylinder
			var collision := CollisionShape3D.new()
			collision.shape = shapes[key]
			collision.position = tree*segment.centre
			body.add_child(collision)
	body.set_meta("tree_count",transforms.size())
	return body

static func repair_landscape(landscape: Node3D) -> int:
	var nature := landscape.get_node_or_null("NatureTiles")
	if nature == null: return 0
	var repaired := 0
	var adjusted_roots := 0
	var profiles: Dictionary = {}
	configure_terrain_support(landscape)
	var terrain_ray := PhysicsRayQueryParameters3D.new()
	terrain_ray.collision_mask = TERRAIN_SUPPORT_LAYER
	var space := landscape.get_world_3d().direct_space_state
	for candidate in nature.find_children("*","MultiMeshInstance3D",true,false):
		await Startup.checkpoint(landscape, "Preparing the landscape’s tree roots…")
		var batch := candidate as MultiMeshInstance3D
		if not ("BroadleafTrees" in str(batch.name)): continue
		var parent := batch.get_parent() as Node3D
		var label := str(batch.name)+"SolidTrunks"
		if parent.get_node_or_null(label) != null: continue
		var mesh_id := batch.multimesh.mesh.get_instance_id()
		if not profiles.has(mesh_id): profiles[mesh_id] = profile(batch.multimesh.mesh)
		var segments: Array[Dictionary] = profiles[mesh_id]
		if segments.is_empty(): continue
		var instances := instance_transforms(batch.multimesh)
		var copy: MultiMesh = copy_instances(batch.multimesh)
		var transforms: Array[Transform3D] = []
		var original_roots: Dictionary = {}
		for index in batch.multimesh.instance_count:
			if index % 16 == 0: await Startup.checkpoint(landscape, "Preparing the landscape’s tree roots…")
			var tree := batch.transform*instances[index]
			if is_zero_approx(tree.basis.determinant()): continue
			# Root support belongs beneath the woody base, not the canopy origin.
			var base: Vector3 = segments[0].centre
			base.y -= float(segments[0].height)*.5
			var world_base := parent.to_global(tree*base)
			terrain_ray.from = world_base+Vector3.UP*50
			terrain_ray.to = world_base-Vector3.UP*50
			var support := space.intersect_ray(terrain_ray)
			if not support.is_empty():
				var shift: float = support.position.y-.12-world_base.y
				if absf(shift) > .02: adjusted_roots += 1
				tree.origin += parent.global_basis.inverse()*Vector3.UP*shift
				copy.set_instance_transform(index,batch.transform.affine_inverse()*tree)
			transforms.append(tree)
			original_roots[Vector2(snappedf(tree.origin.x,.01),snappedf(tree.origin.z,.01))] = true
		# Retire only the old origin-centred cylinders corresponding to this batch.
		for child in parent.get_children():
			if not child is StaticBody3D or child.has_meta("tree_trunk_geometry"): continue
			var key := Vector2(snappedf(child.position.x,.01),snappedf(child.position.z,.01))
			if not original_roots.has(key): continue
			for collider in child.get_children():
				if collider is CollisionShape3D and collider.shape is CylinderShape3D:
					child.collision_layer = 0
					child.queue_free()
					break
		batch.multimesh = copy
		add_batch(parent,transforms,segments,label)
		repaired += transforms.size()
	if repaired > 0: landscape.set_meta("tree_root_adjustments",adjusted_roots)
	return repaired

static func ground_batch(batch: MultiMeshInstance3D, segments: Array[Dictionary], embed: float = .12) -> Array[Transform3D]:
	await Startup.wait_for(batch, "Terrain collision")
	configure_terrain_support(batch)
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = TERRAIN_SUPPORT_LAYER
	var space := batch.get_world_3d().direct_space_state
	var instances := instance_transforms(batch.multimesh)
	var copy: MultiMesh = copy_instances(batch.multimesh)
	var transforms: Array[Transform3D] = []
	for index in copy.instance_count:
		if index % 16 == 0: await Startup.checkpoint(batch, "Preparing the grove’s tree roots…")
		var tree := batch.transform*instances[index]
		if is_zero_approx(tree.basis.determinant()): continue
		var base: Vector3 = segments[0].centre
		base.y -= float(segments[0].height)*.5
		var root := batch.get_parent_node_3d().to_global(tree*base)
		ray.from = root+Vector3.UP*50
		ray.to = root-Vector3.UP*50
		var ground := space.intersect_ray(ray)
		if not ground.is_empty():
			tree.origin += batch.get_parent_node_3d().global_basis.inverse()*Vector3.UP*(ground.position.y-embed-root.y)
			copy.set_instance_transform(index,batch.transform.affine_inverse()*tree)
		transforms.append(tree)
	batch.multimesh = copy
	return transforms
