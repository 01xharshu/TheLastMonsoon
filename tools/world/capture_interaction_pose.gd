extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("POSE CAPTURE: native renderer required")
		quit(1)
		return
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 15: await process_frame
	var actor: CharacterBody3D = world.get_node("Player")
	var chest: Interactable = world.get_node("Settlement/ColonialCompound/SecludedSupplyChest")
	actor.global_position = chest.global_position + Vector3(0,1,1.15)
	actor.get_node("VisualRoot").rotation.y = PI
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.global_position = chest.global_position + Vector3(3.2,1.9,3.8)
	camera.look_at(chest.global_position + Vector3(0,.7,.7))
	camera.make_current()
	actor._begin_interaction_hold(chest,"interact")
	Input.action_press("interact")
	for i in 48: await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://docs/world/captures/interaction_chest_kneel.png"
	assert(root.get_texture().get_image().save_png(path) == OK)
	print("POSE CAPTURE ",path)
	Input.action_release("interact")
	quit()
