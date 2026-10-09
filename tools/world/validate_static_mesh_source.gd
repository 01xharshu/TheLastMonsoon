extends SceneTree
const Source = preload("res://systems/static_mesh_source.gd")
var failures: Array[String] = []
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func _run() -> void:
	var meshes: Array[Mesh] = []
	for size in [Vector3(.13,2.8,.13),Vector3(20,.24,12),Vector3(10.8,.22,14),Vector3.ONE]:
		var mesh := BoxMesh.new()
		mesh.size = size
		meshes.append(mesh)
	var subdivided := BoxMesh.new()
	subdivided.subdivide_width = 2
	meshes.append(subdivided)
	# A nonempty path reproduced the editor crash on saved CylinderMesh.
	for primitive in [CylinderMesh.new(), SphereMesh.new(), BoxMesh.new()]:
		primitive.resource_path = "res://__static_mesh_regression_%s.tres" % primitive.get_class()
		if primitive is BoxMesh: primitive.subdivide_width = 2
		meshes.append(primitive)
	var sphere := SphereMesh.new()
	meshes.append(sphere)
	var tree: Node3D = load("res://environment/vegetation/mango_tree/mango_tree_01.glb").instantiate()
	for node in tree.find_children("*", "MeshInstance3D", true, false): meshes.append(node.mesh)
	for mesh in meshes:
		for surface in mesh.get_surface_count():
			for basis in [Basis.IDENTITY,Basis(Vector3.UP,.37),Basis(Vector3.RIGHT,-.25).scaled(Vector3(.7,1.3,1.1))]:
				var original := SurfaceTool.new()
				var cached := SurfaceTool.new()
				original.begin(Mesh.PRIMITIVE_TRIANGLES)
				cached.begin(Mesh.PRIMITIVE_TRIANGLES)
				var transform := Transform3D(basis,Vector3(-13,.24,4))
				# Append twice to verify offset indices and mixed append behavior.
				for repetition in 2:
					original.append_from(mesh,surface,transform)
					Source.append(cached,mesh,surface,transform)
				var expected := original.commit_to_arrays()
				var actual := cached.commit_to_arrays()
				for field in Mesh.ARRAY_MAX:
					check(expected[field] == actual[field],"Static mesh differs in field %s for %s" % [field,mesh])
	tree.free()
	print("STATIC MESH SOURCE ",JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","failures":failures}))
	root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)
