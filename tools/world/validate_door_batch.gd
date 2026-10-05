extends SceneTree
const Door = preload("res://objects/hinged_door.gd")
class ReferenceDoor extends Door:
	func _batch_leaf(_pivot: Node3D) -> void: pass
	func batch_now() -> void:
		for pivot in leaf_pivots: super._batch_leaf(pivot)
func _initialize() -> void: run.call_deferred()
func stats(door: Node3D) -> Dictionary:
	var vertices := 0
	var meshes := 0
	var bounds := AABB()
	var first := true
	for mesh in door.find_children("*","MeshInstance3D",true,false):
		meshes += 1
		var at: Transform3D = door.global_transform.affine_inverse()*mesh.global_transform
		for index in mesh.mesh.get_surface_count():
			var arrays = mesh.mesh.surface_get_arrays(index)
			var faces: PackedVector3Array = mesh.mesh.get_faces()
			if index == 0: vertices += faces.size()
			for vertex in arrays[Mesh.ARRAY_VERTEX]:
				var position: Vector3 = at*vertex
				if first: bounds = AABB(position,Vector3.ZERO); first = false
				else: bounds = bounds.expand(position)
	return {"triangle_vertices":vertices,"mesh_nodes":meshes,"bounds":bounds}
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var door := ReferenceDoor.new()
	door.opened = false
	var timber := StandardMaterial3D.new()
	world.add_child(door)
	door.build(timber)
	var before := stats(door)
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(960,720)
		root.content_scale_size = root.size
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		DisplayServer.window_set_size(root.size)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-35,-35,0)
		world.add_child(sun)
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.global_position = Vector3(4,3,6)
		camera.look_at(door.global_position+Vector3.UP)
		camera.make_current()
		await capture("/tmp/tlm_door_reference.png")
	door.batch_now()
	var after := stats(door)
	assert(before.triangle_vertices == after.triangle_vertices)
	assert(before.bounds.position.is_equal_approx(after.bounds.position))
	assert(before.bounds.size.is_equal_approx(after.bounds.size))
	assert(after.mesh_nodes == 2)
	for amount in [0.0,.25,.5,1.0]:
		door.swing = amount
		for index in 2:
			var pivot: Node3D = door.leaf_pivots[index]
			var expected: Transform3D = door._leaf_transform(index,amount)
			assert(door.leaf_shapes[index].transform.is_equal_approx(expected))
			assert(is_equal_approx(absf(pivot.rotation.y),amount*PI*.5))
			assert(pivot.get_node("IronPullRing") is Marker3D)
	door.swing = 0.0
	if DisplayServer.get_name() != "headless": await capture("/tmp/tlm_door_batched.png")
	print("DOOR BATCH GEOMETRY / HINGE / COLLISION: PASS before=",before," after=",after)
	world.queue_free()
	for frame in 3: await physics_frame
	quit()
func capture(path: String) -> void:
	for frame in 3: await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(path) == OK)
