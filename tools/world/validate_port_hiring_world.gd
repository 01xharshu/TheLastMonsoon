extends SceneTree

const WORLD := "res://world/suryagarh/suryagarh_world.tscn"
const WORKER := "Street_port_approach_00"
const IDENTITY := "port_approach:0"

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var saver := root.get_node("SaveManager")
	var save_folder := OS.get_environment("TLM_PORT_TEST_SAVE")
	if save_folder.is_empty():
		fail("temporary save root required")
		return
	saver.save_root = save_folder
	saver.pending_slot = -1
	change_scene_to_file(WORLD)
	await scene_changed
	var world := current_scene
	var city := world.get_node("CityRoutePopulation")
	var clock := world.get_node("GameTimeSystem")
	clock.clock_paused = true
	clock.total_game_minutes = 600.0
	clock.current_hour = 10
	var player := world.get_node("Player") as CharacterBody3D
	player.set_physics_process(false)
	player.global_position = Vector3(-194, 7, 635)
	var actor := await wait_for_worker(city)
	if actor == null:
		fail("port walker did not materialize")
		return
	var journey := actor.get_node("CityStreetJourney")
	var last: Vector2 = journey.route[-1]
	var previous: Vector2 = journey.route[-2]
	var start := last.move_toward(previous, 2.0)
	var support: Dictionary = journey.ground_at(start)
	if support.is_empty():
		fail("final approach has no ground")
		return
	actor.global_position = support.position
	actor.rotation.y = atan2(last.x-start.x,last.y-start.y)
	journey.goal = journey.route.size()-1
	journey.direction = 1
	journey.wait = 0.0
	for frame in 720:
		if city.port_hiring.worker == IDENTITY:
			break
		await physics_frame
	if city.port_hiring.worker != IDENTITY:
		fail("walker did not reach hiring endpoint, position %s, target %s" % [actor.global_position,last])
		return
	var deadline: float = city.port_hiring.ends_at
	if not saver.save_game(world, 1) or str(saver.read_slot(1).get("port_hiring",{}).get("worker","")) != IDENTITY:
		fail("disk save omitted hiring reservation")
		return
	if not saver.start_loaded_game(1):
		fail("Continue rejected temporary slot")
		return
	await scene_changed
	world = current_scene
	city = world.get_node("CityRoutePopulation")
	for frame in 3600:
		if city.port_hiring.worker == IDENTITY:
			break
		await physics_frame
	if city.port_hiring.worker != IDENTITY or not is_equal_approx(city.port_hiring.ends_at, deadline):
		fail("Continue changed worker or deadline")
		return
	clock = world.get_node("GameTimeSystem")
	clock.total_game_minutes = deadline
	var payroll: Dictionary = city.export_port_hiring()
	if payroll.earnings.get(IDENTITY,0) != 1 or city.export_port_hiring().earnings.get(IDENTITY,0) != 1:
		fail("restored shift did not pay exactly once")
		return
	print("PORT HIRING WORLD PASS | final 2m approach, disk Continue, once-only wage")
	await saver.quit_game(0)

func wait_for_worker(city: Node) -> Node3D:
	for frame in 5400:
		var actor := city.get_node_or_null(WORKER) as Node3D
		if actor != null:
			return actor
		await physics_frame
	return null

func fail(message: String) -> void:
	push_error("PORT HIRING WORLD FAIL | " + message)
	quit(1)
