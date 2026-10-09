extends Node
## Map-specific bridge. The forest generator itself remains portable.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
@export var replace_baked_grass_in_patch: bool = true
var layout = Layout.new()
var _original_grass_batches: Dictionary = {}

func _world_point(x: float, z: float) -> Vector2:
	var origin: Vector3 = get_parent().global_position
	return Vector2(origin.x + x, origin.z + z)

func sample_forest_height(x: float, z: float) -> float:
	var p := _world_point(x, z)
	return layout.height(p.x, p.y) - get_parent().global_position.y

func sample_forest_normal(x: float, z: float) -> Vector3:
	var p := _world_point(x, z)
	return layout.normal(p.x, p.y)

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

func prepare_forest_area() -> void:
	for batch in _original_grass_batches:
		if is_instance_valid(batch): batch.multimesh = _original_grass_batches[batch]
	if not replace_baked_grass_in_patch:
		get_parent().set_meta("replaced_baked_grass_instances", 0)
		return
	var landscape := get_node_or_null("../../Landscape")
	if landscape == null: return
	var nature := landscape.get_node_or_null("NatureTiles")
	if nature == null: return
	var center: Vector3 = get_parent().global_position
	var size: Vector2 = get_parent().forest_size
	var removed := 0
	for tile in nature.get_children():
		if absf(tile.global_position.x - center.x) > 190.0 or absf(tile.global_position.z - center.z) > 190.0: continue
		for batch in tile.get_children():
			if not batch is MultiMeshInstance3D or not batch.name.begins_with("Grass_"): continue
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
