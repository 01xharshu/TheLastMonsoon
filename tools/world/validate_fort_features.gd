extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var fort: Node3D = load("res://world/ruined_fort/fort_world_piece.tscn").instantiate()
	fort.position = Vector3(520,120,-350)
	root.add_child(fort)
	await physics_frame
	await physics_frame
	var points := get_nodes_in_group("fort_cover_points")
	assert(points.size() == 44)
	for point in points:
		var local: Vector3 = fort.to_local(point.global_position)
		assert(absf(local.y-fort.height_at(local.x,local.z)) < 0.65, "Cover marker is above ground")
	var wall := fort.get_node("Architecture/WestClimbWall")
	assert(wall.is_in_group("climbable_walls"))
	assert(float(wall.get_meta("top_y")) > 123)
	var landing := Vector3(wall.global_position.x+0.8,float(wall.get_meta("top_y"))+0.94,wall.global_position.z)
	var query := PhysicsRayQueryParameters3D.create(landing,landing-Vector3.UP*1.2)
	var support := fort.get_world_3d().direct_space_state.intersect_ray(query)
	assert(not support.is_empty() and absf(support.position.y-float(wall.get_meta("top_y"))) < 0.15)
	assert(fort.get_node("Vegetation/ClusteredDryGrass").multimesh.instance_count == 240)
	print("FORT FEATURES PASS | 44 ground cover markers | supported climb landing | 240 grass tufts")
	quit()
