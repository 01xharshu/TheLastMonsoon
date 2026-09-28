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
	var clock := GameTimeSystem.new()
	clock.name = "GameTimeSystem"
	clock.clock_paused = true
	scene.add_child(clock)
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
	var sample_name := OS.get_environment("TLM_REST_SAMPLE")
	if sample_name == "": sample_name = "sit"
	if sample_name == "sequence":
		var survival: SurvivalComponent = player.get_node("SurvivalComponent")
		survival.energy = 20.0
		var before: float = clock.total_game_minutes
		bed.interact(player)
		var progress_samples: Array[float] = []
		for step in 16:
			await create_timer(0.25).timeout
			progress_samples.append(float(player.get_meta("rest_progress", -1.0)))
		assert(not bed.resting and player.get_meta("rest_action", "") == "", "Charpai did not release player")
		assert(is_equal_approx(clock.total_game_minutes - before, 480.0), "Charpai did not advance eight hours")
		assert(survival.energy > 20.0, "Charpai did not restore energy")
		var final_model: Node3D = player.get_node("VisualRoot/CharacterVisual").model
		assert(final_model.quaternion.angle_to(Quaternion.IDENTITY) < 0.08, "Charpai left the visual rig rolled after wake")
		print("REST SEQUENCE PASS ", JSON.stringify(progress_samples))
		quit()
		return
	player.set_meta("rest_action", "sleep")
	var samples := [{"label":"sit", "progress":0.35}]
	if sample_name == "lie": samples = [{"label":"lie", "progress":1.0}]
	elif sample_name == "mid": samples = [{"label":"mid", "progress":0.65}]
	for sample in samples:
		player.set_meta("rest_progress", sample.progress)
		for frame in 12: await process_frame
		var visual: Node3D = player.get_node("VisualRoot/CharacterVisual")
		var rig: Skeleton3D = visual.skeleton
		var positions := {}
		var points := {}
		for bone in ["pelvis", "foot_l", "foot_r", "hand_l", "hand_r", "head"]:
			var point: Vector3 = rig.to_global(rig.get_bone_global_pose(rig.find_bone(bone)).origin)
			points[bone] = point
			positions[bone] = str(point)
		if sample.label == "sit":
			assert(absf(points.foot_l.y - 0.105) < 0.05 and absf(points.foot_r.y - 0.105) < 0.05, "Seated boots missed the floor")
		elif sample.label == "lie":
			assert(absf(points.foot_l.y - points.foot_r.y) < 0.07, "Reclined legs are vertically stacked")
			assert(points.hand_l.y > 0.60 and points.hand_r.y > 0.60, "Reclined hand fell below cot weave")
		if not DisplayServer.get_name() == "headless": await RenderingServer.frame_post_draw
		var path: String = "res://docs/characters/arjun/charpai_" + str(sample.label) + "_contact.png"
		if not DisplayServer.get_name() == "headless": root.get_texture().get_image().save_png(path)
		print("REST CONTACT ", sample.label, " ", JSON.stringify(positions))
	quit()
