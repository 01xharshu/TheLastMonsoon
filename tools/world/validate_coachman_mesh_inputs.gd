extends SceneTree
## CPU source-cache regression, no rendered human placeholders or captures.
const Inputs = preload("res://vehicles/coachman_mesh_inputs.gd")
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func owner_world() -> Node:
	var world := Node.new()
	root.add_child(world)
	var clock := Node.new(); clock.name = "GameTimeSystem"; world.add_child(clock)
	return world
func run() -> void:
	var world := owner_world()
	var source: Array = []; source.resize(Mesh.ARRAY_MAX)
	source[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, source)
	var path := "user://coachman_mesh_input_fixture.res"
	check(ResourceSaver.save(mesh, path) == OK, "fixture save failed")
	var imported := ResourceLoader.load(path, "ArrayMesh", ResourceLoader.CACHE_MODE_IGNORE) as ArrayMesh
	var expected := imported.surface_get_arrays(0)
	var first := Inputs.arrays(imported, 0, world)
	check(first == expected, "cache changed source arrays")
	check(Inputs.arrays(imported, 0, world) == expected, "repeat read changed source arrays")
	check(world.get_meta("coachman_mesh_readbacks", 0) == 1, "shared source was read repeatedly")
	first[Mesh.ARRAY_VERTEX][0] = Vector3(8, 9, 10)
	first[Mesh.ARRAY_INDEX] = PackedInt32Array([2, 1, 0])
	check(Inputs.arrays(imported, 0, world) == expected, "caller mutation damaged cache")
	var reloaded := ResourceLoader.load(path, "ArrayMesh", ResourceLoader.CACHE_MODE_IGNORE) as ArrayMesh
	check(Inputs.arrays(reloaded, 0, world) == expected, "new mesh instance reused stale input")
	check(world.get_meta("coachman_mesh_readbacks", 0) == 2, "resource identity was not respected")
	var other_world := owner_world()
	check(Inputs.arrays(imported, 0, other_world) == expected, "second world changed source")
	check(other_world.get_meta("coachman_mesh_readbacks", 0) == 1, "cache escaped owning world")
	check(Inputs.arrays(mesh, 0, world) == mesh.surface_get_arrays(0), "procedural source changed")
	mesh.clear_surfaces(); source[Mesh.ARRAY_VERTEX][1] = Vector3(2, 0, 0)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, source)
	check(Inputs.arrays(mesh, 0, world) == mesh.surface_get_arrays(0), "procedural source was cached")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("COACHMAN MESH INPUTS ", "PASS" if failures.is_empty() else "FAIL", " ", failures)
	quit(0 if failures.is_empty() else 1)
