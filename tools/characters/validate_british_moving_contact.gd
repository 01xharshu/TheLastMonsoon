extends SceneTree
## Actual Player versus advancing patrols, side approaches and endpoint turns.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := load("res://world/suryagarh/suryagarh_world.tscn").instantiate() as Node3D
	root.add_child(world)
	for startup_frame in 4:
		await process_frame
	# Household setup can relocate residents and coach components can move them.
	# Finish setup, then isolate this contact exercise from those other systems.
	world.set_process(false)
	world.set_physics_process(false)
	for child in world.find_children("*", "", true, false):
		child.set_process(false)
		child.set_physics_process(false)
	var player := world.get_node("Player") as CharacterBody3D
	player.set_process(false)
	player.set_physics_process(false)
	for child in player.find_children("*", "", true, false):
		child.set_process(false)
		child.set_physics_process(false)
	var roster := world.get_node("BritishNpcRosterCandidate")
	var camera: Camera3D
	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1280, 720)
		world.get_node("Player/UI").hide()
		world.get_node("LandscapeUI").hide()
		camera = Camera3D.new()
		camera.fov = 45.0
		world.add_child(camera)
		camera.make_current()
		# The gameplay spring arm may hide the body during startup; this external
		# review camera needs it visible after the camera-clearance script pauses.
		player.get_node("VisualRoot").show()
	for actor in roster.get_children():
		actor.set_process(false)
	var errors: Array[String] = []
	var results: Array = []
	var stationary_actors: Array[String] = []
	var live_updates := "--live" in OS.get_cmdline_user_args()
	var selected_actor := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--actor="):
			selected_actor = argument.trim_prefix("--actor=")
	for actor_node in roster.get_children():
		var actor := actor_node as Node3D
		if not selected_actor.is_empty() and actor.name != selected_actor:
			continue
		if not bool(actor.get("movement_enabled")):
			stationary_actors.append(str(actor.name))
			continue
		var axis: Vector3 = actor.get("patrol_axis")
		var home: Vector3 = actor.get("_home")
		var distance: float = actor.get("patrol_distance")
		var collider := actor.get_node("BodyCollider") as AnimatableBody3D
		var capsule := (collider.get_node("BodyShape") as CollisionShape3D).shape as CapsuleShape3D
		var required_gap := capsule.radius + 0.4
		for scenario in ["front", "return", "side", "turn"]:
			var clock := 4.5 if scenario == "return" else (4.0 if scenario == "turn" else 0.0)
			# Reset each independent case without asking avoidance to traverse the
			# prior case's occupied path or inheriting a patrol teleport velocity.
			player.global_position = home + Vector3(0, 4, 4)
			actor.position = home + axis * distance if scenario in ["return", "turn"] else home
			actor.rotation.y = atan2(-axis.x, -axis.z) if scenario == "return" else atan2(axis.x, axis.z)
			actor.set("_clock", clock)
			actor.call("_process", 0.0)
			collider.force_update_transform()
			await physics_frame
			await physics_frame
			var side := Vector3(-axis.z, 0, axis.x)
			var start := actor.global_position + axis * 0.78
			if scenario == "return":
				start = actor.global_position - axis * 0.78
			elif scenario in ["side", "turn"]:
				start = actor.global_position + side * 1.1
			var ray := PhysicsRayQueryParameters3D.create(start + Vector3.UP * 3.0, start - Vector3.UP * 3.0, 1)
			ray.exclude = [player.get_rid(), collider.get_rid()]
			var ground := world.get_world_3d().direct_space_state.intersect_ray(ray)
			player.global_position = start + Vector3.UP * 0.91
			if not ground.is_empty():
				player.global_position.y = ground.position.y + 0.91
			player.velocity = Vector3.ZERO
			player.force_update_transform()
			collider.force_update_transform()
			await physics_frame
			await physics_frame
			var minimum_gap := INF
			var standing_start := player.global_position
			var maximum_player_step := 0.0
			var blocked_frames := 0
			actor.set_process(live_updates)
			for frame in 90:
				var previous := player.global_position
				if not live_updates:
					actor.call("_process", 1.0 / 60.0)
				player.velocity = -side * 1.0 if scenario in ["side", "turn"] else Vector3.ZERO
				player.velocity.y = -0.2
				player.move_and_slide()
				if camera != null:
					player.get_node("VisualRoot/CharacterVisual").call("_process", 1.0 / 60.0)
				var offset := player.global_position - actor.global_position
				offset.y = 0.0
				minimum_gap = minf(minimum_gap, offset.length())
				maximum_player_step = maxf(maximum_player_step, player.global_position.distance_to(previous))
				if actor.get("animation_state") == &"idle" and scenario in ["front", "return"]:
					blocked_frames += 1
				await physics_frame
			actor.set_process(false)
			var resume_start := actor.global_position
			var standing_drift := Vector2(player.global_position.x - standing_start.x, player.global_position.z - standing_start.z).length()
			if camera != null and scenario == "front":
				camera.global_position = actor.global_position + side * 3.0 - axis * 2.0 + Vector3.UP * 1.8
				camera.look_at((actor.global_position + player.global_position - Vector3.UP * 0.9) * 0.5 + Vector3.UP * 0.9)
				for frame in 5:
					await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://docs/characters/british/candidates/" + str(actor.name).to_snake_case() + "_moving_wait.png")
			player.global_position += side * 3.0
			player.force_update_transform()
			await physics_frame
			actor.set_process(live_updates)
			for frame in 30:
				if not live_updates:
					actor.call("_process", 1.0 / 60.0)
				await physics_frame
			actor.set_process(false)
			var resumed_distance := actor.global_position.distance_to(resume_start)
			if minimum_gap < required_gap - 0.025:
				errors.append(str(actor.name) + "/" + scenario + ": overlap gap=" + str(minimum_gap))
			if maximum_player_step > 0.12:
				errors.append(str(actor.name) + "/" + scenario + ": player jump=" + str(maximum_player_step))
			if scenario in ["front", "return"] and (blocked_frames == 0 or resumed_distance < distance * 0.15):
				errors.append(str(actor.name) + "/" + scenario + ": no idle wait or resume")
			if scenario in ["front", "return"] and standing_drift > 0.03:
				errors.append(str(actor.name) + "/" + scenario + ": stationary Player pushed " + str(standing_drift))
			results.append({"actor": str(actor.name), "scenario": scenario, "minimum_body_gap_m": minimum_gap, "required_gap_m": required_gap, "maximum_player_step_m": maximum_player_step, "standing_player_drift_m": standing_drift, "blocked_idle_frames": blocked_frames, "resume_travel_m": resumed_distance, "ground_height_m": ground.position.y if not ground.is_empty() else null, "npc_grade_m": home.y, "ground_collider": str(ground.collider.get_path()) if not ground.is_empty() else "none"})
		print("BRITISH_MOVING_CONTACT_ACTOR ", actor.name)
		if "--sample" in OS.get_cmdline_user_args():
			break
	var expected_cases := 4 if "--sample" in OS.get_cmdline_user_args() or not selected_actor.is_empty() else (roster.get_child_count() - stationary_actors.size()) * 4
	if results.size() != expected_cases:
		errors.append("Expected " + str(expected_cases) + " cases; got " + str(results.size()))
	var report := {"passed": errors.is_empty() and not results.is_empty(), "cases": results.size(), "automatic_actor_updates": live_updates, "stationary_actors": stationary_actors, "results": results, "errors": errors, "scope": "actual Player and patrols after Suryagarh setup; household/coach updates paused; stationary residents excluded; body capsules, not cloth or sole approval"}
	var suffix := "_sample" if "--sample" in OS.get_cmdline_user_args() else ""
	if not selected_actor.is_empty():
		suffix = "_" + selected_actor.to_snake_case()
	if live_updates:
		suffix += "_live"
	if camera != null:
		suffix += "_metal"
	FileAccess.open("res://docs/characters/british/candidates/moving_contact" + suffix + "_validation.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  ") + "\n")
	print("BRITISH_MOVING_CONTACT ", JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
