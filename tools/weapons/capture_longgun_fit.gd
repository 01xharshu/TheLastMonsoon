extends SceneTree
## Diagnostic captures on the temporary, owner-rejected Arjun body.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("LONG GUN FIT CAPTURE: native renderer required")
		quit(1)
		return
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 12: await physics_frame
	var actor: CharacterBody3D = world.get_node("Player")
	actor.set_physics_process(false)
	var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
	visual.set_process(false)
	actor.get_node("UI").hide()
	for item in ["enfield", "double_gun"]: actor.inventory.add_item(item, 1)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 43.0
	camera.current = true
	for entry in [{"name":"enfield","slot":1},{"name":"double_gun","slot":5}]:
		visual.equipment.select_weapon(entry.slot)
		visual.equipment.aiming = true
		visual.equipment.aim_direction = visual.model.global_basis.z
		for i in 18: visual._process(1.0/60.0)
		for view in [{"name":"side","eye":Vector3(-2.35,1.55,1.0)}, {"name":"shoulder","eye":Vector3(-1.15,1.70,-2.20)}, {"name":"hands","eye":Vector3(-0.95,1.48,0.58)}]:
			camera.global_position = visual.model.to_global(view.eye)
			camera.look_at(visual.model.to_global(Vector3(0,1.42,.22)))
			camera.fov = 30.0 if view.name == "hands" else 43.0
			for i in 3: await process_frame
			await RenderingServer.frame_post_draw
			var path: String = "res://docs/characters/arjun/longgun_" + entry.name + "_" + view.name + ".png"
			assert(root.get_texture().get_image().save_png(path) == OK)
			print("LONG GUN FIT ", entry.name, " ", view.name, " grip=", visual.equipment.grip_errors())
	quit()
