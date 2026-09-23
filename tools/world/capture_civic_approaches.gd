extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Civic captures require a rendering backend")
		quit(1)
		return
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.get_node("Player").set_physics_process(false)
	world.get_node("Player/UI").hide()
	world.get_node("LandscapeUI").hide()
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 62.0
	camera.make_current()
	var views := [
		{"name":"11_town_hall_approach","eye":Vector3(-306,15,-420),"target":Vector3(-320,12,-469)},
		{"name":"12_police_approach","eye":Vector3(337,17,174),"target":Vector3(320,14,123)},
		{"name":"13_compound_gate","eye":Vector3(345,19,200),"target":Vector3(345,15,270)},
	]
	for view in views:
		camera.position = view.eye
		camera.look_at(view.target)
		for i in 12: await process_frame
		await RenderingServer.frame_post_draw
		var path: String = "res://docs/world/captures/"+view.name+".png"
		var err := root.get_texture().get_image().save_png(path)
		assert(err==OK,path)
		print("CIVIC CAPTURE ",path)
	quit()
