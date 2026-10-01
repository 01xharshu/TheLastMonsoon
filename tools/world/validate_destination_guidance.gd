extends SceneTree
var world: Node3D
var actor: CharacterBody3D
var jobs: Node
var marker: Control

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	world = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world); current_scene = world
	for frame in 25: await physics_frame
	actor = world.get_node("Player"); jobs = world.get_node("ErrandSystem")
	marker = jobs.destination_marker
	actor.set_physics_process(false)
	actor.global_position = jobs.targets.board.global_position + Vector3(0,0,1.2)
	actor.global_position.y = jobs.floor_levels.board+.95
	jobs.use_endpoint("board",actor); assert(jobs.accept("road_meal"))
	var road: Vector3 = jobs.targets.road.global_position
	actor.global_position = Vector3(road.x,world.layout.height(road.x,road.z+400)+.95,road.z+400)
	actor.rotation.y = 0; actor.get_node("CameraPivot").rotation = Vector3(-.05,0,0)
	actor.get_node("VisualRoot").global_rotation.y = PI
	for frame in 8: await physics_frame
	marker.refresh()
	if not _expect(marker.visible and marker.distance_text == "400 m", "400 m destination label"): return
	await _shot("destination_400m")
	actor.get_node("CameraPivot").rotation.y = PI
	for frame in 6: await physics_frame
	marker.refresh()
	if not _expect(marker.at_edge and marker.marker_position.x >= 100 and marker.marker_position.x <= 1180,"Behind-camera edge arrow"): return
	await _shot("destination_offscreen")
	# Progress switches the marker automatically; restored state re-derives the correct stop.
	jobs.restore_state({"active":"merchant_parcel","stages":{"merchant_parcel":"accepted"}})
	marker.refresh(); assert(marker.destination.endpoint == "parcel")
	actor.global_position = jobs.targets.parcel.global_position + Vector3(0,0,1.1)
	actor.global_position.y = jobs.floor_levels.parcel+.95
	jobs.use_endpoint("parcel",actor); marker.refresh()
	assert(marker.destination.endpoint == "market")
	var saved: Dictionary = jobs.export_state(); jobs.restore_state({}); jobs.restore_state(saved)
	marker.refresh(); assert(marker.destination.endpoint == "market" and marker.objective_text.contains("Deliver"))
	jobs.open_panel(); marker.refresh(); assert(not marker.visible); jobs.close_panel()
	jobs.cancel(); actor.get_node("UI/WorldMap").waypoint = Vector2(INF,INF)
	marker.refresh(); assert(not marker.visible)
	actor.get_node("UI/WorldMap").waypoint = Vector2(road.x,road.z)
	marker.refresh(); assert(marker.visible and marker.caption == "Map destination")
	actor.get_node("UI/WorldMap").waypoint = Vector2(INF,INF)
	jobs.restore_state({"active":"market_sort","stages":{"market_sort":"worked"}})
	assert(jobs.next_endpoint() == "market")
	jobs.restore_state({"active":"road_meal","stages":{"road_meal":"accepted"}})
	# Actual controller movement at time_scale 1; no position writes during the route.
	Engine.time_scale = 1.0
	actor.global_position = Vector3(road.x+2,jobs.floor_levels.road+.95,road.z+12)
	actor.velocity = Vector3.ZERO; actor.rotation.y = 0
	actor.set_physics_process(true); Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for frame in 20: await physics_frame
	var start := actor.global_position
	var route: Array[Vector2] = [Vector2(road.x+3,road.z+8),Vector2(road.x+3,road.z+.6),Vector2(road.x+1.0,road.z+.6)]
	for stop in route:
		var reached := false
		for frame in 420:
			var offset := stop-Vector2(actor.global_position.x,actor.global_position.z)
			if offset.length() < .4: reached = true; break
			actor.get_node("CameraPivot").global_rotation.y = atan2(-offset.x,-offset.y)
			Input.action_press("move_forward")
			await physics_frame
		Input.action_release("move_forward")
		if not reached:
			for index in actor.get_slide_collision_count(): print("GUIDANCE ROUTE BLOCKER ",actor.get_slide_collision(index).get_collider().get_path())
		if not _expect(reached,"Normal-speed controller route to " + str(stop) + " stopped at " + str(actor.global_position)): return
	for frame in 12: await physics_frame
	marker.refresh()
	if not _expect(marker.arrived and marker.distance_m <= 2.6,"Walked into destination interaction range"): return
	if actor._find_interactable() != jobs.targets.road:
		print("GUIDANCE ARRIVAL ",actor.global_position," visual ",actor.get_node("VisualRoot").global_rotation," selected ",actor._find_interactable())
	if not _expect(actor._find_interactable() == jobs.targets.road,"Road traveller selected on arrival"): return
	await _shot("destination_arrived")
	actor.get_node("InventoryComponent").add_item("roti",1)
	var before: int = actor.get_node("InventoryComponent").get_item_count("rupees")
	var event := InputEventAction.new(); event.action = "interact"; event.pressed = true
	Input.parse_input_event(event)
	await physics_frame
	marker.refresh()
	if not _expect(jobs.active.is_empty() and not marker.visible,"Normal interaction completes job and clears marker"): return
	assert(actor.get_node("InventoryComponent").get_item_count("rupees") == before+2)
	print("DESTINATION GUIDANCE: PASS | 400m, offscreen arrow, step switch/restore, modal/cancel hide, map pin, actual normal-speed walk ",start," -> ",actor.global_position," and arrival interaction/payment")
	quit()

func _expect(value: bool, reason: String) -> bool:
	if not value: push_error("DESTINATION GUIDANCE FAIL: " + reason); quit(1)
	return value

func _shot(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for frame in 4: await process_frame
	RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png("res://docs/world/captures/"+label+".png") == OK)
