extends SceneTree
## Determinism, chunk partitioning, LOD geometry, node budget and slope contact.
const Generator = preload("res://environment/forest/scripts/forest_generator.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var forest := Node3D.new()
	forest.set_script(Generator)
	forest.config = load("res://environment/forest/config/benchmark.tres").duplicate()
	forest.config.chunk_size = 12.0
	root.add_child(forest)
	var before: int = forest.get_meta("placement_signature")
	print("DEFAULT_CHUNKS ", forest.get_node("GeneratedChunks_Runtime").get_child_count(), " nodes=", forest.find_children("*", "", true, false).size())
	forest.regenerate()
	assert(before == forest.get_meta("placement_signature"), "Seed regeneration changed placement")
	assert(forest.find_children("*", "", true, false).size() < 1000)
	forest.config.chunk_size = 15.0
	forest.regenerate()
	assert(before == forest.get_meta("placement_signature"), "Chunk size changed placement")
	assert(forest.get_node("GeneratedChunks_Runtime").get_child_count() == 16)
	for layer in forest._lod_meshes:
		var triangles: Array[int] = []
		for meshes in forest._lod_meshes[layer]:
			var total := 0
			for mesh in meshes:
				for s in mesh.get_surface_count():
					var arrays: Array = mesh.surface_get_arrays(s)
					var indices = arrays[Mesh.ARRAY_INDEX]
					total += (indices.size() if indices != null and not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size()) / 3
			triangles.append(total)
		assert(triangles[0] > triangles[1] and triangles[1] > triangles[2], "LOD not cheaper: " + layer)
		print("LOD ", layer, " ", triangles)
	var nodes := forest.find_children("*", "", true, false).size()
	assert(nodes < 1000, "Generated node budget exceeded")
	for chunk in forest.get_node("GeneratedChunks_Runtime").get_children():
		assert(chunk.position != Vector3.ZERO)
		for batch in chunk.get_children():
			if batch is StaticBody3D:
				assert(batch.get_child(0) is CollisionShape3D)
				assert(batch.transform.basis.get_scale().x > 0.0)
	print("FOREST_FOUNDATION_PASS nodes=", nodes, " counts=", forest.get_meta("forest_counts"), " seed/chunk invariance and cheaper LODs verified")
	forest.queue_free()
	await process_frame
	quit()
