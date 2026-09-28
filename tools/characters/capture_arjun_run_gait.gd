extends SceneTree
## One-frame native-renderer check of the temporary rig's run pose.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("RUN GAIT CAPTURE: native renderer required")
		quit(1)
		return
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(.22,.25,.24)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(.8,.8,.78)
	environment.environment = env
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40,-30,0)
	sun.light_energy = 1.8
	stage.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(8,8)
	ground.mesh = plane
	ground.position.y = -0.38
	stage.add_child(ground)
	var model: Node3D = load("res://characters/arjun/arjun.glb").instantiate()
	stage.add_child(model)
	var tree: AnimationTree = load("res://player/arjun_motion_tree.gd").new()
	model.add_child(tree)
	if not tree.configure(model):
		quit(1)
		return
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(2.7,1.0,0)
	camera.look_at(Vector3(0,0,0))
	camera.current = true
	for i in 15:
		tree.update_motion(1.0/30.0,1.75,0.0,false)
	model.position.y = -tree.foot_contact_offset
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://docs/characters/arjun/animation_tree_run_side.png"
	assert(root.get_texture().get_image().save_png(path) == OK)
	print("RUN GAIT CAPTURE ", path)
	quit()
