extends SceneTree
## Runs the actual title-menu journey callback. Reads existing saves; writes none.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var saves: Node = root.get_node("SaveManager")
	assert(saves.WORLD == "res://world/suryagarh/suryagarh_world.tscn")
	var existing_slot: int = saves.newest_slot()
	var slots: Array[int] = [0]
	if existing_slot > 0: slots.append(existing_slot)
	for slot in slots:
		var menu: Node = await preload("res://tools/maintenance/startup_fixture.gd").open_title(self)
		if menu == null:
			saves.quit_game(1)
			return
		menu._begin_journey(slot)
		while current_scene == null or current_scene.scene_file_path != saves.WORLD:
			await process_frame
		var world: Node3D = current_scene
		for frame in range(4): await process_frame
		var flock: Node3D = world.get_node("SkyBirds")
		var sun: DirectionalLight3D = world.get_node("Sun")
		assert(flock.birds.size() == 60)
		assert(flock.game_time == world.get_node("GameTimeSystem"))
		assert(sun.sky_material.shader.resource_path == "res://world/suryagarh/shaders/day_night_sky.gdshader")
		assert(world.get_node("WorldEnvironment").environment.sky.sky_material == sun.sky_material)
		var clock: GameTimeSystem = world.get_node("GameTimeSystem")
		var elevation := sin((clock.get_time_of_day_fraction()-0.25)*TAU)
		assert(is_equal_approx(flock.activity,smoothstep(-0.12,0.08,elevation)))
		assert(is_equal_approx(float(sun.sky_material.get_shader_parameter("night_visibility")),1.0-smoothstep(-0.3,0.02,elevation)))
		print("MAIN SKY INTEGRATION PASS | ","New Journey" if slot == 0 else "Continue existing save"," | birds + world clock + moon/star shader")
		preload("res://tools/test_audio_cleanup.gd").stop(root)
		world.queue_free()
		current_scene = null
		await process_frame
	if existing_slot == 0: print("Continue runtime not exercised: no existing save; shared WORLD destination verified")
	preload("res://tools/test_audio_cleanup.gd").finish(self)
