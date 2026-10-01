extends SceneTree
## One native viewport per view, selected with TLM_PORT_VIEW, for reliable captures.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1600,900)
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	var player: CharacterBody3D = world.get_node("Player")
	player.set_physics_process(false)
	player.get_node("UI").hide()
	world.get_node("LandscapeUI").hide()
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 62
	camera.far = 6500
	camera.make_current()
	var selected := OS.get_environment("TLM_PORT_VIEW")
	if selected.is_empty(): selected = "overview"
	var ship: Node3D = world.get_node("HooghlyPort/MerchantShip")
	var views := {
		"overview":[Vector3(-244,38,748),Vector3(-130,10,680),Vector3(-100,4.22,684)],
		"ship":[Vector3(-37,20,627),Vector3(-85,15,680),Vector3(-88,4.22,678)],
		"deck":[ship.position+Vector3(-4,6,-9),ship.position+Vector3(0,4,12),ship.position+Vector3(-2.8,4.22,-4)],
		"hold":[ship.position+Vector3(1.5,1.1,11),ship.position+Vector3(-1,-0.1,-9),ship.position+Vector3(-1.8,-0.12,-7)],
		"cabin":[ship.position+Vector3(2.9,5.2,16.3),ship.position+Vector3(-1.2,4.0,21.3),ship.position+Vector3(0,4.22,18)],
		"sea":[Vector3(-95,5.4,710),Vector3(50,1.0,1400),Vector3(40,-0.25,817)]}
	var view: Array = views[selected]
	player.position = view[2]
	player.velocity = Vector3.ZERO
	player.visual_root.rotation.y = PI
	camera.position = view[0]
	camera.look_at(view[1])
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://docs/world/captures/hooghly_port_"+selected+".png"
	var error := root.get_texture().get_image().save_png(path)
	print("HOOGHLY PORT CAPTURE ",selected," ",error)
	quit(0 if error==OK else 1)
