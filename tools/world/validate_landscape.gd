extends SceneTree
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
var failures: Array[String] = []
var layout = Layout.new()

func _initialize() -> void:
	call_deferred("run_checks")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func run_checks() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.get_node("GameTimeSystem").clock_paused = true
	var player: CharacterBody3D = world.get_node("Player")
	for i in 90: await physics_frame
	check(player.is_on_floor(), "Spawn did not settle on terrain")
	check(absf(player.position.y - 0.9 - layout.height(player.position.x,player.position.z)) < 0.15, "Spawn/terrain contact mismatch")
	check(world.get_node("Landscape/TerrainTiles").get_child_count() == 144, "Incorrect terrain tile count")
	var sample_count: int = 0
	var max_error: float = 0.0
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	for tz in 12:
		for tx in 12:
			for offset in [Vector2(72,72), Vector2(0,72), Vector2(72,0)]:
				var p: Vector2 = Vector2(-Layout.HALF + tx * Layout.TILE, -Layout.HALF + tz * Layout.TILE) + offset
				var query := PhysicsRayQueryParameters3D.create(Vector3(p.x,350,p.y),Vector3(p.x,-30,p.y))
				var hit: Dictionary = space.intersect_ray(query)
				var excluded: Array[RID] = [player.get_rid()]
				for attempt in 8:
					if hit.is_empty() or hit.collider.name == "GroundCollision": break
					excluded.append(hit.collider.get_rid())
					query.exclude = excluded
					hit = space.intersect_ray(query)
				check(not hit.is_empty(), "Ground collision missing at " + str(p))
				if not hit.is_empty():
					var error: float = absf(hit.position.y - layout.height(p.x,p.y))
					max_error = maxf(max_error,error)
					check(error < 0.06, "Terrain seam collision error at " + str(p) + ": " + str(error))
				sample_count += 1
	# Exercise the actual existing movement controller at three different dry sites.
	var walks: Array[Dictionary] = []
	for site in [0,2,3]:
		world.move_to_review_point(site)
		for i in 60: await physics_frame
		var start: Vector3 = player.position
		Input.action_press("move_forward")
		for i in 120: await physics_frame
		Input.action_release("move_forward")
		for i in 10: await physics_frame
		var distance: float = Vector2(player.position.x-start.x,player.position.z-start.z).length()
		check(distance > 5.0, "Controller failed to traverse site " + str(site))
		check(player.is_on_floor(), "Player lost terrain contact at site " + str(site))
		walks.append({"site":site,"distance_m":distance,"grounded":player.is_on_floor()})
	# Deep water remains deliberately unavailable until swimming has been implemented.
	world.move_to_review_point(1)
	for i in 30: await physics_frame
	var dry: Vector3 = player.position
	player.position = Vector3(layout.river_x(155), -2, 155)
	for i in 3: await physics_frame
	var water_return_ok: bool = player.position.distance_to(dry) < 3
	check(water_return_ok, "Deep-water dry-ground return failed")
	player.position = Vector3(900,30,0)
	for i in 3: await physics_frame
	var boundary_ok: bool = player.position.x <= Layout.HALF-4
	check(boundary_ok, "Playable boundary containment failed")
	world.move_to_review_point(0)
	for i in 60: await physics_frame
	var jump_start: float = player.position.y
	var jump_peak: float = jump_start
	Input.action_press("jump")
	for i in 100:
		await physics_frame
		jump_peak = maxf(jump_peak, player.position.y)
		if i == 1: Input.action_release("jump")
	check(jump_peak-jump_start > 0.7 and player.is_on_floor(), "Jump/landing failed on landscape")
	var key := InputEventKey.new()
	key.keycode = KEY_F3
	key.pressed = true
	world._unhandled_key_input(key)
	check(world.survey_camera.current and not player.is_physics_processing(), "Survey mode did not pause player movement")
	world._unhandled_key_input(key)
	check(world.player_camera.current and player.is_physics_processing(), "Survey mode did not restore player movement")
	var report := {"status":"PASS" if failures.is_empty() else "FAIL", "terrain_collision_samples":sample_count,
		"max_collision_error_m":max_error,"walks":walks,"jump_height_m":jump_peak-jump_start,"deep_water_return":water_return_ok,"boundary_containment":boundary_ok,"failures":failures}
	var file := FileAccess.open("res://docs/world/validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	print("LANDSCAPE VALIDATION ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
