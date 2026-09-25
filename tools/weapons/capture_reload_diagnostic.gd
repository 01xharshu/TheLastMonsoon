extends SceneTree
## Internal motion diagnostic only: current Arjun appearance is owner-rejected.
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	var actor: CharacterBody3D = world.get_node("Player")
	actor.set_physics_process(false)
	actor.get_node("UI").hide()
	var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 47.0
	camera.global_position = actor.global_position + Vector3(2.0,1.65,2.4)
	camera.look_at(actor.global_position + Vector3(0,1.05,0))
	camera.make_current()
	actor.inventory.add_item("enfield",1)
	actor.inventory.add_item("pistol",1)
	for weapon in [1,3]:
		visual.equipment.selected = weapon
		visual.equipment.stowed = false
		visual.equipment._refresh()
		var combat: Node = actor.get_node("RifleCombat" if weapon == 1 else "PistolCombat")
		combat.set_process(false)
		combat.reload_remaining = 1.8 if weapon == 1 else 1.5
		for i in 8: visual._process(1.0/60.0)
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		var path := "/tmp/tlm_%s_reload_diagnostic.png" % ("enfield" if weapon == 1 else "adams")
		assert(root.get_texture().get_image().save_png(path) == OK)
		print("RELOAD DIAGNOSTIC ",path)
	quit()
