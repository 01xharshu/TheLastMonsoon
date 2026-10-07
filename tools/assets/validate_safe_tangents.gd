extends SceneTree
## Assert that selective tangent import preserves all source geometry and morphs.
const Tangents = preload("res://addons/safe_mesh_tangents/tangent_importer.gd")
const ASSETS := [
	"res://characters/npcs/british/corporal_woman.glb",
	"res://characters/npcs/british/sergeant_woman.glb",
	"res://characters/npcs/british/private_woman.glb",
	"res://characters/npcs/british/candidates/corporal_woman_skirt_candidate.glb",
	"res://characters/npcs/british/candidates/sergeant_woman_skirt_candidate.glb",
	"res://characters/npcs/british/candidates/private_woman_skirt_candidate.glb",
	"res://characters/npcs/motion/river_woman/river_woman_rigged_candidate.glb",
	"res://characters/npcs/motion/errand_passenger/errand_passenger.glb",
	"res://characters/npcs/motion/village_farmer/village_farmer_rigged_candidate.glb",
	"res://characters/npcs/motion/boatman/boatman_rigged_candidate.glb",
	"res://characters/npcs/motion/village_woman/village_woman_rigged_candidate.glb",
]
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
	for path in ASSETS:
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
	print("SAFE TANGENTS ", "FAIL" if failed else "PASS", " | assets=", ASSETS.size(), " surfaces=", surfaces, " morph surfaces=", morphs)
	var save_manager := root.get_node_or_null("SaveManager")
	if save_manager != null:
		save_manager.quit_game(1 if failed else 0)
	else:
		quit(1 if failed else 0)

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
