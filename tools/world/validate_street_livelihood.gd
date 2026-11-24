extends SceneTree

const Livelihood = preload("res://world/suryagarh/street_livelihood.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var loader := load("res://world/suryagarh/city_route_population.gd") as GDScript
	var journey := load("res://world/suryagarh/city_street_journey.gd") as GDScript
	var ok := loader != null and loader.can_instantiate() and journey != null and journey.can_instantiate()
	ok = ok and Livelihood.role_for("administrative_approach", 0) == &"clerk"
	ok = ok and Livelihood.role_for("government_house_road", 0) == &"domestic_worker"
	ok = ok and Livelihood.role_for("port_approach", 0) == &"porter"
	ok = ok and Livelihood.role_for("port_approach", 2) == &"job_seeker"
	ok = ok and Livelihood.role_for("city_market_street", 1) == &"shopper"
	ok = ok and Livelihood.dwell(&"clerk", true) > Livelihood.dwell(&"shopper", true)
	ok = ok and Livelihood.activity(&"porter", -1, 10.0, false) == &"waiting_for_hire"
	ok = ok and Livelihood.activity(&"porter", -1, 0.0, true) == &"returning_after_hours"
	var social := load("res://world/suryagarh/population_social.gd") as GDScript
	ok = ok and social != null and social.can_instantiate()
	if ok:
		var walker: Node = journey.new()
		walker.livelihood_role = &"clerk"
		walker.direction = 1
		ok = not walker.can_pause_for_peer()
		walker.direction = -1
		ok = ok and walker.can_pause_for_peer()
		walker.free()
	var hiring = preload("res://world/suryagarh/port_hiring.gd").new()
	ok = hiring.offer("port_approach:0", 420.0) and ok
	ok = not hiring.offer("port_approach:2", 421.0) and ok
	var restored = preload("res://world/suryagarh/port_hiring.gd").new()
	restored.restore_state(hiring.export_state())
	restored.settle(439.0)
	ok = restored.earnings.is_empty() and ok
	restored.settle(440.0)
	restored.settle(441.0)
	ok = restored.earnings.get("port_approach:0") == 1 and ok
	ok = not restored.offer("port_approach:0", 441.0) and ok
	ok = restored.offer("port_approach:2", 441.0) and ok
	ok = not hiring.offer("port_approach:3", 1010.0) and ok
	ok = not hiring.offer("port_approach:3", 360.0) and ok
	ok = restored.offer("port_approach:0", 1860.0) and ok
	if ok:
		ok = check_port_arrival(loader, journey)
	print("STREET LIVELIHOOD ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)


func check_port_arrival(loader: GDScript, journey: GDScript) -> bool:
	var city: Node = loader.new()
	var clock := preload("res://world/suryagarh/systems/game_time_system.gd").new()
	clock.total_game_minutes = 420.0
	city.population_clock = clock
	var actor := Node3D.new()
	actor.name = "Street_port_approach_00"
	city.add_child(actor)
	var walker: Node = journey.new()
	walker.actor = actor
	walker.route = city.route_points("port_approach", 0, 3.3)
	walker.goal = walker.route.size() - 1
	walker.livelihood_role = &"porter"
	walker.port_hiring_owner = city
	walker.port_worker_key = "port_approach:0"
	walker.arrive()
	var ok: bool = city.port_shift_active("port_approach:0") == true
	ok = not walker.can_pause_for_peer() and ok
	actor.set_meta("knocked_out", true)
	clock.total_game_minutes = 440.0
	var state: Dictionary = city.export_port_hiring()
	ok = state.worker.is_empty() and state.earnings.is_empty() and ok
	var record := {"kind":"person", "route":"port_approach", "index":2,
		"points":walker.route, "phase":{"point":walker.route[-1],"goal":walker.route.size()-1}, "wait":0.0, "direction":1}
	city.advance_record(record, 0.5)
	ok = city.port_shift_active("port_approach:2") and ok
	var saved: Dictionary = city.export_port_hiring()
	city.port_hiring.cancel()
	city.port_hiring.restore_state(JSON.parse_string(JSON.stringify(saved)))
	var held: float = record.wait
	city.advance_record(record, 0.5)
	ok = record.wait == held and ok
	clock.total_game_minutes = 460.0
	city.advance_record(record, 0.5)
	ok = record.wait < held and city.port_hiring.earnings.get("port_approach:2") == 1 and ok
	walker.free()
	city.free()
	clock.free()
	return ok
