extends SceneTree
var output_dir := OS.get_environment("TLM_RIVER_TEST_OUTPUT")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	if output_dir.is_empty():
		push_error("Run with temporary TLM_RIVER_TEST_OUTPUT; caller must clean it in finally")
		quit(1);return
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var scene := load("res://characters/npcs/indian/river_routine_review.tscn").instantiate() as Node3D
	var viewport := SubViewport.new()
	viewport.name = "RiverReviewViewport"
	viewport.size = Vector2i(1280,720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(scene)
	current_scene = viewport
	for woman in scene.women: woman.set_process(false)
	if "--record" in OS.get_cmdline_user_args():
		await record(scene)
		return
	for entry in [["depart", 5.0], ["fill", 17.0], ["wash", 29.0], ["rub", 24.8], ["rinse", 26.0], ["wring", 28.0], ["talk", 43.0], ["pickup", 52.8], ["return", 60.0]]:
		for woman in scene.women:
			woman.sample(float(entry[1]))
		var center: Vector3 = scene.women[1].global_position
		var camera: Camera3D = scene.get_node("ReviewCamera")
		camera.global_position = center + Vector3(3.5, 2.1, 4.8 if entry[0] == "return" else -4.8)
		camera.look_at(center + Vector3(0, .7, 0))
		await process_frame
		RenderingServer.force_draw(false)
		var path := output_dir+"/river_%s.png" % entry[0]
		var picture := (scene.get_parent() as SubViewport).get_texture().get_image()
		picture.resize(1280, 720)
		var error := picture.save_png(path)
		print("RIVER_CAPTURE ", error, " ", path)
		if error != OK:
			quit(1)
			return
	quit()

func record(scene: Node3D) -> void:
	(scene.get_parent() as SubViewport).size = Vector2i(854,480)
	var folder := output_dir+"/frames"
	DirAccess.make_dir_recursive_absolute(folder)
	for woman in scene.women: woman.sample(0.0)
	for frame in 1095:
		for woman in scene.women: woman.tick_routine(1.0/15.0)
		var actor: Node3D = scene.women[1]
		var camera: Camera3D = scene.get_node("ReviewCamera")
		camera.global_position = actor.global_position+actor.global_basis*Vector3(3.5, 2.1, -4.8)
		camera.look_at(actor.global_position+Vector3(0,.6,0))
		await process_frame
		RenderingServer.force_draw(false)
		var picture := (scene.get_parent() as SubViewport).get_texture().get_image()
		picture.resize(854,480)
		var error := picture.save_png(folder+"/frame_%04d.png" % frame)
		if error != OK:
			push_error("Cannot save river sequence frame")
			quit(1)
			return
		if frame%150 == 0: print("RIVER_SEQUENCE frame ", frame, " action ", actor.action)
	print("RIVER_SEQUENCE_COMPLETE 1095 frames at 15fps; simulated 1.0x, not hardware performance evidence")
	quit()
