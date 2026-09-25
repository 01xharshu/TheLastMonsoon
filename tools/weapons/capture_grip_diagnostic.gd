extends SceneTree
## Contact diagnostic on the current rejected runtime body; not character approval.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("GRIP CAPTURE BLOCKED: native renderer required")
		quit(1)
		return
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 10: await physics_frame
	var actor: CharacterBody3D = world.get_node("Player")
	actor.set_physics_process(false)
	var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
	visual.set_process(false)
	actor.get_node("UI").hide()
	for item in ["bow", "double_gun", "pistol"]:
		actor.inventory.add_item(item, 1)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 29.0
	camera.global_position = visual.model.to_global(Vector3(1.05, 1.55, 1.65))
	camera.look_at(visual.model.to_global(Vector3(0, 1.28, .22)))
	camera.current = true
	for selection in [2, 5, 3]:
		visual.equipment.select_weapon(selection)
		visual.equipment.aiming = selection != 2
		visual.equipment.aim_direction = visual.model.global_basis.z
		if selection == 2:
			visual.equipment.bow_hand.set_draw_fraction(1.0)
		for i in 15: visual._process(1.0 / 60.0)
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		var label: String = ["bow", "double_gun", "pistol"][[2, 5, 3].find(selection)]
		var path: String = "res://docs/characters/arjun/grip_diagnostic_" + label + ".png"
		assert(root.get_texture().get_image().save_png(path) == OK)
		print("GRIP DIAGNOSTIC ", path)
	quit()
