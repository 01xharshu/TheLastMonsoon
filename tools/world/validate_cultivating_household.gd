extends Node3D

const World = preload("res://world/suryagarh/suryagarh_world.tscn")

func _ready() -> void:
	var world := World.instantiate()
	world.name = "Suryagarh"
	add_child(world)
	_check_when_ready.call_deferred(world)

func _check_when_ready(world: Node3D) -> void:
	for _frame in 2400:
		var settlement := world.get_node_or_null("Settlement")
		var home := settlement.get_node_or_null("BhairavpurHouse1") if settlement else null
		var carpenter := settlement.get_node_or_null("BhairavpurHouse25") if settlement else null
		var potter := settlement.get_node_or_null("BhairavpurHouse30") if settlement else null
		var weaver := settlement.get_node_or_null("BhairavpurHouse27") if settlement else null
		if home and carpenter and potter and weaver and settlement.has_meta("bhairavpur_home_count"):
			await _validate(settlement, home, carpenter, potter, weaver, world)
			return
		await get_tree().process_frame
	push_error("Timed out waiting for Bhairavpur House1 to finish building")
	get_tree().quit(1)

func _validate(settlement: Node3D, home: Node3D, carpenter: Node3D, potter: Node3D, weaver: Node3D, world: Node3D) -> void:
	var kit := home.get_node_or_null("CultivatingKit")
	var plot := settlement.get_node_or_null("BhairavpurHouse1WorkedPlot")
	var lamp := home.get_node_or_null("HouseOilLamp")
	var pots := kit.find_children("CoveredWaterVessel*", "Node3D", true, false) if kit else []
	var sacks := kit.find_children("GrainSack*", "Node3D", true, false) if kit else []
	var roof := home.get_node_or_null("CultivatingEarthRoof")
	var carpentry_kit := carpenter.get_node_or_null("CarpenterMaterialKit")
	var work_surfaces := carpenter.find_children("CarpenterWorkSurface", "Node3D", true, false)
	var planks := carpentry_kit.find_children("StoredPlank*", "Node3D", true, false) if carpentry_kit else []
	var stools := carpentry_kit.find_children("FinishedStoolSeat*", "Node3D", true, false) if carpentry_kit else []
	var offcuts := carpentry_kit.find_children("ShortOffcut*", "Node3D", true, false) if carpentry_kit else []
	var pottery_kit := potter.get_node_or_null("PotteryKit")
	var drying_pots: Array[Node3D] = []
	var finished_pots: Array[Node3D] = []
	for vessel: Node3D in potter.find_children("*", "Node3D", true, false):
		if vessel.get_meta("pottery_role", "") == "drying":
			drying_pots.append(vessel)
		if pottery_kit and vessel.get_parent() == pottery_kit and vessel.get_meta("pottery_role", "") == "FinishedPot":
			finished_pots.append(vessel)
	var firing_yard := settlement.get_node_or_null("House30FiringYard")
	var pottery_lamp := potter.get_node_or_null("HouseOilLamp")
	var weaving_kit := weaver.get_node_or_null("WeavingKit")
	var loom_surfaces := weaver.find_children("WeaverWorkSurface", "Node3D", true, false)
	var weaving_lamp := weaver.get_node_or_null("HouseOilLamp")
	var errors: Array[String] = []
	if settlement.get_meta("bhairavpur_home_count") != 33: errors.append("home count changed")
	if not kit: errors.append("House1 kit missing")
	if not plot: errors.append("linked worked plot missing")
	if home.get_meta("livelihood", "") != "cultivating": errors.append("livelihood metadata missing")
	if home.get_meta("roof_style", "") != "earth terrace": errors.append("candidate flat roof missing")
	if pots.size() != 2: errors.append("covered water vessels missing")
	if sacks.size() != 2: errors.append("stored grain sacks missing")
	if roof == null or home.get_node_or_null("VerandaShade") != null:
		errors.append("pilot roof replacement incomplete")
	if lamp == null or lamp.position.distance_to(Vector3(3.8, 1.40, 3.24)) > 0.001:
		errors.append("House1 lamp offset incorrect")
	if not carpentry_kit or carpenter.get_meta("livelihood", "") != "carpentry":
		errors.append("House25 material kit missing")
	if work_surfaces.size() != 1: errors.append("existing carpenter work surface duplicated or removed")
	if planks.size() != 9 or stools.size() != 2 or offcuts.size() != 7:
		errors.append("House25 stock/offcut/output dressing incomplete (%d/%d/%d)" % [planks.size(), stools.size(), offcuts.size()])
	if not pottery_kit or potter.get_meta("livelihood", "") != "pottery":
		errors.append("House30 pottery kit missing")
	if drying_pots.size() != 3 or finished_pots.size() != 3:
		errors.append("House30 drying or finished pottery storage incomplete (%d/%d)" % [drying_pots.size(), finished_pots.size()])
	if not potter.get_node_or_null("PotteryKit/SingleClayWheel") or potter.get_node_or_null("PotterFlywheel"):
		errors.append("House30 wheel replacement duplicated or missing")
	if not firing_yard or firing_yard.get_meta("state", "") != "cold; no active fire or weather-independent firing simulation":
		errors.append("House30 cold firing yard missing or incorrectly active")
	if pottery_lamp == null or pottery_lamp.position.distance_to(Vector3(3.8, 1.40, 3.14)) > 0.001:
		errors.append("House30 lamp offset incorrect")
	if not weaving_kit or not str(weaver.get_meta("loom_status", "")).begins_with("inherited placeholder"):
		errors.append("House27 kit missing or loom status changed")
	if loom_surfaces.size() != 1:
		errors.append("existing House27 loom was duplicated or removed")
	if weaving_lamp == null or weaving_lamp.position.distance_to(Vector3(3.8, 1.40, 3.14)) > 0.001:
		errors.append("House27 lamp offset incorrect")
	for vessel: Node3D in drying_pots + finished_pots:
		var collision_shapes := vessel.find_children("*", "CollisionShape3D", true, false)
		var meshes := vessel.find_children("*", "MeshInstance3D", true, false)
		if (
			not vessel.has_meta("earthen_vessel")
			or collision_shapes.is_empty()
			or meshes.is_empty()
		):
			errors.append("House30 vessel %s lost protected visuals or collision" % vessel.name)
	for pot: Node3D in pots:
		if (
			not pot.has_meta("earthen_vessel")
			or not pot.get_node_or_null("VesselCollision")
			or pot.find_children("*", "MeshInstance3D", true, false).is_empty()
		):
			errors.append("covered vessel lost its protected collision component")
	if errors.is_empty():
		var routes_ok: bool = await _check_player_routes(world, weaver)
		if not routes_ok:
			return
		print("HOUSEHOLD PILOTS PASS | 33 homes | House1 cultivation | House25 carpentry | House27 weaving | House30 pottery")
		get_tree().quit(0)
	else:
		for error in errors: push_error(error)
		get_tree().quit(1)

func _check_player_routes(world: Node3D, home: Node3D) -> bool:
	var player: CharacterBody3D = world.get_node("Player")
	player.set_process_unhandled_input(false)
	for action in ["move_forward", "move_backward", "move_left", "move_right", "sprint", "jump"]:
		Input.action_release(action)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	world.get_node("GameTimeSystem").clock_paused = true
	for route in [
		["entry", [Vector3(0, 0, 8), Vector3(0, 0, 0)]],
		["exit", [Vector3(0, 0, 0), Vector3(0, 0, 8)]],
		["yarn preparation", [Vector3(0, 0, 7), Vector3(-3, 0, 7), Vector3(-3, 0, 6.1)]],
		["loom approach", [Vector3(-1.7, 0, 5.7), Vector3(0, 0, 5.7), Vector3(2.25, 0, 5.7)]],
		["cloth storage", [Vector3(0, 0, 0), Vector3(2, 0, 0), Vector3(2, 0, 1.3)]]
	]:
		var points: Array[Vector3] = []
		for local: Vector3 in route[1]: points.append(home.to_global(local))
		var ok := await _walk_player_path(world, player, home, points)
		if not ok:
			push_error("House27 actual Player route blocked: %s" % route[0])
			get_tree().quit(1)
			return false
		print("HOUSE27 PLAYER ROUTE PASS | %s" % route[0])
	return true

func _walk_player_path(world: Node3D, player: CharacterBody3D, home: Node3D, points: Array[Vector3]) -> bool:
	var first := Vector2(points[0].x, points[0].z)
	player.global_position = Vector3(first.x, _route_ground(world, player, home, first) + .95, first.y)
	player.velocity = Vector3.ZERO
	for _frame in 15: await get_tree().physics_frame
	for segment in range(points.size() - 1):
		var target := Vector2(points[segment + 1].x, points[segment + 1].z)
		var reached := false
		var frame_budget := ceili(Vector2(points[segment].x, points[segment].z).distance_to(target) / player.walk_speed * 60.0) + 180
		for _frame in frame_budget:
			var position := Vector2(player.global_position.x, player.global_position.z)
			var delta := target - position
			var speed := Vector2(player.velocity.x, player.velocity.z).length()
			if delta.length() < .20 and speed < .15:
				reached = true
				break
			if delta.length() <= speed * speed / (2.0 * player.deceleration) + .10:
				Input.action_release("move_forward")
			else:
				player.get_node("CameraPivot").global_rotation.y = atan2(-delta.x, -delta.y)
				Input.action_press("move_forward")
			await get_tree().physics_frame
		Input.action_release("move_forward")
		if not reached:
			print("PLAYER_PATH_BLOCKED | segment=%d start=%s target=%s current=%s velocity=%s" % [segment, str(points[segment]), str(points[segment + 1]), str(player.global_position), str(player.velocity)])
			for index in player.get_slide_collision_count():
				print("PLAYER_PATH_CONTACT | %s" % player.get_slide_collision(index).get_collider().get_path())
			return false
	return true

func _route_ground(world: Node3D, player: CharacterBody3D, home: Node3D, p: Vector2) -> float:
	var query := PhysicsRayQueryParameters3D.create(Vector3(p.x, 40, p.y), Vector3(p.x, -20, p.y))
	query.exclude = [player.get_rid()]
	var floor_y := home.global_position.y
	for _attempt in 24:
		var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty(): break
		if hit.collider.name == "GroundCollision":
			floor_y = hit.position.y
			break
		var exclusions: Array[RID] = query.exclude
		exclusions.append(hit.collider.get_rid())
		query.exclude = exclusions
	var local := home.to_local(Vector3(p.x, home.global_position.y, p.y))
	var plinth := home.get_node_or_null("Plinth") as Node3D
	if plinth:
		var collision: CollisionShape3D = plinth.find_children("*", "CollisionShape3D", true, false)[0]
		var half: Vector3 = collision.shape.size * .5
		if absf(local.x) <= half.x and absf(local.z) <= half.z:
			floor_y = maxf(floor_y, home.global_position.y + plinth.position.y + half.y)
	return floor_y
