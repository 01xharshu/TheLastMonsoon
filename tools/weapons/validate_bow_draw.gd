extends SceneTree
## Standalone Forward+/Metal capture of rest and full draw.
func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var bow: Node3D = load("res://environment/weapons/period_bow/bow_mechanism.gd").new()
	stage.add_child(bow)
	assert(is_equal_approx(bow.draw_fraction,0.0) and not bow.arrow.visible)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.38,0.40,0.39)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.86,0.87,0.84)
	environment.ambient_light_energy = 0.85
	world_environment.environment = environment
	stage.add_child(world_environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40,-25,0)
	light.light_energy = 1.4
	stage.add_child(light)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.7
	camera.position = Vector3(0,0.18,3)
	camera.look_at(Vector3.ZERO)
	camera.make_current()
	for value in [0.0,1.0]:
		bow.set_draw_fraction(value)
		assert(is_equal_approx(bow.draw_fraction,value))
		assert(bow.arrow.visible == (value > 0.0))
		if DisplayServer.get_name() != "headless":
			for i in 3: await process_frame
			await RenderingServer.frame_post_draw
			var path := "res://docs/characters/arjun/weapon_bow_%s_2026-09-23.png" % ("drawn" if value > 0 else "rest")
			assert(root.get_texture().get_image().save_png(path) == OK)
			print("BOW DRAW CAPTURE ",path)
	print("BOW DRAW: PASS | rest, nock, full string displacement")
	quit()
