extends SceneTree
## Native renderer: fixed camera, no temporal fog/AO, image samples remain in RAM.
func _initialize() -> void: call_deferred("run")
func sample() -> PackedByteArray:
	for i in 12: await process_frame
	RenderingServer.force_draw()
	return root.get_texture().get_image().get_data()
func difference(a: PackedByteArray, b: PackedByteArray) -> int:
	var changed := 0
	for i in a.size():
		if abs(int(a[i]) - int(b[i])) > 3: changed += 1
	return changed
func run() -> void:
	root.size = Vector2i(256, 256)
	DisplayServer.window_set_size(Vector2i(256, 256))
	root.use_taa = false
	var scene := Node3D.new(); root.add_child(scene); current_scene = scene
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.04, 0.04, 0.04)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 1.0
	var lighting := WorldEnvironment.new(); lighting.environment = environment; scene.add_child(lighting)
	var plant := load("res://environment/forest/assets/fern_lod0.glb").instantiate() as Node3D
	scene.add_child(plant)
	var materials: Array[ShaderMaterial] = []
	for mesh: MeshInstance3D in plant.find_children("*", "MeshInstance3D", true, false):
		for index in mesh.mesh.get_surface_count():
			if not "Leaves" in str(mesh.get_active_material(index).resource_name): continue
			var material := ShaderMaterial.new()
			material.shader = preload("res://environment/forest/shaders/foliage.gdshader")
			material.set_shader_parameter("tint", Color(0.25, 0.55, 0.15))
			material.set_shader_parameter("wind_uv_reversed", true)
			material.set_shader_parameter("wind_strength", 0.0)
			mesh.set_surface_override_material(index, material); materials.append(material)
	var camera := Camera3D.new(); scene.add_child(camera)
	camera.position = Vector3(1.3, 0.85, 1.6); camera.look_at(Vector3(0, 0.45, 0)); camera.fov = 38; camera.make_current()
	var still_a := await sample(); var still_b := await sample()
	for material in materials: material.set_shader_parameter("wind_strength", load("res://environment/forest/config/benchmark.tres").wind_strength)
	var moving_a := await sample(); var moving_b := await sample()
	var still_delta := difference(still_a, still_b)
	var wind_delta := difference(moving_a, moving_b)
	print("FOREST_WIND_PIXELS stationary=", still_delta, " moving=", wind_delta)
	var passed := wind_delta > still_delta + 20
	if passed: print("FOREST_WIND_RENDER_PASS foliage changes under wind; fixed-camera baseline measured")
	scene.queue_free(); await process_frame
	quit(0 if passed else 1)
