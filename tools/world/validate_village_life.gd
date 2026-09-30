extends "res://tools/world/validate_village_area.gd"
var checking_routes := false
func _ground(p: Vector2) -> float:
	var terrain := super._ground(p)
	if not checking_routes: return terrain
	var query := PhysicsRayQueryParameters3D.create(Vector3(p.x,8.5,p.y),Vector3(p.x,-20,p.y))
	query.exclude = [player.get_rid()]
	var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
	return maxf(terrain,hit.position.y) if not hit.is_empty() else terrain

func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	world = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	player = world.get_node("Player")
	player.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 12: await physics_frame
	var clock: GameTimeSystem = world.get_node("GameTimeSystem")
	clock.clock_paused = true
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_check(world.get_node_or_null("Settlement/BhairavpurPond") == null,"rejected pond and access structures absent")
	var lamps := get_nodes_in_group("village_oil_lamp")
	_check(lamps.size() == 34,"33 household lamps plus estate rent-office lamp")
	for hour in [12,21,5,6]:
		clock.total_game_minutes = hour*60.0
		clock._update_readable_time(true)
		await process_frame
		for lamp in lamps:
			_check(lamp.is_lit == (hour >=18 or hour<6),"lamp state hour %d home %s"%[hour,lamp.get_parent().name])
	clock.total_game_minutes = 21*60.0
	clock._update_readable_time(true)
	await process_frame
	lamps[0].interact(player)
	_check(not lamps[0].is_lit,"manual extinguish")
	clock.advance_minutes(1)
	_check(not lamps[0].is_lit,"manual state persists during night")
	lamps[0].interact(player)
	_check(lamps[0].is_lit,"manual relight")
	_check(get_nodes_in_group("village_gathering_fire").size()==2,"two night gathering bays")
	for fire in get_nodes_in_group("village_gathering_fire"):
		_check(fire.get_node("FireLight").visible,"fire light at night")
	# Verify the restored former basin and estate ground against baked terrain.
	for p in [Vector2(-411,187),Vector2(-429,187),Vector2(-393,187),Vector2(-411,202),Vector2(-411,172),Vector2(-321,344)]:
		_sample_ground(p,layout.height(p.x,p.y),"social place")
	_check(worst_ground_gap < .035,"restored ground/estate survey samples")
	checking_routes = true
	for route in ["village_estate_approach"]:
		await _walk_route(route,Layout.ROUTES[route])
	await _walk_route("estate gate and courtyard",[Vector2(-321,327),Vector2(-321,350)])
	var path := "res://docs/world/village_life_headless.json" if DisplayServer.get_name()=="headless" else "res://docs/world/village_life_metal.json"
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","lamps":lamps.size(),"terrain_samples":ground_samples,"worst_gap_m":worst_ground_gap,"routes":routes,"failures":failures},"\t"))
	print("VILLAGE LIFE ","PASS" if failures.is_empty() else "FAIL")
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
