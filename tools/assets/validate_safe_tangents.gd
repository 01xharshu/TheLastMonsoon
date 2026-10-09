extends SceneTree
## Assert that selective tangent import preserves all source geometry and morphs.
const Tangents = preload("res://addons/safe_mesh_tangents/tangent_importer.gd")
var assets: Array[String] = []
var failed := false
var failures: Dictionary = {}
var surfaces := 0
var morphs := 0

func require(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		if not failures.has(message):
			failures[message] = true
			push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	# Discover opt-out assets instead of keeping a list that misses new exports.
	for folder in ["res://characters", "res://assets", "res://environment"]:
		find_safe_imports(folder)
	assets.sort()
	require(not assets.is_empty(), "Safe tangent import assets discovered")
	for path in assets:
		var state := GLTFState.new()
		var document := GLTFDocument.new()
		require(document.append_from_file(path, state, 0) == OK, path + " parses")
		for gltf_mesh in state.get_meshes():
			var original: ImporterMesh = gltf_mesh.mesh
			var repaired := Tangents.with_tangents(original)
			require(original.get_surface_count() == repaired.get_surface_count(), "surface count")
			require(original.get_blend_shape_count() == repaired.get_blend_shape_count(), "morph count")
			for surface in original.get_surface_count():
				surfaces += 1
				var before := original.get_surface_arrays(surface)
				var after := repaired.get_surface_arrays(surface)
				compare_arrays(before, after)
				require(original.get_surface_material(surface) == repaired.get_surface_material(surface), "material preserved")
				for shape in original.get_blend_shape_count():
					morphs += 1
					require(original.get_blend_shape_name(shape) == repaired.get_blend_shape_name(shape), "morph name")
					compare_arrays(original.get_surface_blend_shape_arrays(surface, shape), repaired.get_surface_blend_shape_arrays(surface, shape))
		var instance: Node = load(path).instantiate()
		check_imported(instance)
		instance.free()
	print("SAFE TANGENTS ", "FAIL" if failed else "PASS", " | assets=", assets.size(), " surfaces=", surfaces, " morph surfaces=", morphs)
	var save_manager := root.get_node_or_null("SaveManager")
	if save_manager != null:
		save_manager.quit_game(1 if failed else 0)
	else:
		quit(1 if failed else 0)

func find_safe_imports(folder: String) -> void:
	var directory := DirAccess.open(folder)
	if directory == null:
		return
	for child in directory.get_directories():
		if not child.begins_with("."):
			find_safe_imports(folder.path_join(child))
	for file in directory.get_files():
		if not file.ends_with(".glb"):
			continue
		var path := folder.path_join(file)
		var settings := ConfigFile.new()
		if settings.load(path + ".import") == OK and not bool(settings.get_value("params", "meshes/ensure_tangents", true)):
			assets.append(path)

func compare_arrays(before: Array, after: Array) -> void:
	for attribute in Mesh.ARRAY_MAX:
		if attribute != Mesh.ARRAY_TANGENT:
			require(before[attribute] == after[attribute], "Source attribute preserved: " + str(attribute))
	var normals = after[Mesh.ARRAY_NORMAL]
	if normals == null or normals.is_empty():
		return
	var tangents: PackedFloat32Array = after[Mesh.ARRAY_TANGENT]
	require(tangents.size() == normals.size() * 4, "One tangent per normal")
	for index in normals.size():
		var tangent := Vector3(tangents[index * 4], tangents[index * 4 + 1], tangents[index * 4 + 2])
		require(tangent.is_finite() and absf(tangent.dot(normals[index])) < 0.001, "Finite perpendicular tangent")

func check_imported(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for surface in node.mesh.get_surface_count():
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			if arrays[Mesh.ARRAY_NORMAL] != null:
				require(arrays[Mesh.ARRAY_TANGENT] != null and not arrays[Mesh.ARRAY_TANGENT].is_empty(), "Imported tangent present: " + str(node.name))
	for child in node.get_children():
		check_imported(child)
