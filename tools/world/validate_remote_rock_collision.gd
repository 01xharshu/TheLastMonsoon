extends SceneTree
## Compare the original per-instance shape with the shared production shape.
var errors: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var source: Node3D = load("res://environment/forest/assets/rock_reused.glb").instantiate()
	var meshes := source.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		push_error("Rock source has no mesh")
		quit(1)
		return
	var mesh: Mesh = meshes[0].mesh
	var start := Time.get_ticks_usec()
	var original_shapes: Array[ConcavePolygonShape3D] = []
	for i in 28: original_shapes.append(mesh.create_trimesh_shape())
	var original_usec := Time.get_ticks_usec() - start
	start = Time.get_ticks_usec()
	var shared: ConcavePolygonShape3D = mesh.create_trimesh_shape()
	var shared_usec := Time.get_ticks_usec() - start
	if shared == null or original_shapes[0].data != shared.data:
		errors.append("Shared rock triangles differ from original")
	var stage := Node3D.new()
	root.add_child(stage)
	var original := MeshInstance3D.new()
	original.mesh = mesh
	original.scale = Vector3(4.4, 5.5, 3.0)
	original.rotation.y = .63
	stage.add_child(original)
	original.create_trimesh_collision()
	var reused := MeshInstance3D.new()
	reused.mesh = mesh
	reused.scale = original.scale
	reused.rotation = original.rotation
	reused.position.x = 50.0
	stage.add_child(reused)
	load("res://world/suryagarh/remote_mountains.gd").attach_rock_collision(reused, shared)
	var body := reused.get_node("RockCollision") as StaticBody3D
	body.collision_layer = 2
	var shape_node := body.get_child(0) as CollisionShape3D
	if shape_node.shape != shared: errors.append("Shared shape was not retained")
	for i in 12:
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		stage.add_child(instance)
		load("res://world/suryagarh/remote_mountains.gd").attach_rock_collision(instance, shared)
		if instance.get_node("RockCollision").get_child(0).shape != shared: errors.append("Rock created a duplicate collision shape")
		instance.queue_free()
	for i in 3: await physics_frame
	var bounds := mesh.get_aabb()
	var hits := 0
	for x in 9:
		for z in 9:
			var local := Vector3(bounds.position.x + bounds.size.x * (float(x) + .5) / 9.0, bounds.end.y + 1.0, bounds.position.z + bounds.size.z * (float(z) + .5) / 9.0)
			var bottom := Vector3(local.x, bounds.position.y - 1.0, local.z)
			var old_query := PhysicsRayQueryParameters3D.create(original.to_global(local), original.to_global(bottom), 1)
			var new_query := PhysicsRayQueryParameters3D.create(reused.to_global(local), reused.to_global(bottom), 2)
			var before := stage.get_world_3d().direct_space_state.intersect_ray(old_query)
			var after := stage.get_world_3d().direct_space_state.intersect_ray(new_query)
			if before.is_empty() != after.is_empty():
				errors.append("Ray hit differs at " + str(Vector2i(x,z)))
			elif not before.is_empty():
				hits += 1
				if absf(before.position.y - after.position.y) > .001 or before.normal.dot(after.normal) < .999:
					errors.append("Ray contact differs at " + str(Vector2i(x,z)))
	print("REMOTE ROCK COLLISION ", JSON.stringify({"passed": errors.is_empty() and hits > 0, "ray_hits":hits, "triangles":shared.data.size()/3, "original_28_shapes_us":original_usec, "one_shared_shape_us":shared_usec, "errors":errors}))
	source.free()
	stage.queue_free()
	await process_frame
	root.get_node("SaveManager").quit_game(0 if errors.is_empty() and hits > 0 else 1)
