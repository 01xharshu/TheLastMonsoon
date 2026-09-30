extends SceneTree
## Deterministic 30 fps studio review of a complete patrol and both turns.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.16, 0.19, 0.22)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.6
	stage.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	light.shadow_enabled = true
	stage.add_child(light)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	floor_mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.32, 0.35, 0.38)
	floor_mesh.material_override = material
	stage.add_child(floor_mesh)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 5.1
	camera.position = Vector3(4, 2.7, 5)
	camera.look_at(Vector3(0, 0.85, -0.45))
	camera.make_current()
	var script := load("res://characters/npcs/british/british_npc_actor.gd")
	var actors: Array[Node3D] = []
	for kind in ["man", "woman"]:
		var actor := Node3D.new()
		actor.set_script(script)
		actor.position.x = -1.05 if kind == "man" else 1.05
		actor.set("movement_profile", &"male" if kind == "man" else &"female")
		actor.set("patrol_distance", 0.9)
		actor.set("patrol_axis", Vector3(0, 0, -1))
		actor.add_child(load("res://characters/npcs/british/private_" + kind + ".glb").instantiate())
		stage.add_child(actor)
		actor.set_process(false)
		actors.append(actor)
	for frame in 330:
		for actor in actors:
			actor.call("_process", 1.0 / 30.0)
		await RenderingServer.frame_post_draw
	print("BRITISH_MOTION_CAPTURE complete: 11 seconds at fixed 30 fps; studio flat ground")
	quit()
