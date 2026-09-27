extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var ground := StaticBody3D.new()
	scene.add_child(ground)
	var ground_shape := CollisionShape3D.new()
	ground_shape.shape = BoxShape3D.new()
	ground_shape.shape.size = Vector3(12, 0.2, 12)
	ground_shape.position.y = -0.1
	ground.add_child(ground_shape)
	var ground_mesh := MeshInstance3D.new()
	ground_mesh.mesh = BoxMesh.new()
	ground_mesh.mesh.size = Vector3(12, 0.2, 12)
	ground_mesh.position.y = -0.1
	ground.add_child(ground_mesh)
	var bed := load("res://objects/charpai.tscn").instantiate() as Node3D
	scene.add_child(bed)
	var player := load("res://player/player.tscn").instantiate() as CharacterBody3D
	scene.add_child(player)
	player.set_meta("mounted_vehicle", null)
	player.global_position = Vector3(0, 0.83, 0)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.get_node("UI").hide()
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	scene.add_child(light)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.global_position = Vector3(2.5, 1.65, 2.2)
	camera.look_at(Vector3(0, 0.55, 0))
	camera.make_current()
	player.set_meta("rest_action", "sleep")
	var sample_name := OS.get_environment("TLM_REST_SAMPLE")
	if sample_name == "": sample_name = "sit"
	var samples := [{"label":"lie", "progress":1.0}] if sample_name == "lie" else [{"label":"sit", "progress":0.35}]
	for sample in samples:
		player.set_meta("rest_progress", sample.progress)
		for frame in 35: await process_frame
		var visual: Node3D = player.get_node("VisualRoot/CharacterVisual")
		var rig: Skeleton3D = visual.skeleton
		var positions := {}
		for bone in ["pelvis", "foot_l", "foot_r", "hand_l", "hand_r", "head"]:
			positions[bone] = str(rig.to_global(rig.get_bone_global_pose(rig.find_bone(bone)).origin))
		await RenderingServer.frame_post_draw
		var path: String = "res://docs/characters/arjun/charpai_" + str(sample.label) + "_contact.png"
		root.get_texture().get_image().save_png(path)
		print("REST CONTACT ", sample.label, " ", JSON.stringify(positions))
	quit()
