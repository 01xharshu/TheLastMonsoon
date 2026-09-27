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
	var names := ["CompanyStoresWoodenCrate", "BhairavpurWoodenBucket", "BhairavpurBrassPot", "BhairavpurWickerBasket", "BhairavpurWoodenStool", "BhairavpurPaintedBench", "CompanyStoresWineBarrel"]
	var props: Array[StaticBody3D] = []
	for name in names:
		var prop: StaticBody3D = settlement.get_node_or_null(name)
		if prop == null or prop.get_child_count() < 2 or not prop.get_child(1) is CollisionShape3D:
			push_error("Missing period prop or collision: " + name)
			quit(1)
			return
		props.append(prop)
	for prop in props:
		print("PERIOD PROP STRUCTURAL PASS: ", prop.name, " ", prop.global_position)
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
