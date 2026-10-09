extends RefCounted
## CPU-only inputs for SurfaceTool: avoid uploading then reading back every box.
## Used only for static scenery merging; never assigned to a rendered node.
static var box_template: Array = []
static var imported: Dictionary = {}
const CACHE_LIMIT := 96

class SurfaceSource extends Mesh:
	var arrays: Array
	var primitive: int = Mesh.PRIMITIVE_TRIANGLES
	func _get_surface_count() -> int: return 1
	func _surface_get_arrays(_index: int) -> Array: return arrays
	func _surface_get_primitive_type(_index: int) -> int: return primitive
	func _get_aabb() -> AABB: return AABB()
	func _get_blend_shape_count() -> int: return 0
	func _get_blend_shape_name(_index: int) -> StringName: return &""
	func _set_blend_shape_name(_index: int, _name: StringName) -> void: pass
	func _surface_get_array_len(_index: int) -> int: return arrays[Mesh.ARRAY_VERTEX].size()
	func _surface_get_array_index_len(_index: int) -> int:
		return arrays[Mesh.ARRAY_INDEX].size() if arrays[Mesh.ARRAY_INDEX] != null else 0
	func _surface_get_blend_shape_arrays(_index: int) -> Array[Array]: return []
	func _surface_get_format(_index: int) -> int: return 0
	func _surface_get_lods(_index: int) -> Dictionary: return {}
	func _surface_get_material(_index: int) -> Material: return null
	func _surface_set_material(_index: int, _material: Material) -> void: pass

static func append(tool: SurfaceTool, mesh: Mesh, surface: int, transform: Transform3D) -> void:
	if mesh is BoxMesh and surface == 0 and not mesh.flip_faces and not mesh.add_uv2 and mesh.subdivide_width == 0 and mesh.subdivide_height == 0 and mesh.subdivide_depth == 0:
		if box_template.is_empty():
			var unit := BoxMesh.new()
			unit.size = Vector3.ONE
			box_template = unit.surface_get_arrays(0)
		var source := SurfaceSource.new()
		source.arrays = box_template.duplicate()
		var points: PackedVector3Array = box_template[Mesh.ARRAY_VERTEX].duplicate()
		for index in points.size(): points[index] *= mesh.size
		source.arrays[Mesh.ARRAY_VERTEX] = points
		tool.append_from(source, 0, transform)
		return
	# Only ArrayMesh exposes surface_get_primitive_type publicly. Saved
	# PrimitiveMesh resources also have a path, but must use the engine path.
	if not mesh is ArrayMesh or mesh.resource_path.is_empty():
		tool.append_from(mesh, surface, transform)
		return
	var key := [mesh, surface]
	if not imported.has(key):
		if imported.size() >= CACHE_LIMIT: imported.erase(imported.keys()[0])
		var source := SurfaceSource.new()
		source.arrays = mesh.surface_get_arrays(surface)
		source.primitive = mesh.surface_get_primitive_type(surface)
		imported[key] = source
	tool.append_from(imported[key], 0, transform)
