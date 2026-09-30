extends SceneTree
## Actual-world architecture and workshop close views at 720p.

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	var player: CharacterBody3D = world.get_node("Player")
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.hide()
	for layer in world.find_children("*","CanvasLayer",true,false): layer.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	world.get_node("GameTimeSystem").clock_paused = true
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 58
	camera.make_current()
	var home: Node3D = world.get_node("Settlement/BhairavpurHouse0")
	var views := [
		["village_detail_overview",Vector3(-455,58,350),Vector3(-331,8,235)],
		["village_detail_roof_street",Vector3(-328,13.5,186),Vector3(-321,9,214)],
		["village_detail_tile_gable",Vector3(-348,11.5,203),Vector3(-343,9,214)],
		["village_detail_thatch",Vector3(-326,12.5,200),Vector3(-321,9.5,214)],
		["village_detail_terrace",Vector3(-297,12,199),Vector3(-299,10,214)],
		["village_detail_pottery",Vector3(-339,9.1,174),Vector3(-340.75,8.05,170.5)],
		["village_detail_weaving",Vector3(-317,9.4,307),Vector3(-318.75,8.15,303.5)],
		["village_detail_carpentry",Vector3(-246,9.6,283),Vector3(-241.2,8.1,280.25)],
		["village_detail_interior",home.to_global(Vector3(0,1.6,2.1)),home.to_global(Vector3(0,1.0,-1.3))],
		["village_detail_market",Vector3(-322,11,275),Vector3(-310,8.5,283)],
	]
	for view in views:
		camera.global_position = view[1]
		camera.look_at(view[2])
		for i in 16: await process_frame
		await RenderingServer.frame_post_draw
		var path: String = "res://docs/world/captures/"+str(view[0])+".png"
		assert(root.get_texture().get_image().save_png(path) == OK,path)
		print("VILLAGE DETAIL CAPTURE ",path)
	world.queue_free()
	await process_frame
	quit()
