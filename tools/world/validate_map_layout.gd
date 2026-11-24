extends SceneTree
## Verify the actual HUD reveal sequence and map data in a disposable world.
var failures: Array[String] = []

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func run() -> void:
	var saves: Node = root.get_node("SaveManager")
	saves.options.fullscreen = false
	saves.options.graphics_quality = 1
	saves.apply_options()
	var world: Node3D = load(saves.WORLD).instantiate()
	root.add_child(world)
	current_scene = world
	var player: CharacterBody3D = world.get_node("Player")
	player.set_physics_process(false)
	var hud: Control = player.get_node("UI/HUDRoot")
	var map: Control = player.get_node("UI/WorldMap")
	var deadline := Time.get_ticks_msec()+120000
	while (not is_instance_valid(map.minimap) or hud.tutorial == null) and Time.get_ticks_msec()<deadline:
		await process_frame
	if not is_instance_valid(map.minimap) or hud.tutorial == null:
		check(false,"HUD or minimap did not initialize")
		await saves.quit_game(1)
		return
	for frame in 8: await process_frame
	var tutorial: Node = hud.tutorial
	var names := ["HydrationRing","SatietyRing","StaminaRing","EnergyRing"]
	var minimap: Control = map.minimap
	var survival: Control = hud.get_node("SurvivalHUD")
	check(minimap.position.is_equal_approx(Vector2(45,hud.size.y-200)),"Map is not in the left cluster")
	check(is_equal_approx(minimap.RANGE,90.0),"Minimap span did not update")
	for step in range(2,8):
		tutorial.step = step
		tutorial._apply_reveal()
		check(minimap.visible,"Map missing at step %d" % step)
		for i in names.size():
			var ring: Control = survival.get_node(names[i])
			check(ring.visible == (step>=3+i),"Wrong reveal for %s at step %d" % [names[i],step])
	for i in names.size():
		var ring: Control = survival.get_node(names[i])
		var center: Vector2 = survival.position+ring.position+ring.size*.5
		var map_center: Vector2 = minimap.position+Vector2(90,90)
		check(center.y < map_center.y and absf(center.distance_to(map_center)-110.0)<2.0,"Gauge does not lie on upper arc: "+names[i])
		check(ring.ICONS[i] != null,"Missing icon: "+names[i])
	var city_deadline := Time.get_ticks_msec()+120000
	while get_nodes_in_group("city_through_house").size()<26 and Time.get_ticks_msec()<city_deadline:
		await process_frame
	map.refresh_sites()
	check(map.city_homes.size()==26,"City house footprint cache incomplete")
	for label in map.LANDMARK_FOOTPRINTS:
		check(map.sites.has(label),"Missing landmark: "+label)
	check(map.Layout.ROUTES.has("city_market_street") and map.Layout.ROUTES.has("village_spine"),"Surveyed roads missing")
	var out := OS.get_environment("TLM_MAP_REVIEW")
	if not out.is_empty() and DisplayServer.get_name() != "headless":
		tutorial.step = 10
		tutorial._apply_reveal()
		for frame in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("hud.png"))
		map.set_open(true)
		map.zoom = 4.0
		map.map_center = Vector2(520,120)
		map.clamp_center()
		map.queue_redraw()
		for frame in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("map.png"))
		map.map_center = Vector2(-350,-365)
		map.clamp_center()
		map.queue_redraw()
		for frame in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out.path_join("city.png"))
		map.set_open(false)
	print("MAP LAYOUT ","PASS" if failures.is_empty() else "FAIL"," | icons=",names," errors=",failures)
	await saves.quit_game(0 if failures.is_empty() else 1)
