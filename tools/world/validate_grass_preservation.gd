extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var before: Node3D = load("/tmp/tlm_grass_before_landscape.scn").instantiate()
	var after: Node3D = load("res://world/suryagarh/generated/landscape.scn").instantiate()
	root.add_child(before)
	root.add_child(after)
	var errors: Array[String] = []
	var batches := 0
	var retained_instances := 0
	for tile in before.get_node("NatureTiles").get_children():
		for node in tile.get_children():
			if str(node.name).begins_with("Grass"): continue
			var candidate: Node = after.get_node("NatureTiles/"+str(tile.name)+"/"+str(node.name))
			if node is MultiMeshInstance3D:
				if node.multimesh.buffer != candidate.multimesh.buffer: errors.append(str(tile.name)+"/"+str(node.name)+" transforms changed")
				batches += 1
				retained_instances += node.multimesh.instance_count
			if node is Node3D and node.transform != candidate.transform: errors.append(str(node.name)+" transform changed")
	var retained_ground := 0
	for node in before.find_children("*","Node3D",true,false):
		var relative := before.get_path_to(node)
		if str(relative).begins_with("NatureTiles"): continue
		var candidate := after.get_node_or_null(relative)
		if candidate == null: errors.append(str(relative)+" missing");continue
		if candidate.get_class() != node.get_class() or candidate.transform != node.transform: errors.append(str(relative)+" class/transform changed")
		if node is MeshInstance3D:
			if candidate.mesh.get_surface_count()!=node.mesh.get_surface_count(): errors.append(str(relative)+" surface count changed")
			else:
				for surface in node.mesh.get_surface_count():
					if node.mesh.surface_get_arrays(surface)!=candidate.mesh.surface_get_arrays(surface): errors.append(str(relative)+" geometry changed")
		if node is CollisionShape3D and node.shape is HeightMapShape3D:
			if node.shape.map_data != candidate.shape.map_data or node.shape.map_width != candidate.shape.map_width or node.shape.map_depth != candidate.shape.map_depth: errors.append(str(relative)+" ground collision changed")
			retained_ground += 1
	var report := {"passed":errors.is_empty(),"retained_tree_rock_batches":batches,"retained_instances":retained_instances,"retained_ground_collision_tiles":retained_ground,"errors":errors,"scope":"paired Metal non-grass nature buffers plus terrain/water geometry and collision; baseline scratch snapshot is required"}
	FileAccess.open("res://docs/world/grass_preservation_2026-10-05.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("GRASS PRESERVATION ",JSON.stringify(report))
	before.free(); after.free()
	quit(0 if errors.is_empty() else 1)
