extends RefCounted
## Share duplicate grass vertex records; retain geometry and bounded normal packing.
static func indexed(source: ArrayMesh, in_place: bool = false) -> ArrayMesh:
	var bounds := source.get_aabb()
	var surfaces: Array = []
	for surface in source.get_surface_count():
		if source.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			return source
		var arrays := source.surface_get_arrays(surface)
		if arrays[Mesh.ARRAY_INDEX] != null and not arrays[Mesh.ARRAY_INDEX].is_empty(): return source
		var reduced := arrays.duplicate(true)
		var attributes: Array[int] = []
		for attribute in Mesh.ARRAY_INDEX:
			if arrays[attribute] == null: continue
			# Grass contains one record per vertex; avoid guessing bone/tangent strides.
			if arrays[attribute].size() != arrays[Mesh.ARRAY_VERTEX].size() * (4 if attribute == Mesh.ARRAY_TANGENT else 1): return source
			attributes.append(attribute)
			reduced[attribute].resize(0)
		var records: Dictionary = {}
		var indices := PackedInt32Array()
		for vertex in arrays[Mesh.ARRAY_VERTEX].size():
			var key: Array = []
			for attribute in attributes:
				var stride := 4 if attribute == Mesh.ARRAY_TANGENT else 1
				for component in stride: key.append(arrays[attribute][vertex * stride + component])
			if not records.has(key):
				records[key] = records.size()
				for attribute in attributes:
					var stride := 4 if attribute == Mesh.ARRAY_TANGENT else 1
					for component in stride: reduced[attribute].append(arrays[attribute][vertex * stride + component])
			indices.append(records[key])
		reduced[Mesh.ARRAY_INDEX] = indices
		surfaces.append([reduced,source.surface_get_material(surface),source.surface_get_name(surface)])
	var result := source if in_place else ArrayMesh.new()
	if in_place: result.clear_surfaces()
	for surface in surfaces:
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,surface[0])
		var index := result.get_surface_count()-1
		result.surface_set_material(index,surface[1])
		result.surface_set_name(index,surface[2])
	result.custom_aabb = bounds
	return result

static func configure_landscape(landscape: Node3D) -> int:
	var nature := landscape.get_node_or_null("NatureTiles")
	if nature == null: return 0
	var meshes: Dictionary = {}
	var changed := 0
	for batch in nature.find_children("Grass*", "MultiMeshInstance3D", true, false):
		var source: ArrayMesh = batch.multimesh.mesh
		# Each landscape has thousands of batches but only a few shared meshes.
		# Update those mesh resources once instead of rebinding every MultiMesh.
		if not meshes.has(source): meshes[source] = indexed(source,true)
		changed += 1
		if changed % 64 == 0:
			await preload("res://systems/world_startup.gd").checkpoint(landscape,"Preparing grass rendering…")
	return changed
