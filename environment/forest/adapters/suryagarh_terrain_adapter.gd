extends Node
## Map-specific bridge. The forest generator itself remains portable.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
@export var replace_baked_grass_in_patch: bool = true
var layout = Layout.new()
var _original_grass_batches: Dictionary = {}
var _surface_cache: Dictionary = {}
const Surface = preload("res://world/suryagarh/grass_blades.gd")

func _world_point(x: float, z: float) -> Vector2:
	var origin: Vector3 = get_parent().global_position
	return Vector2(origin.x + x, origin.z + z)

func _surface_frame(p: Vector2) -> Transform3D:
	var cell := Vector2i(((p + Vector2.ONE * Layout.HALF) / Layout.TILE).floor())
	if not _surface_cache.has(cell):
		var tile := get_node_or_null("../../Landscape/TerrainTiles/Terrain_%02d_%02d" % [cell.x, cell.y]) as MeshInstance3D
		if tile != null and tile.mesh != null:
			var vertices: PackedVector3Array = tile.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			var step := vertices[1].x - vertices[0].x
			_surface_cache[cell] = {"vertices": vertices, "step": step, "origin": Vector2(tile.global_position.x, tile.global_position.z)}
		else:
			_surface_cache[cell] = {}
	var cached: Dictionary = _surface_cache[cell]
	if not cached.is_empty():
		return Surface.baked_frame(cached.vertices, cached.origin, p, cached.step, Layout.TILE)
	return Transform3D(Basis.IDENTITY, Vector3(p.x, layout.height(p.x, p.y), p.y))

func sample_forest_height(x: float, z: float) -> float:
	return _surface_frame(_world_point(x, z)).origin.y - get_parent().global_position.y

func sample_forest_normal(x: float, z: float) -> Vector3:
	var frame := _surface_frame(_world_point(x, z))
	return frame.basis.z.cross(frame.basis.x).normalized()

func sample_forest_biome_mask(x: float, z: float) -> float:
	var p := _world_point(x, z)
	if layout.built_area(p.x, p.y): return 0.0
	var road := smoothstep(6.0, 16.0, layout.road_distance(p.x, p.y))
	var plot := smoothstep(15.0, 40.0, layout.plot_clearance(p.x, p.y))
	var field := 1.0 - layout.field_mask(p.x, p.y)
	return road * plot * field

func sample_forest_existing_tree_points() -> PackedVector2Array:
	var result := PackedVector2Array()
	var landscape := get_node_or_null("../../Landscape")
	if landscape == null: return result
	var nature := landscape.get_node_or_null("NatureTiles")
	if nature == null: return result
	var origin: Vector3 = get_parent().global_position
	var size: Vector2 = get_parent().forest_size
	for tile in nature.get_children():
		if absf(tile.global_position.x - origin.x) > 190.0 or absf(tile.global_position.z - origin.z) > 190.0: continue
		for body in tile.get_children():
			if not body is StaticBody3D: continue
			var collision: CollisionShape3D
			for child in body.get_children():
				if child is CollisionShape3D:
					collision = child
					break
			if collision == null or not collision.shape is CylinderShape3D: continue
			var p: Vector3 = body.global_position
			var local := Vector2(p.x - origin.x, p.z - origin.z)
			if absf(local.x) < size.x * 0.5 + 5.0 and absf(local.y) < size.y * 0.5 + 5.0:
				result.append(local)
	return result

func _restore_grass() -> void:
	for batch in _original_grass_batches:
		if is_instance_valid(batch): batch.multimesh = _original_grass_batches[batch]

func _exit_tree() -> void:
	_restore_grass()

func prepare_forest_area() -> void:
	var provider: Script = get_parent().startup_provider
	_surface_cache.clear()
	_restore_grass()
	if not replace_baked_grass_in_patch:
		get_parent().set_meta("replaced_baked_grass_instances", 0)
		return
	var landscape := get_node_or_null("../../Landscape")
	if landscape == null: return
	var containers: Array[Node] = []
	for container_name in ["NatureTiles", "TerrainTiles"]:
		var container := landscape.get_node_or_null(container_name)
		if container != null: containers.append_array(container.get_children())
	var center: Vector3 = get_parent().global_position
	var size: Vector2 = get_parent().forest_size
	var removed := 0
	for tile in containers:
		if absf(tile.global_position.x - center.x) > 190.0 or absf(tile.global_position.z - center.z) > 190.0: continue
		for batch in tile.get_children():
			if provider != null: await provider.checkpoint(self, "Preparing the countryside’s grass…")
			if not batch is MultiMeshInstance3D or not batch.name.begins_with("Grass"): continue
			if not _original_grass_batches.has(batch): _original_grass_batches[batch] = batch.multimesh
			var original: MultiMesh = _original_grass_batches[batch]
			var source := original.buffer
			var retained := PackedFloat32Array()
			# Preserve the living-world colour/custom-data channels as well as transforms.
			var stride := 12
			if original.use_colors: stride += 4
			if original.use_custom_data: stride += 4
			if source.size() != original.instance_count * stride: continue
			for i in original.instance_count:
				if i % 256 == 0 and provider != null: await provider.checkpoint(self, "Preparing the countryside’s grass…")
				var offset := i * stride
				var local := Vector3(source[offset + 3], source[offset + 7], source[offset + 11])
				var world_point: Vector3 = batch.global_transform * local
				if absf(world_point.x - center.x) < size.x * 0.5 and absf(world_point.z - center.z) < size.y * 0.5:
					removed += 1
					continue
				retained.append_array(source.slice(offset, offset + stride))
			if retained.size() == source.size(): continue
			var replacement := MultiMesh.new()
			replacement.transform_format = MultiMesh.TRANSFORM_3D
			replacement.mesh = original.mesh
			replacement.use_colors = original.use_colors
			replacement.use_custom_data = original.use_custom_data
			replacement.instance_count = int(retained.size() / stride)
			replacement.buffer = retained
			batch.multimesh = replacement
	get_parent().set_meta("replaced_baked_grass_instances", removed)
