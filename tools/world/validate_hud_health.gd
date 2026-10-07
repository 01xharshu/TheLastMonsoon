extends SceneTree
func _initialize() -> void: call_deferred("run")
func disable_input(node: Node) -> void:
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	node.set_process_unhandled_key_input(false)
	for child in node.get_children(): disable_input(child)
func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	var saves: Node = root.get_node("SaveManager")
	var original: Dictionary = saves.options.duplicate(true)
	saves.options.graphics_quality = 0
	var world: Node = load(saves.WORLD).instantiate()
	root.add_child(world)
	current_scene = world
	disable_input(world)
	saves.apply_options(world)
	print("HUD WORLD LOADED")
	for i in 10: await process_frame
	print("HUD FRAMES READY")
	var player: Node = world.get_node("Player")
	player.set_physics_process(false)
	var hud: Control = player.get_node("UI/HUDRoot")
	player.get_node("UI/IdentityScroll").set_open(false)
	player.get_node("UI/IdentityScroll").hide()
	hud.show()
	assert(hud.is_visible_in_tree())
	var original_money: int = player.inventory.get_item_count("rupees")
	player.inventory.add_item("rupees",37)
	for i in 2: await process_frame
	assert(hud.money_label.text == str(original_money+37))
	player.inventory.remove_item("rupees",12)
	for i in 2: await process_frame
	assert(hud.money_label.text == str(original_money+25))
	var survival: Node = player.get_node("SurvivalComponent")
	survival.hydration = 35.0
	survival.satiety = 75.0
	survival.set_process(false)
	survival.set_physics_process(false)
	for value in [100.0,15.0]:
		player.health = value
		hud.health_trail = value
		survival.hydration_changed.emit(35.0,100.0)
		survival.satiety_changed.emit(75.0,100.0)
		for i in 5: await process_frame
		assert(is_equal_approx(hud.health,value))
		assert(hud.get_node("SurvivalHUD/HydrationRing").current_value > 34.0 and hud.get_node("SurvivalHUD/HydrationRing").current_value < 36.0)
		assert(player.get_node("UI/WorldMap").minimap.position.x >= hud.size.x-201)
		if DisplayServer.get_name() != "headless":
			print("HUD CAPTURE WAIT")
			RenderingServer.force_draw()
			await process_frame
			print("HUD CAPTURE READY")
			root.get_texture().get_image().save_png("res://docs/world/captures/hud_health_%d.png" % int(value))
	player.health = 5
	hud.health_trail = 100
	for i in 2: await process_frame
	assert(hud.health_trail>hud.health and hud.health_trail<100)
	player.health = 100
	for i in 2: await process_frame
	assert(hud.health_trail == 100)
	print("HUD HEALTH PASS: real health, survival signals, minimap clearance, damage trail/healing")
	saves.options = original
	quit()
