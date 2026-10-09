@tool
extends EditorScenePostImportPlugin
## Runs before Godot creates LODs/shadow meshes, with source arrays still editable.
## Only assets opting out of the built-in tangent pass use this workaround.

func _pre_process(scene: Node) -> void:
	if bool(get_option_value("meshes/ensure_tangents")):
		return
	var replacements: Dictionary = {}
	_fill_meshes(scene, replacements)

func _fill_meshes(node: Node, replacements: Dictionary) -> void:
	if node is ImporterMeshInstance3D and node.mesh != null:
		var original: ImporterMesh = node.mesh
		if not replacements.has(original):
			replacements[original] = with_tangents(original)
		node.mesh = replacements[original]
	for child in node.get_children():
		_fill_meshes(child, replacements)

static func tangent_array(arrays: Array, primitive: int) -> PackedFloat32Array:
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs = arrays[Mesh.ARRAY_TEX_UV]
	if uvs != null and uvs.size() == normals.size() and primitive == Mesh.PRIMITIVE_TRIANGLES:
		var tool := SurfaceTool.new()
		tool.create_from_arrays(arrays, primitive)
		var bones = arrays[Mesh.ARRAY_BONES]
		if bones != null and bones.size() == normals.size() * 8:
			tool.set_skin_weight_count(SurfaceTool.SKIN_8_WEIGHTS)
		tool.generate_tangents()
		var generated: Array = tool.commit_to_arrays()
		# Copy tangents alone: never reindex vertices, weights or morph targets.
		assert(generated[Mesh.ARRAY_VERTEX] == arrays[Mesh.ARRAY_VERTEX])
		assert(generated[Mesh.ARRAY_INDEX] == arrays[Mesh.ARRAY_INDEX])
		var result: PackedFloat32Array = generated[Mesh.ARRAY_TANGENT]
		# MikkTSpace assumes unit normals. Some source morph normals are not unit
		# length; orthogonalize the frame without changing those source normals.
		for index in normals.size():
			var normal := normals[index].normalized()
			var tangent := Vector3(result[index * 4], result[index * 4 + 1], result[index * 4 + 2])
			tangent = (tangent - normal * tangent.dot(normal)).normalized()
			if tangent.is_zero_approx():
				var axis := Vector3.RIGHT if absf(normal.dot(Vector3.UP)) > 0.99 else Vector3.UP
				tangent = axis.cross(normal).normalized()
			result[index * 4] = tangent.x
			result[index * 4 + 1] = tangent.y
			result[index * 4 + 2] = tangent.z
		return result
	# Untextured geometry needs only a stable orthonormal frame. No UVs invented.
	var result := PackedFloat32Array()
	result.resize(normals.size() * 4)
	for index in normals.size():
		var normal := normals[index].normalized()
		var axis := Vector3.RIGHT if absf(normal.dot(Vector3.UP)) > 0.99 else Vector3.UP
		var tangent := axis.cross(normal).normalized()
		result[index * 4] = tangent.x
		result[index * 4 + 1] = tangent.y
		result[index * 4 + 2] = tangent.z
		result[index * 4 + 3] = 1.0
	return result

static func with_tangents(original: ImporterMesh) -> ImporterMesh:
	var result := ImporterMesh.new()
	result.resource_name = original.resource_name
	result.set_blend_shape_mode(original.get_blend_shape_mode())
	for index in original.get_blend_shape_count():
		result.add_blend_shape(original.get_blend_shape_name(index))
	for surface in original.get_surface_count():
		var arrays := original.get_surface_arrays(surface)
		var primitive := original.get_surface_primitive_type(surface)
		var normals = arrays[Mesh.ARRAY_NORMAL]
		var missing: bool = normals != null and (arrays[Mesh.ARRAY_TANGENT] == null or arrays[Mesh.ARRAY_TANGENT].is_empty())
		if missing:
			arrays[Mesh.ARRAY_TANGENT] = tangent_array(arrays, primitive)
		var shapes: Array[Array] = []
		for shape in original.get_blend_shape_count():
			var morph := original.get_surface_blend_shape_arrays(surface, shape)
			if missing:
				var posed := arrays.duplicate()
				posed[Mesh.ARRAY_VERTEX] = morph[Mesh.ARRAY_VERTEX]
				posed[Mesh.ARRAY_NORMAL] = morph[Mesh.ARRAY_NORMAL]
				morph[Mesh.ARRAY_TANGENT] = tangent_array(posed, primitive)
			shapes.append(morph)
		var lods: Dictionary = {}
		for lod in original.get_surface_lod_count(surface):
			lods[original.get_surface_lod_size(surface, lod)] = original.get_surface_lod_indices(surface, lod)
		result.add_surface(primitive, arrays, shapes, lods, original.get_surface_material(surface), original.get_surface_name(surface), original.get_surface_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
	return result
