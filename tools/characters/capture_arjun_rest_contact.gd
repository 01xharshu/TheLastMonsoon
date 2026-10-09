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
	var hidden_name := OS.get_environment("TLM_REST_HIDE_MESH")
	if hidden_name != "":
		for mesh in player.find_children("*", "MeshInstance3D", true, false):
			if hidden_name in str(mesh.name):
				mesh.hide()
	player.set_meta("mounted_vehicle", null)
	var sample_name := OS.get_environment("TLM_REST_SAMPLE")
	player.global_position = Vector3(0, 0.83, -1.35) if sample_name == "input_sequence" else Vector3(0, 0.83, 0)
	if sample_name != "input_sequence":
		player.set_process(false)
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)
		player.get_node("StairFootContact").set_process(false)
	player.get_node("UI").hide()
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	scene.add_child(light)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.global_position = Vector3(1.65, 1.28, 1.35) if OS.get_environment("TLM_REST_CLOSE") == "1" else Vector3(2.5, 1.65, 2.2)
	camera.look_at(Vector3(0, 0.55, 0))
	camera.make_current()
	if sample_name == "": sample_name = "sit"
	if sample_name == "input_sequence":
		var survival: SurvivalComponent = player.get_node("SurvivalComponent")
		survival.energy = 20.0
		for frame in 12: await physics_frame
		assert(player._find_interactable() == bed, "Player did not select the charpai")
		var before: float = clock.total_game_minutes
		var event := InputEventAction.new()
		event.action = "interact"
		event.pressed = true
		Input.parse_input_event(event)
		await create_timer(0.15).timeout
		var released := InputEventAction.new()
		released.action = "interact"
		released.pressed = false
		Input.parse_input_event(released)
		assert(bed.resting, "Player interact input did not start rest")
		for step in 16: await create_timer(0.25).timeout
		assert(not bed.resting and player.get_meta("rest_action", "") == "", "Player-input rest did not release control")
		assert(is_equal_approx(clock.total_game_minutes - before, 480.0), "Player-input rest did not advance eight hours")
		assert(survival.energy > 20.0, "Player-input rest did not restore energy")
		print("REST PLAYER INPUT PASS")
		quit()
		return
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
	elif sample_name == "mid_wake":
		player.set_meta("rest_waking", true)
		samples = [{"label":"mid_wake", "progress":0.65}]
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
		elif sample.label == "mid" or sample.label == "mid_wake":
			assert(points.head.y < 1.10 and points.pelvis.y < 0.77, "Middle recline left the torso suspended")
			assert(points.hand_r.y < 0.73 and points.hand_r.y > 0.60, "Middle brace missed the cot height")
			assert(points.foot_l.y > 0.65 and points.foot_r.y > 0.65, "Middle recline left a boot below the cot")
		elif sample.label == "lie":
			assert(absf(points.foot_l.y - points.foot_r.y) < 0.07, "Reclined legs are vertically stacked")
			assert(points.hand_l.y > 0.60 and points.hand_r.y > 0.60, "Reclined hand fell below cot weave")
		var output_dir := OS.get_environment("TLM_REST_CAPTURE_DIR")
		if output_dir != "" and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute(output_dir)
			var path: String = output_dir.path_join("charpai_" + str(sample.label) + ".png")
			root.get_texture().get_image().save_png(path)
		print("REST CONTACT ", sample.label, " ", JSON.stringify(positions))
	quit()
