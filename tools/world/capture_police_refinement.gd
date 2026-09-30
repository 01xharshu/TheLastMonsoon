extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name()=="headless": quit(1); return
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var actor: Node3D = world.get_node("Player")
	actor.set_physics_process(false)
	actor.hide()
	actor.get_node("UI").hide()
	world.get_node("LandscapeUI").hide()
	var police: Node3D = world.get_node("Settlement/DistrictPolice")
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 65
	camera.make_current()
	var shots := [
		["masonry_vents",Vector3(24,6.8,25),Vector3(16,3.7,8)],
		["reception",Vector3(0,1.9,16.4),Vector3(2,1.1,9)],
		["records",Vector3(-7,1.85,-3.4),Vector3(-10.7,1.25,-7.8)],
		["duty_room",Vector3(-7,7.2,-2.7),Vector3(-11,6.6,-7)],
		["cellar",Vector3(6,-2.1,-6),Vector3(0,-2.6,-9)],
		["night_reception",Vector3(0,1.9,16.4),Vector3(3,1.4,9)]
	]
	for shot in shots:
		if shot[0]=="night_reception":
			world.get_node("GameTimeSystem").advance_hours(13.0)
		camera.global_position = police.to_global(shot[1])
		camera.look_at(police.to_global(shot[2]))
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		var path: String = "res://docs/world/captures/police_refinement_%s.png" % shot[0]
		var err := root.get_texture().get_image().save_png(path)
		print("POLICE REFINEMENT CAPTURE ",path," ",err)
		if err!=OK: quit(1); return
	quit(0)
