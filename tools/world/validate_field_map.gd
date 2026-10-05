extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("validate")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func validate() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	root.disable_3d = true
	print("MAP WORLD READY")
	var player: CharacterBody3D = world.get_node("Player")
	player.set_physics_process(false)
	var map: Control = player.get_node("UI/WorldMap")
	map.set_open(true)
	for i in 8: await process_frame
	map.refresh_sites()
	var registry := preload("res://player/map_infrastructure.gd")
	var built: Dictionary = registry.collect(world)
	print("MAP BUILT SITES: ",built.size())
	for label in ["Police Thana","District Jail","Company Armoury","Military Hospital","Military Supply Depot","Grain and Fodder Warehouse","Cavalry Stables","Anglican Church","Military Cemetery","Collectorate","District Treasury","British Courthouse","Collector Bungalow","Officer Bungalow","Village Horse Stable","Port Customs Warehouse","Ruined Indian Fort","Forest Shrine"]:
		check(built.has(label),"Built facility missing on map: "+label)
	for label in built:
		var point: Vector2 = built[label]
		check(absf(point.x) <= map.Layout.HALF and absf(point.y) <= map.Layout.HALF,"Site outside world bounds: "+label)
		check(map.sites.has(label),"Live facility missing from picker: "+label)
	for node in world.find_children("*","Node3D",true,false):
		if not registry.NAMED.has(str(node.name)): continue
		if node.name in ["ForestShrine","HooghlyPort"]: continue
		var label: String = registry.NAMED[str(node.name)]
		check(built[label].distance_to(Vector2(node.global_position.x,node.global_position.z)) < .01,"Incorrect live map coordinate: "+label)
	var plots: Dictionary = map.Layout.PLOTS
	var ids: Array = plots.keys()
	for i in ids.size():
		for j in range(i+1,ids.size()):
			var a: Dictionary = plots[ids[i]]
			var b: Dictionary = plots[ids[j]]
			var overlap: Vector2 = a.half+b.half-(a.center-b.center).abs()
			check(overlap.x <= 4.0 or overlap.y <= 4.0,"District plots overlap: %s / %s" % [ids[i],ids[j]])
	check(map.terrain.get_size().x >= 1024,"High-resolution map raster missing")
	var target := Vector2(320,120)
	check(map.unproject(map.project(target)).distance_to(target)<0.01,"World/screen map projection mismatch")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = map.map_rect.get_center()
	map._gui_input(wheel)
	map._gui_input(wheel)
	map._gui_input(wheel)
	check(map.zoom > 1.9,"Map did not zoom with pointer wheel")
	map.map_center = target
	map.clamp_center()
	for i in 3: await process_frame
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("res://docs/world/captures/10_map_zoom.png")
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = map.map_rect.get_center()
	map._gui_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = down.position
	map._gui_input(up)
	check(map.waypoint.distance_to(target)<1.0,"Map click did not place marker at selected location")
	var motion := InputEventMouseMotion.new()
	motion.position = down.position+Vector2(50,20)
	motion.relative = Vector2(50,20)
	map._gui_input(down)
	map._gui_input(motion)
	map._gui_input(up)
	check(map.map_center.distance_to(target)>1.0,"Map drag did not pan")
	if built.has("Military Hospital"):
		map.map_center = built["Military Hospital"]
		map.clamp_center()
		map.select_point(map.project(built["Military Hospital"]))
		check(map.waypoint.distance_to(built["Military Hospital"]) < .01,"Map icon did not mark facility")
		for i in 3: await process_frame
		if DisplayServer.get_name() != "headless":
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("res://docs/world/captures/infrastructure_map_selected.png")
	var evidence := {"status":"PASS" if failures.is_empty() else "FAIL","built_count":built.size(),"district_plots":plots.size(),"sites":built,"failures":failures}
	var output := FileAccess.open("res://docs/world/infrastructure_map_validation.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(evidence,"\t"))
	map.set_open(false)
	check(not player.get_meta("map_open"),"Map did not release gameplay input")
	print("FIELD MAP VALIDATION ",JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","zoom":map.zoom,"waypoint":map.waypoint,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
