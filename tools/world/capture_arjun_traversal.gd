extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func capture(name: String) -> void:
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "res://docs/world/captures/" + name + ".png"
	print("CAPTURE ", path, " ", image.save_png(path))

func _run() -> void:
	var world := preload("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 15: await physics_frame
	var horse: CharacterBody3D = world.get_node("VillageHorse")
	var actor: CharacterBody3D = world.get_node("Player")
	var clear_at := horse.global_position + Vector3(12, 0, 0)
	clear_at.y = horse.layout.height(clear_at.x, clear_at.z) + 0.9
	horse.global_position = clear_at
	horse.velocity = Vector3.ZERO
	actor.global_position = horse.global_position + horse.global_basis.x * 1.8 + Vector3.UP
	actor.get_node("UI").hide()
	world.get_node("LandscapeUI").hide()
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	camera.global_position = horse.global_position + horse.global_basis.x * 5.0 + horse.global_basis.z * 3.0 + Vector3.UP * 2.4
	camera.look_at(horse.global_position + Vector3.UP * 1.5)
	for i in 4: await physics_frame
	if not horse.board(actor):
		push_error("Capture: boarding failed")
		quit(1)
		return
	for i in 20: await physics_frame
	await capture("20_horse_mount_transition")
	for i in 40: await physics_frame
	await capture("21_horse_saddle_arrival")
	for i in 20: await physics_frame
	if not horse.dismount():
		push_error("Capture: dismount failed")
		quit(1)
		return
	for i in 20: await physics_frame
	await capture("22_horse_dismount_transition")
	quit()
