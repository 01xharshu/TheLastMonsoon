extends SceneTree
## Native-renderer check of the populated-world prompt and shared collection feed.

func _initialize() -> void:
	_capture.call_deferred()

func _capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("CLEAN INTERACTION UI: native renderer required")
		quit(1)
		return
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	var actor: CharacterBody3D = world.get_node("Player")
	var chest: Interactable = world.get_node("Settlement/ColonialCompound/SecludedSupplyChest")
	actor.global_position = chest.global_position + Vector3(0, 1.0, 2.1)
	actor.get_node("VisualRoot").rotation.y = PI
	actor.set_physics_process(false)
	actor.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.global_position = chest.global_position + Vector3(2.8, 2.3, 4.4)
	camera.look_at(chest.global_position + Vector3.UP * 0.6)
	camera.make_current()
	for i in 30:
		await physics_frame
	actor.interaction_overlay.set_target(chest)
	await _shot("/tmp/tlm_clean_chest_prompt.png")
	chest.interact(actor)
	for i in 8:
		await process_frame
	await _shot("/tmp/tlm_clean_chest_rewards.png")
	actor.interaction_overlay.rewards.clear()
	actor.interaction_overlay.reward_timer = 0.0
	var mango: Interactable = load("res://objects/mango.gd").new()
	world.add_child(mango)
	mango.global_position = actor.global_position + Vector3(0, -0.9, -0.65)
	mango.interact(actor)
	for i in 4:
		await process_frame
	await _shot("/tmp/tlm_clean_mango_reward.png")
	print("CLEAN INTERACTION UI: captured prompt, chest and mango rewards")
	quit()

func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(path)
	assert(result == OK)
	print("CLEAN INTERACTION CAPTURE ", path)
