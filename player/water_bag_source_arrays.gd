extends RefCounted
## Immutable stopper inputs remain on the CPU instead of reading uploaded buffers.
const SOURCE := "res://assets/props/household/pouch_stopper.res"
const CACHE_PATH := "res://assets/props/household/pouch_stopper_cpu.res"

static func arrays(mesh: Mesh, surface: int, cache: Resource = null) -> Array:
	if cache == null:
		if not ResourceLoader.exists(CACHE_PATH): return []
		cache = load(CACHE_PATH)
	if cache == null: return []
	if mesh.resource_path != SOURCE or int(cache.get_meta("revision",0)) != 1: return []
	if str(cache.get_meta("source_sha256","")) != FileAccess.get_sha256(SOURCE): return []
	var surfaces: Array = cache.get_meta("surfaces",[])
	if surfaces.size() != mesh.get_surface_count() or surface < 0 or surface >= surfaces.size(): return []
	var data: Array = surfaces[surface]
	if data.size() != Mesh.ARRAY_MAX or not data[Mesh.ARRAY_VERTEX] is PackedVector3Array: return []
	if data[Mesh.ARRAY_VERTEX].size() != mesh.surface_get_array_len(surface): return []
	var copy := data.duplicate()
	for index in copy.size():
		if copy[index] != null: copy[index] = copy[index].duplicate()
	return copy
