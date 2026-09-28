extends SceneTree
## Internal motion diagnostic only: current Arjun appearance is owner-rejected.
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	root.size = Vector2i(1280, 720)
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var environment := WorldEnvironment.new()
	var sky := Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = Color(0.30,0.32,0.30)
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Color(0.85,0.84,0.80)
	environment.environment = sky
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40,-30,0)
	world.add_child(light)
	var time := Node.new()
	time.name = "GameTimeSystem"
	time.set_script(load("res://world/suryagarh/systems/game_time_system.gd"))
	world.add_child(time)
	var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
	world.add_child(actor)
	actor.set_physics_process(false)
	actor.get_node("UI").hide()
	var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 47.0
	camera.global_position = actor.global_position + Vector3(1.8,1.45,2.3)
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
		if weapon == 1:
			combat.reload_remaining = 3.4
			for i in 8: visual._process(1.0/60.0)
			var palm: Vector3 = visual.equipment.enfield_cartridge.global_position
			camera.global_position = palm + Vector3(0.45,0.35,0.70)
			camera.look_at(palm)
			for i in 3: await process_frame
			await RenderingServer.frame_post_draw
			var cartridge_path := "/tmp/tlm_enfield_cartridge_diagnostic.png"
			assert(root.get_texture().get_image().save_png(cartridge_path) == OK)
			print("RELOAD DIAGNOSTIC ",cartridge_path)
	quit()
