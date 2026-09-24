extends SceneTree

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("CART CAPTURE BLOCKED: native renderer required")
		quit(1)
		return
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(24,18)
	ground.mesh = plane
	var earth := StandardMaterial3D.new()
	earth.albedo_color = Color(.47,.40,.30)
	ground.material_override = earth
	stage.add_child(ground)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-32,0)
	sun.light_energy = 1.9
	stage.add_child(sun)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(.65,.72,.73)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(.79,.77,.70)
	env.ambient_light_energy = .8
	environment.environment = env
	stage.add_child(environment)
	var cart_script: Script = load("res://vehicles/horse_cart_candidate.gd")
	for i in 2:
		var cart: Node3D = cart_script.new()
		cart.variant = i
		cart.name = "PassengerEkka" if i == 0 else "OpenGoodsCart"
		cart.position.x = -3.1 if i == 0 else 3.1
		stage.add_child(cart)
	var camera := Camera3D.new()
	camera.position = Vector3(10,5,11)
	camera.fov = 53
	stage.add_child(camera)
	camera.look_at(Vector3(0,1,0))
	camera.make_current()
	for i in 24: await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://docs/world/captures/horse_cart_candidates.png"
	var err := root.get_texture().get_image().save_png(path)
	assert(err == OK)
	print("CART CANDIDATES CAPTURE ",path)
	for i in 2:
		var x := -3.1 if i == 0 else 3.1
		camera.position = Vector3(x+6,3.5,8)
		camera.look_at(Vector3(x,1.15,.5))
		for frame in 8: await process_frame
		await RenderingServer.frame_post_draw
		var detail_path := "res://docs/world/captures/horse_cart_%s.png" % ("ekka" if i == 0 else "goods")
		assert(root.get_texture().get_image().save_png(detail_path) == OK)
		print("CART CANDIDATES CAPTURE ",detail_path)
	quit()
