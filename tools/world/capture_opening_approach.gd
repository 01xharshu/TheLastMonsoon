extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	await process_frame
	root.get_node("SaveManager").pending_slot = 0
	root.get_node("SaveManager").apply_pending(world)
	var opening = world.get_node("OpeningSequence")
	opening.set_process(false)
	opening.set_process_input(false)
	for t in [14.0,16.0,19.0,21.5,23.5]:
		opening.elapsed = t
		opening._process(0.0)
		await create_timer(0.3).timeout
		var local_camera: Vector3 = opening.home.to_local(opening.camera.global_position)
		assert(local_camera.z < 3.41 and absf(local_camera.x) < 4.56,"Camera crossed the room wall")
		print("INTERIOR CAMERA PASS at ", t, " | ", local_camera)
		opening._process(0.0)
		assert(opening.state == "night", "Capture unexpectedly left the night sequence")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/world/captures/opening_interior_%02d.png" % int(t))
	print("OPENING APPROACH CAPTURE COMPLETE")
	quit()
