extends SceneTree
## Run with the project Forward+/Metal renderer to verify the placed existing asset.
func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var world = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	var player = world.get_node("Player")
	var bed = world.get_node("Charpai")
	var clock = world.get_node("GameTimeSystem")
	clock.clock_paused = true
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.visible = false
	player.get_node("UI").hide()
	world.get_node("LandscapeUI").hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 10: await physics_frame
	var contacts: Array = []
	for child in bed.get_node("CharpaiVisual").find_children("Leg_*", "MeshInstance3D", true, false):
		if child is MeshInstance3D and str(child.name).begins_with("Leg_"):
			var aabb: AABB = child.get_aabb()
			var foot: Vector3 = child.to_global(Vector3(aabb.get_center().x, aabb.position.y, aabb.get_center().z))
			var query = PhysicsRayQueryParameters3D.create(foot + Vector3.UP, foot - Vector3.UP)
			query.exclude = [bed.get_rid()]
			var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
			assert(not hit.is_empty(), "Missing ground under charpai leg")
			var gap: float = foot.y - hit.position.y
			assert(absf(gap) < 0.01, "Charpai foot does not contact terrain")
			contacts.append({"leg":str(child.name), "gap_m":gap})
	assert(contacts.size() == 4)
	var query = PhysicsRayQueryParameters3D.create(bed.position + Vector3(0,2,0), bed.position)
	assert(world.get_world_3d().direct_space_state.intersect_ray(query).get("collider") == bed)
	var survival = player.get_node("SurvivalComponent")
	survival.energy = 20.0
	var before: float = clock.total_game_minutes
	player.visible = true
	var pose_camera := Camera3D.new()
	world.add_child(pose_camera)
	pose_camera.global_position = bed.to_global(Vector3(2.7, 2.0, 2.5))
	pose_camera.look_at(bed.to_global(Vector3(0, 0.65, 0)))
	pose_camera.make_current()
	bed.interact(player)
	assert(bed.resting and player.get_meta("rest_action", "") == "sleep")
	assert(is_equal_approx(clock.total_game_minutes, before), "Time jumped before the sitting animation")
	await create_timer(0.32).timeout
	await RenderingServer.frame_post_draw
	var output_dir := OS.get_environment("TLM_TEST_OUTPUT_DIR")
	if output_dir != "":
		DirAccess.make_dir_recursive_absolute(output_dir)
		root.get_texture().get_image().save_png(output_dir.path_join("charpai_sitting.png"))
	await create_timer(0.68).timeout
	assert(float(player.get_meta("rest_progress", 0.0)) > 0.9, "Sleep pose did not complete")
	assert(is_equal_approx(clock.total_game_minutes, before), "Time jumped before fade-out")
	await RenderingServer.frame_post_draw
	if output_dir != "":
		root.get_texture().get_image().save_png(output_dir.path_join("charpai_sleeping.png"))
	await create_timer(0.85).timeout
	assert(bed.get_meta("sleep_fade_covered", false), "Clock advanced without covered fade")
	assert(is_equal_approx(clock.total_game_minutes - before, 480.0))
	await create_timer(1.7).timeout
	assert(not bed.resting and player.get_meta("rest_action", "") == "", "Rest did not release player")
	assert(survival.energy > 20.0)
	var report = {"position":str(bed.position), "leg_contacts":contacts, "collision":true, "sleep_hours":8, "energy_after_sleep":survival.energy}
	print("CHARPAI CHECK PASS ", JSON.stringify(report))
	if output_dir != "":
		var file := FileAccess.open(output_dir.path_join("charpai_validation.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"\t") + "\n")
	quit()
