extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	var player: Node3D = world.get_node("Player")
	player.set_physics_process(false)
	player.hide()
	for layer in world.find_children("*","CanvasLayer",true,false): layer.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var clock: GameTimeSystem = world.get_node("GameTimeSystem")
	clock.clock_paused = true
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 58
	camera.make_current()
	var home: Node3D = world.get_node("Settlement/BhairavpurHouse0")
	var views := [
		["village_former_pond_restored",12,Vector3(-438,19,170),Vector3(-411,7.2,187)],
		["village_estate_day",12,Vector3(-350,19,313),Vector3(-321,10,344)],
		["village_estate_courtyard",12,Vector3(-321,9.0,332),Vector3(-321,9.2,352)],
		["village_houses_night",21,Vector3(-351,10.5,196),Vector3(-331,9,214)],
		["village_lamp_spill",21,home.to_global(Vector3(0,1.65,8)),home.to_global(Vector3(.7,1.45,1.2))],
		["village_gathering_fire",21,Vector3(-397,9,235),Vector3(-393,7.6,230)],
		["village_estate_night",21,Vector3(-325,9.0,334),Vector3(-333,8.5,337)],
	]
	for view in views:
		clock.total_game_minutes = float(view[1])*60
		clock._update_readable_time(true)
		world.get_node("Sun")._update_day_night_lighting()
		camera.global_position = view[2]
		camera.look_at(view[3])
		for i in 20: await process_frame
		await RenderingServer.frame_post_draw
		var path: String = "res://docs/world/captures/"+str(view[0])+".png"
		assert(root.get_texture().get_image().save_png(path) == OK)
		print("VILLAGE LIFE CAPTURE ",path)
	world.queue_free()
	await process_frame
	quit()
