extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	var actor: Node3D = world.get_node("Player")
	actor.set_physics_process(false)
	actor.hide()
	actor.get_node("UI").hide()
	var police: Node3D = world.get_node("Settlement/DistrictPolice")
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 60
	camera.make_current()
	var shots := [
		["exterior", Vector3(33,19,44), Vector3(0,4,0)],
		["lower_cells", Vector3(7,-2,-6), Vector3(0,-2,-9)],
		["stairs", Vector3(9,2,9), Vector3(12,-2,-1)],
		["ammunition", Vector3(16,1.6,-8.5), Vector3(16,1.03,-11)]
	]
	for shot in shots:
		camera.global_position = police.to_global(shot[1])
		camera.look_at(police.to_global(shot[2]))
		for i in 4: await process_frame
		RenderingServer.force_draw()
		var path: String = "/tmp/tlm_police_%s_2026-09-30.png" % shot[0]
		assert(root.get_texture().get_image().save_png(path) == OK)
		print("POLICE CAPTURE ", path)
	quit()
