extends SceneTree
## Structural integration check. Run with --headless; render quality is separate.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	for body in world.find_children("*", "CollisionObject3D", true, false):
		body.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	world.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(world)
	current_scene = world
	world.get_node("Player").disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	world.get_node("Player").process_mode = Node.PROCESS_MODE_DISABLED
	for body in world.find_children("*", "CollisionObject3D", true, false):
		body.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
	await physics_frame
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
	var map: Control = player.get_node("UI/WorldMap")
	map.refresh_sites()
	var destination := Vector2(forest.global_position.x, forest.global_position.z)
	assert(map.sites.get("Forest grove") == destination, "Map destination differs from live forest")
	assert(map.site_kind("Forest grove") == "nature")
	map.size = Vector2(1280, 720)
	map._update_map_area()
	map.map_center = destination
	map.zoom = 4.0
	map.visible = true
	var click_at: Vector2 = map.project(destination)
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = click_at
		click.pressed = pressed
		map._gui_input(click)
	assert(map.selected_site == "Forest grove")
	assert(map.waypoint == destination)
	map.visible = false
	map.marker._process(0.0)
	assert(Vector2(map.marker.global_position.x, map.marker.global_position.z).is_equal_approx(destination))
	# Confirm the authored node wins over stale static coordinates after a move.
	forest.position.x += 5.0
	map.refresh_sites()
	assert(map.sites["Forest grove"] == destination + Vector2(5, 0))
	forest.position.x -= 5.0
	map.refresh_sites()
	print("FOREST_MAP_ACCESS_PASS nature marker, mouse selection, live position and in-world waypoint verified")
	var entry: Vector2 = forest.path_points[0]
	player.position = forest.global_position + Vector3(entry.x, adapter.sample_forest_height(entry.x, entry.y) + 1.05, entry.y)
	player.velocity = Vector3.ZERO
	player.floor_snap_length = 0.6
	var grounded := 0
	var steps := 0
	var reached := 0
	var targets: PackedVector2Array = forest.path_points.duplicate()
	targets.append(destination - Vector2(forest.global_position.x, forest.global_position.z))
	for index in range(1, targets.size()):
		var point: Vector2 = targets[index]
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
		"corridor_segments_reached": mini(reached, forest.path_points.size() - 1),
		"map_destination_reached": reached == targets.size() - 1, "corridor_segments": forest.path_points.size() - 1,
		"physics_frames": steps, "grounded_frames": grounded,
		"final_position": [player.position.x, player.position.y, player.position.z],
		"passed": reached == targets.size() - 1,
		"limitation": "Manual capsule physics sweep at 3 m/s. Player controls, camera clearance, foot contact and rendered appearance require separate review."}
	print("FOREST_WORLD_CORRIDOR ", JSON.stringify(report))
	world.queue_free()
	await process_frame
	quit(0 if report.passed else 1)
