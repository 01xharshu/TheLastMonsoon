extends SceneTree
## Structural integration check. Run with --headless; render quality is separate.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.get_node("Player").disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	world.get_node("Player").process_mode = Node.PROCESS_MODE_DISABLED
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
	var player: CharacterBody3D = world.get_node("Player")
	var entry: Vector2 = forest.path_points[0]
	player.position = forest.global_position + Vector3(entry.x, adapter.sample_forest_height(entry.x, entry.y) + 1.05, entry.y)
	player.velocity = Vector3.ZERO
	player.floor_snap_length = 0.6
	var grounded := 0
	var steps := 0
	var reached := 0
	for index in range(1, forest.path_points.size()):
		var point: Vector2 = forest.path_points[index]
		var target := Vector2(forest.global_position.x + point.x, forest.global_position.z + point.y)
		for frame in 900:
			await physics_frame
			var planar := Vector2(player.position.x, player.position.z)
			if planar.distance_to(target) < 0.3:
				reached += 1
				break
			var direction := (target - planar).normalized()
			player.velocity.x = direction.x * 3.0
			player.velocity.z = direction.y * 3.0
			player.velocity.y = -0.2 if player.is_on_floor() else player.velocity.y - 9.8 / 60.0
			player.move_and_slide()
			steps += 1
			if player.is_on_floor(): grounded += 1
	var report := {"date": Time.get_date_string_from_system(), "center": [370, -105], "size_metres": [60, 60],
		"chunks": chunks.get_child_count(), "counts": counts, "existing_tree_points": existing.size(),
		"replaced_baked_grass_instances": forest.get_meta("replaced_baked_grass_instances", 0),
		"corridor_segments_reached": reached, "corridor_segments": forest.path_points.size() - 1,
		"physics_frames": steps, "grounded_frames": grounded,
		"final_position": [player.position.x, player.position.y, player.position.z],
		"passed": reached == forest.path_points.size() - 1,
		"limitation": "Manual capsule physics sweep at 3 m/s. Player controls, camera clearance, foot contact and rendered appearance require separate review."}
	print("FOREST_WORLD_CORRIDOR ", JSON.stringify(report))
	world.queue_free()
	await process_frame
	quit(0 if report.passed else 1)
