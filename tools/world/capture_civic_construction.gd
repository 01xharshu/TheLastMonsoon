extends SceneTree
## Fresh main-world views of the civic construction continuation.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_size = Vector2i(1280,720)
	root.size = Vector2i(1280,720)
	var world = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 6: await physics_frame
	world.get_node("Player").set_physics_process(false)
	world.get_node("Player").hide()
	world.get_node("Player/UI").hide()
	world.get_node("LandscapeUI").hide()
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	for name in ["TownHall","DistrictPolice"]:
		var building: Node3D = world.get_node("Settlement/"+name)
		var views := [
			["exterior",Vector3(18,13,37),Vector3(0,4,0)],
			["interior",Vector3(-6,2.6,11),Vector3(-7,3,-8)],
			["upper",Vector3(-5,7.5,9),Vector3(4,9.2,-5)],
			["drain",Vector3(building.width*.5+4,2,-building.depth*.5+5),Vector3(building.width*.5+.5,0,-building.depth*.5+.5)]
		]
		for view in views:
			camera.global_position = building.to_global(view[1])
			camera.look_at(building.to_global(view[2]))
			for i in 4: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/world/captures/civic_construction_"+name+"_"+view[0]+".png")
	print("CIVIC CONSTRUCTION CAPTURES PASS")
	quit()
