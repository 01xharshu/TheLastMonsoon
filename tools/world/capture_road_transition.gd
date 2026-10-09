extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var tag := "before" if "--before" in OS.get_cmdline_user_args() else "after"
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var scene := Node3D.new()
	viewport.add_child(scene)
	scene.add_child(load("res://world/suryagarh/generated/landscape.scn").instantiate())
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.39,.48,.56)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(.78,.84,.93)
	env.environment.ambient_light_energy = .45
	scene.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38,-32,0)
	scene.add_child(sun)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.fov = 65
	camera.make_current()
	var space := scene.get_world_3d().direct_space_state
	for i in 4: await physics_frame
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(486,180,-251),Vector3(486,80,-251)))
	assert(not hit.is_empty())
	var y: float = hit.position.y
	var views := [["walk",Vector3(486,y+1.65,-253),Vector3(502,y,-252)],["cut",Vector3(482,y+9,-235),Vector3(486,y,-251)]]
	DirAccess.make_dir_recursive_absolute("res://docs/world/captures/terrain_2026-10-08")
	for view in views:
		camera.position = view[1]
		camera.look_at(view[2])
		for i in 8: await process_frame
		RenderingServer.force_draw()
		assert(viewport.get_texture().get_image().save_png("res://docs/world/captures/terrain_2026-10-08/"+tag+"_"+view[0]+".png")==OK)
		print("ROAD CAPTURE ",tag," ",view[0])
	quit()
