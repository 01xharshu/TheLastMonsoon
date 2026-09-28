extends SceneTree
## Full-world Player capsule approaches one military and one civil-ground NPC.

const OUTPUT := "res://docs/characters/british/candidates/player_collision_validation.json"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := load("res://world/suryagarh/suryagarh_world.tscn").instantiate() as Node3D
	root.add_child(world)
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
	var names := ["PrivateMan", "OfficialWoman"]
	if "--official-only" in OS.get_cmdline_user_args():
		names = ["OfficialWoman"]
	for name in names:
		var actor := roster.get_node(name) as Node3D
		actor.set_process(false)
		var collider := actor.get_node("BodyCollider") as AnimatableBody3D
		player.velocity = Vector3.ZERO
		player.global_position = actor.global_position + Vector3(0, 0.90, -1.6)
		await physics_frame
		collider.force_update_transform()
		var hit := player.move_and_collide(Vector3(0, 0, 3.2))
		if hit != null and hit.get_collider() == collider and hit.get_travel().length() < 1.6:
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
	var passed := stopped == names.size() and errors.is_empty()
	var report := {"passed": passed, "actual_player_stops": stopped, "sampled": names.size(), "errors": errors, "scope": "full-world Player capsule approach on Company Compound and Government House plots"}
	FileAccess.open(OUTPUT, FileAccess.WRITE).store_string(JSON.stringify(report, "  ") + "\n")
	print("BRITISH_PLAYER_COLLISION ", JSON.stringify(report))
	quit(0 if passed else 1)
