extends SceneTree
var output_dir := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output-dir="): output_dir = arg.trim_prefix("--output-dir=")
	if not output_dir.is_empty() and not (output_dir.begins_with(OS.get_temp_dir()) or output_dir.begins_with("/tmp/")):
		push_error("Stance review output must use an OS temporary directory")
		quit(1)
		return
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 18: await process_frame
	var actor: CharacterBody3D = world.get_node("Player")
	var chest: Interactable = world.get_node("Settlement/ColonialCompound/SecludedSupplyChest")
	actor.global_position = chest.global_position+Vector3(0,1,1.1)
	actor.get_node("VisualRoot").rotation.y = PI
	actor.get_node("CameraPivot").rotation.y = 0.0
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.global_position = chest.global_position+Vector3(3.6,1.8,3.1)
	camera.look_at(chest.global_position+Vector3(0,.6,.7))
	camera.make_current()
	for i in 8: await process_frame
	var stance: Node = actor.get_node("StealthStance")
	if not stance.try_cover():
		push_error("COVER CAPTURE: no cover surface")
		quit(1)
		return
	for i in 45: await process_frame
	await _shot("arjun_cover_crate")
	Input.action_press("aim")
	for i in 24: await process_frame
	await _shot("arjun_cover_aim")
	Input.action_release("aim")
	stance.stand()
	actor.global_position += Vector3(0,0,.8)
	stance.enter_prone()
	for i in 50: await process_frame
	await _shot("arjun_prone")
	quit()

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	if output_dir.is_empty(): return
	var path := output_dir+"/"+name+".png"
	assert(root.get_texture().get_image().save_png(path) == OK)
	print("STANCE CAPTURE ",path)
