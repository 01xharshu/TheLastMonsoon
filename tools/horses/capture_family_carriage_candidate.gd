extends SceneTree

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("FAMILY CARRIAGE CAPTURE BLOCKED: native renderer required")
		quit(1)
		return
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(24,20)
	ground.mesh = plane
	var earth := StandardMaterial3D.new()
	earth.albedo_color = Color(.48,.42,.32)
	ground.material_override = earth
	stage.add_child(ground)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-35,0)
	sun.light_energy = 1.8
	stage.add_child(sun)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(.65,.72,.73)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(.78,.77,.72)
	env.ambient_light_energy = .8
	environment.environment = env
	stage.add_child(environment)
	var carriage: Node3D = load("res://vehicles/family_carriage_candidate.gd").new()
	stage.add_child(carriage)
	var camera := Camera3D.new()
	camera.fov = 49
	stage.add_child(camera)
	camera.make_current()
	for view in [
		["quarter",Vector3(7,3.9,8.4),Vector3(0,1.5,.7)],
		["side",Vector3(8,3.0,1.15),Vector3(0,1.5,.8)],
		["front",Vector3(4.4,3.1,-7.4),Vector3(0,1.55,-.2)],
	]:
		camera.position = view[1]
		camera.look_at(view[2])
		for frame in 10: await process_frame
		await RenderingServer.frame_post_draw
		var path: String = "res://docs/world/captures/family_carriage_%s.png" % view[0]
		assert(root.get_texture().get_image().save_png(path) == OK)
		print("FAMILY CARRIAGE CAPTURE ",path)
	for node in carriage.get_node("FamilyCarriageVisual").get_children():
		if node.name in ["Roof","RoofCrown","RoofEndBinding","RoofSeam","InteriorCeilingLiner"]:
			node.hide()
	camera.position = Vector3(2.9,5.2,3.2)
	camera.look_at(Vector3(0,1.65,2.76))
	for frame in 10: await process_frame
	await RenderingServer.frame_post_draw
	var interior_path := "res://docs/world/captures/family_carriage_interior.png"
	assert(root.get_texture().get_image().save_png(interior_path) == OK)
	print("FAMILY CARRIAGE CAPTURE ",interior_path)
	quit()
