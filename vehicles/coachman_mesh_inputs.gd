extends RefCounted
## Imported driver sources are immutable and shared across carriages. Keep their
## CPU inputs in the owning world rather than reading the uploaded mesh per driver.
const World = preload("res://systems/world_context.gd")
const CACHE_KEY := &"coachman_mesh_cpu_inputs"

static func arrays(mesh: Mesh, surface: int, owner: Node) -> Array:
	# Procedural fitting meshes change during construction; always read them fresh.
	if not mesh is ArrayMesh or mesh.resource_path.is_empty():
		return mesh.surface_get_arrays(surface)
	var world := World.find_world(owner)
	if world == null: return mesh.surface_get_arrays(surface)
	var cache: Dictionary = world.get_meta(CACHE_KEY, {})
	var key := [mesh, surface]
	if not cache.has(key):
		cache[key] = mesh.surface_get_arrays(surface)
		world.set_meta(CACHE_KEY, cache)
		world.set_meta("coachman_mesh_readbacks", int(world.get_meta("coachman_mesh_readbacks", 0)) + 1)
	# Mesh slots contain packed arrays. Duplicate each payload explicitly: a
	# caller's nested vertex assignment must not mutate the retained source.
	var copy: Array = cache[key].duplicate()
	for index in copy.size():
		if copy[index] != null: copy[index] = copy[index].duplicate()
	return copy
