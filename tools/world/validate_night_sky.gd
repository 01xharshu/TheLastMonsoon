extends SceneTree
var scene: Node3D
var sun: DirectionalLight3D
var camera: Camera3D
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	scene = Node3D.new()
	root.add_child(scene)
	var clock := preload("res://world/suryagarh/systems/game_time_system.gd").new()
	clock.name = "GameTimeSystem"
	clock.starting_hour = 22
	scene.add_child(clock)
	clock.set_process(false)
	var environment := WorldEnvironment.new()
	environment.name = "WorldEnvironment"
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_SKY
	environment.environment.sky = Sky.new()
	scene.add_child(environment)
	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	scene.add_child(moon)
	sun = preload("res://world/suryagarh/systems/sun_controller.gd").new()
	sun.name = "Sun"
	scene.add_child(sun)
	assert(sun.sky_material.get_shader_parameter("night_visibility") > 0.99)
	assert(moon.global_basis.z.y > 0.0)
	camera = Camera3D.new()
	scene.add_child(camera)
	camera.look_at(moon.global_basis.z)
	for i in range(30): await process_frame
	if OS.get_environment("MONSOON_SKY_REVIEW") != "":
		root.get_texture().get_image().save_png(OS.get_environment("MONSOON_SKY_REVIEW"))
	clock.total_game_minutes = 12.0 * 60.0
	sun._update_day_night_lighting()
	assert(sun.sky_material.get_shader_parameter("night_visibility") < 0.01)
	assert(sun.sky_material.get_shader_parameter("sun_visibility") > 0.99)
	for hour in range(24):
		clock.total_game_minutes = hour * 60.0
		sun._process(0.001)
		assert(is_equal_approx(sun.last_lighting_minutes, clock.total_game_minutes))
		if hour >= 7 and hour <= 17:
			assert(sun.sky_material.get_shader_parameter("night_visibility") < 0.01)
			assert(moon.light_energy == 0.0)
		if hour <= 4 or hour >= 20:
			assert(sun.sky_material.get_shader_parameter("night_visibility") > 0.99)
			assert(moon.global_basis.z.y > 0.0)
	clock.total_game_minutes = 1440.0
	sun._process(0.001)
	var midnight_direction: Vector3 = sun.sky_material.get_shader_parameter("moon_direction")
	clock.total_game_minutes = 0.0
	sun._process(0.001)
	assert(midnight_direction.is_equal_approx(sun.sky_material.get_shader_parameter("moon_direction")))
	var unchanged: float = sun.last_lighting_minutes
	sun._process(10.0)
	assert(sun.last_lighting_minutes == unchanged)
	print("NIGHT SKY PASS: 24h horizon/light/visibility, forward/backward jumps, midnight continuity, paused clock")
	scene.queue_free()
	await process_frame
	preload("res://tools/test_audio_cleanup.gd").stop(root)
	await preload("res://tools/test_audio_cleanup.gd").settle(self)
	quit()
