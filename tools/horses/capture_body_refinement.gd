extends SceneTree
## Native renderer, actual horse/tack script; isolates body review from world startup.
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.34,.40,.45)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(.80,.85,.9)
	environment.environment.ambient_light_energy = .5
	scene.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-35,0)
	sun.shadow_enabled = true
	scene.add_child(sun)
	var floor_ := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40,40)
	floor_.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(.30,.33,.24)
	floor_.material_override = material
	scene.add_child(floor_)
	var horse := CharacterBody3D.new()
	horse.set_script(preload("res://horses/stable_horse.gd"))
	scene.add_child(horse)
	horse.set_physics_process(false)
	var stage := "after" if "--after" in OS.get_cmdline_user_args() else "before"
	if stage == "after":
		var replacement: Node3D = load("res://assets/animals/horse/horse_body_refinement.glb").instantiate()
		replacement.transform = horse.rigged_model.transform
		horse.rigged_model.free()
		horse.body_root.add_child(replacement)
		horse.rigged_model = replacement
		horse.rigged_anim = replacement.find_child("AnimationPlayer",true,false)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.fov = 48
	camera.make_current()
	for view in [["side",Vector3(-5,2.2,0)],["front",Vector3(0,2.2,-5)],["quarter",Vector3(-4,2.5,-3)]]:
		horse.rigged_anim.play("AnimalArmature|Idle")
		horse.rigged_anim.seek(.25,true)
		horse.rigged_anim.pause()
		camera.global_position = view[1]
		camera.look_at(Vector3.UP*1.3)
		for i in 12: await process_frame
		await RenderingServer.frame_post_draw
		var path: String = "res://docs/world/captures/horse_body_"+stage+"_"+view[0]+".png"
		assert(root.get_texture().get_image().save_png(path)==OK)
		print("HORSE BODY CAPTURE ",path)
	scene.queue_free()
	await process_frame
	quit()
