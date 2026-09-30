extends SceneTree
## Full-world Player capsule approaches one military and one civil-ground NPC.

const OUTPUT := "res://docs/characters/british/candidates/player_collision_validation.json"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := load("res://world/suryagarh/suryagarh_world.tscn").instantiate() as Node3D
	root.add_child(world)
	for startup_frame in 4:
		await process_frame
	# Finish household placement before freezing the contact fixture; coach
	# updates must not relocate a sampled resident during a manual approach.
	world.set_process(false)
	world.set_physics_process(false)
	for child in world.find_children("*", "", true, false):
		child.set_process(false)
		child.set_physics_process(false)
	await physics_frame
	var player := world.get_node("Player") as CharacterBody3D
	var roster := world.get_node("BritishNpcRosterCandidate") as Node3D
	player.set_process(false)
	player.set_physics_process(false)
	var camera: Camera3D
	if DisplayServer.get_name() != "headless":
		world.get_node("Player/UI").hide()
		world.get_node("LandscapeUI").hide()
		camera = Camera3D.new()
		world.add_child(camera)
		camera.fov = 42.0
		camera.make_current()
	var errors: Array[String] = []
	var stopped := 0
	var walking_stops := 0
	var names := ["PrivateMan", "OfficialWoman"]
	if "--all" in OS.get_cmdline_user_args():
		names.clear()
		for actor in roster.get_children():
			names.append(str(actor.name))
	if "--official-only" in OS.get_cmdline_user_args():
		names = ["OfficialWoman"]
	for name in names:
		var actor := roster.get_node(name) as Node3D
		actor.set_process(false)
		var collider := actor.get_node("BodyCollider") as AnimatableBody3D
		player.velocity = Vector3.ZERO
		player.global_position = actor.global_position + Vector3(0, 0.90, -1.6)
		var ground_query := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 3.0, player.global_position - Vector3.UP * 3.0, 1)
		ground_query.exclude = [player.get_rid(), collider.get_rid()]
		var ground := world.get_world_3d().direct_space_state.intersect_ray(ground_query)
		if not ground.is_empty():
			player.global_position.y = ground.position.y + 0.91
		await physics_frame
		collider.force_update_transform()
		player.force_update_transform()
		# Let the physics broadphase consume both teleports before the sweep.
		await physics_frame
		var approach_start := player.global_position
		var hit := player.move_and_collide(Vector3(0, 0, 3.2))
		var sweep_stopped := hit != null and hit.get_collider() == collider and hit.get_travel().length() < 1.6
		player.global_position = approach_start
		player.force_update_transform()
		await physics_frame
		var walked_into_npc := false
		for step in 100:
			player.velocity = Vector3(0, -0.2, 2.0)
			player.move_and_slide()
			for index in player.get_slide_collision_count():
				if player.get_slide_collision(index).get_collider() == collider:
					walked_into_npc = true
			await physics_frame
		if walked_into_npc and player.global_position.z < actor.global_position.z:
			walking_stops += 1
		else:
			errors.append(name + ": ordinary walking did not remain blocked")
		if sweep_stopped:
			stopped += 1
			if camera != null:
				camera.global_position = actor.global_position + Vector3(2.6, 2.1, -3.7)
				camera.look_at(actor.global_position + Vector3(0, 1.0, -0.45))
				for i in 12:
					await process_frame
				await RenderingServer.frame_post_draw
				var image_path: String = "res://docs/characters/british/candidates/" + str(name).to_snake_case() + "_player_block.png"
				var image_error := root.get_texture().get_image().save_png(image_path)
				if image_error != OK:
					errors.append(name + ": capture failed " + str(image_error))
		else:
			errors.append(name + ": Player did not stop at NPC; hit=" + (str(hit.get_collider().name) if hit != null else "none") + " actor=" + str(actor.global_position) + " collider=" + str(collider.global_position) + " player=" + str(player.global_position) + " mask=" + str(player.collision_mask) + " layer=" + str(collider.collision_layer) + " player_shape=" + str((player.get_node("CollisionShape3D") as CollisionShape3D).global_position) + " npc_shape=" + str((collider.get_node("BodyShape") as CollisionShape3D).global_position) + " npc_shapes=" + str(PhysicsServer3D.body_get_shape_count(collider.get_rid())) + " same_space=" + str(PhysicsServer3D.body_get_space(player.get_rid()) == PhysicsServer3D.body_get_space(collider.get_rid())))
	var passed := stopped == names.size() and walking_stops == names.size() and errors.is_empty()
	var report := {"passed": passed, "actual_player_stops": stopped, "ordinary_walking_stops": walking_stops, "walking_physics_steps_per_actor": 100, "sampled": names.size(), "actors": names, "errors": errors, "scope": "full-world Player sweep and 2 m/s walking from ray-surveyed ground height"}
	var output := OUTPUT if DisplayServer.get_name() == "headless" else OUTPUT.replace("_validation.json", "_metal_validation.json")
	if "--all" in OS.get_cmdline_user_args():
		output = output.replace("player_collision_", "player_collision_all_")
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(report, "  ") + "\n")
	print("BRITISH_PLAYER_COLLISION ", JSON.stringify(report))
	quit(0 if passed else 1)
