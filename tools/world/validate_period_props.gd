extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 8:
		await process_frame
	var settlement: Node3D = world.get_node("Settlement")
	var names := ["CompanyStoresWoodenCrate", "BhairavpurWoodenBucket", "BhairavpurBrassPot", "BhairavpurWickerBasket", "BhairavpurWoodenStool", "CompanyGuardBench", "CompanyStoresWineBarrel"]
	var props: Array[StaticBody3D] = []
	var failures: Array[String] = []
	for name in names:
		var prop: StaticBody3D = settlement.get_node_or_null(name)
		if prop == null or prop.get_child_count() < 2 or not prop.get_child(1) is CollisionShape3D:
			push_error("Missing period prop or collision: " + name)
			quit(1)
			return
		props.append(prop)
	for prop in props:
		var mesh_bottom := INF
		for mesh in prop.find_children("*", "MeshInstance3D", true, false):
			var bounds: AABB = mesh.global_transform * mesh.get_aabb()
			mesh_bottom = minf(mesh_bottom, bounds.position.y)
		var ray := PhysicsRayQueryParameters3D.create(prop.global_position + Vector3.UP * 2.0, prop.global_position - Vector3.UP * 2.0)
		ray.exclude = [prop.get_rid()]
		var floor_hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
		var gap: float = mesh_bottom - floor_hit.position.y if not floor_hit.is_empty() else INF
		var grounded: bool = gap >= -.04 and gap <= .06
		if not grounded:
			failures.append(prop.name + " ground gap " + str(gap))
		print("PERIOD PROP ", "PASS" if grounded else "FAIL", ": ", prop.name, " at ", prop.global_position, " visual-ground-gap=", gap)
	if not failures.is_empty():
		push_error("Period prop placement: " + str(failures))
		quit(1)
		return
	if DisplayServer.get_name() != "headless":
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.fov = 48
		for i in props.size():
			var prop := props[i]
			var close := i == 2 or i == 3 or i == 4
			camera.global_position = prop.global_position + (Vector3(1.1,.8,1.4) if close else Vector3(2.3,1.6,3.0))
			camera.look_at(prop.global_position + Vector3(0,.12 if close else .45,0))
			camera.current = true
			for frame in 10:
				await process_frame
			await RenderingServer.frame_post_draw
			var file: String = "res://docs/world/captures/period_" + ["crate", "bucket", "brass_pot", "wicker_basket", "stool", "bench", "barrel"][i] + ".png"
			root.get_viewport().get_texture().get_image().save_png(file)
			print("PERIOD PROP CAPTURE: ", file)
	quit()
