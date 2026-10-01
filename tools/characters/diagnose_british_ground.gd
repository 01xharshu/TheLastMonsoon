extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var world := load("res://world/suryagarh/suryagarh_world.tscn").instantiate() as Node3D
	root.add_child(world)
	for frame in 5:
		await process_frame
	for node in world.find_children("*", "", true, false):
		node.set_process(false)
		node.set_physics_process(false)
	world.set_process(false)
	world.set_physics_process(false)
	var player := world.get_node("Player") as CharacterBody3D
	var actor := world.get_node("BritishNpcRosterCandidate/PrivateWoman") as Node3D
	var start := actor.global_position + Vector3(0.78, 0, 0)
	var query := PhysicsRayQueryParameters3D.create(start + Vector3.UP * 3, start - Vector3.UP * 3, 1)
	query.exclude = [player.get_rid(), actor.get_node("BodyCollider").get_rid()]
	var ground := world.get_world_3d().direct_space_state.intersect_ray(query)
	player.global_position = Vector3(start.x, ground.position.y + 0.91, start.z)
	player.force_update_transform()
	await physics_frame
	await physics_frame
	var visual := player.get_node("VisualRoot/CharacterVisual")
	for frame in 60:
		player.velocity = Vector3(0, -0.2, 0)
		player.move_and_slide()
		visual.call("_process", 1.0 / 60.0)
		await physics_frame
	var skeleton: Skeleton3D = visual.get("skeleton")
	var poses := {}
	for label in ["pelvis", "foot_l", "foot_r"]:
		poses[label] = str(skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(label)).origin)
	print("GROUND_DIAG ", JSON.stringify({"floor": str(ground.position), "floor_collider": str(ground.collider.get_path()), "layout_height": load("res://world/suryagarh/landscape_layout.gd").new().height(start.x,start.z), "player": str(player.global_position), "model": str(visual.get("model").global_position), "foot_offset": visual.get("motion_tree").foot_contact_offset, "poses": poses}))
	for mesh in world.find_children("*", "MeshInstance3D", true, false):
		var bounds: AABB = mesh.global_transform * mesh.get_aabb()
		if start.x >= bounds.position.x and start.x <= bounds.end.x and start.z >= bounds.position.z and start.z <= bounds.end.z and bounds.position.y < ground.position.y + 1.0 and bounds.end.y > ground.position.y - 0.5:
			print("GROUND_MESH ",mesh.get_path()," bounds ",bounds)
			if not mesh.is_visible_in_tree() or not str(mesh.get_path()).begins_with("/root/Suryagarh/Landscape") and not str(mesh.get_path()).begins_with("/root/Suryagarh/Settlement"):
				continue
			var inverse: Transform3D = mesh.global_transform.affine_inverse()
			var from: Vector3 = inverse * (start + Vector3.UP * 2.0)
			var to: Vector3 = inverse * (start - Vector3.UP)
			var faces: PackedVector3Array = mesh.mesh.get_faces()
			var highest := -INF
			for index in range(0, faces.size(), 3):
				var hit: Variant = Geometry3D.segment_intersects_triangle(from,to,faces[index],faces[index+1],faces[index+2])
				if hit != null:
					highest = maxf(highest, (mesh.global_transform * hit).y)
			if highest > -INF:
				print("GROUND_VISIBLE_SURFACE ",mesh.get_path()," y=",highest)
	quit()
