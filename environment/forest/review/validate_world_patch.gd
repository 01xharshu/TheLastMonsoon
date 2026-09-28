extends SceneTree
## Structural integration check. Run with --headless; render quality is separate.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.get_node("Player").set_physics_process(false)
	await process_frame
	var forest: Node3D = world.get_node("WorldForestPatch")
	var adapter: Node = forest.get_node("TerrainAdapter")
	var counts: Dictionary = forest.get_meta("forest_counts", {})
	var existing: PackedVector2Array = adapter.sample_forest_existing_tree_points()
	var chunks: Node = forest.get_node("GeneratedChunks_Runtime")
	var local_y: float = adapter.sample_forest_height(0.0, 0.0)
	var normal: Vector3 = adapter.sample_forest_normal(0.0, 0.0)
	assert(chunks.get_child_count() > 0)
	assert(counts.get("canopy", 0) + counts.get("canopy_broad", 0) > 0)
	assert(existing.size() > 0)
	assert(local_y > 20.0 and local_y < 50.0)
	assert(normal.y > 0.7)
	print("FOREST_WORLD_PATCH_PASS center=", forest.global_position, " chunks=", chunks.get_child_count(), " counts=", counts, " existing_trees=", existing.size(), " center_height=", local_y, " normal_y=", normal.y)
	world.queue_free()
	quit()
