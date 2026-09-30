extends SceneTree
## Physical terrain survey and actual Player routes in expanded Bhairavpur.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const Village = preload("res://world/suryagarh/settlements/bhairavpur_village.gd")
var world: Node3D
var player: CharacterBody3D
var layout := Layout.new()
var failures: Array[String] = []
var routes: Array[Dictionary] = []
var ground_samples := 0
var worst_ground_gap := 0.0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures.append(message)

func _ground(p: Vector2) -> float:
	var query := PhysicsRayQueryParameters3D.create(Vector3(p.x,40,p.y),Vector3(p.x,-20,p.y))
	query.exclude = [player.get_rid()]
	for attempt in 24:
		var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty(): return INF
		if hit.collider.name == "GroundCollision": return hit.position.y
		var exclusions: Array[RID] = query.exclude
		exclusions.append(hit.collider.get_rid())
		query.exclude = exclusions
	return INF

func _sample_ground(p: Vector2, expected: float, label: String) -> void:
	var gap := absf(_ground(p)-expected)
	ground_samples += 1
	worst_ground_gap = maxf(worst_ground_gap,gap)
	if gap > .035: failures.append(label+" ground gap "+str(gap)+" at "+str(p))

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
	for action in ["move_forward","move_backward","move_left","move_right","sprint","jump"]:
		Input.action_release(action)
	for i in 12: await physics_frame
	world.get_node("GameTimeSystem").clock_paused = true
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var homes := get_nodes_in_group("bhairavpur_home")
	var stalls := get_nodes_in_group("bhairavpur_market_stall")
	var gardens := get_nodes_in_group("bhairavpur_garden")
	_check(homes.size() == Village.HOME_COUNT,"33 village homes exist")
	_check(stalls.size() == Village.STALL_COUNT,"eight market stalls exist")
	_check(gardens.size() == Village.GARDEN_COUNT,"twelve cultivated beds exist")
	_check(get_nodes_in_group("bhairavpur_shade_tree").size() == 6,"six shade trees exist")
	for node: Node3D in get_nodes_in_group("bhairavpur_structure"):
		_sample_ground(Vector2(node.global_position.x,node.global_position.z),node.global_position.y,str(node.name))
	for home: Node3D in homes:
		var plinth: Node3D = home.get_node("Plinth")
		var collision: CollisionShape3D = plinth.find_children("*","CollisionShape3D",true,false)[0]
		var half: Vector3 = collision.shape.size*.5
		for x in [-half.x,0.0,half.x]:
			for z in [-half.z,0.0,half.z]:
				var p := home.to_global(Vector3(x,0,z))
				_sample_ground(Vector2(p.x,p.z),home.global_position.y,str(home.name))
	for name in Layout.ROUTES:
		if not name.begins_with("village_"): continue
		var points: Array = Layout.ROUTES[name]
		for i in range(points.size()-1):
			var a: Vector2 = points[i]
			var b: Vector2 = points[i+1]
			var steps := maxi(1,ceili(a.distance_to(b)/3.0))
			for step in range(steps+1):
				var p := a.lerp(b,float(step)/steps)
				_sample_ground(p,layout.height(p.x,p.y),str(name))
	_check(worst_ground_gap <= .035,"baked ground matches sampled foundations and lanes")
	if failures.is_empty():
		if "--metal-samples" in OS.get_cmdline_user_args():
			await _walk_route("west lane Metal sample",[Vector2(-374,230),Vector2(-374,280)])
			await _walk_route("market Metal sample",[Vector2(-352,275),Vector2(-278,275)])
			await _walk_route("farm Metal sample",[Vector2(-413,245),Vector2(-413,280)])
		else:
			for name in Layout.ROUTES:
				if name.begins_with("village_"): await _walk_route(str(name),Layout.ROUTES[name])
			await _walk_route("farm beds aisle",[Vector2(-413,227),Vector2(-413,313)])
		await _well_check()
	var report := {"status":"PASS" if failures.is_empty() else "FAIL","route_scope":"three Metal samples" if "--metal-samples" in OS.get_cmdline_user_args() else "six complete lane chains and farm aisle","renderer":RenderingServer.get_current_rendering_method(),"display_server":DisplayServer.get_name(),"homes":homes.size(),"market_stalls":stalls.size(),"cultivated_beds":gardens.size(),"ground_samples":ground_samples,"worst_ground_gap_m":worst_ground_gap,"routes":routes,"failures":failures}
	var path := "res://docs/world/village_validation_metal.json" if DisplayServer.get_name() != "headless" else "res://docs/world/village_validation_headless.json"
	var output := FileAccess.open(path,FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t")+"\n")
	print("VILLAGE AREA ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _walk_route(label: String, points: Array) -> void:
	var start: Vector2 = points[0]
	player.global_position = Vector3(start.x,_ground(start)+.95,start.y)
	player.velocity = Vector3.ZERO
	for i in 15: await physics_frame
	var beginning := player.global_position
	var finished_segments := 0
	var worst_fall := 0.0
	var max_deviation := 0.0
	for i in range(points.size()-1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i+1]
		var direction := (b-a).normalized()
		player.get_node("CameraPivot").global_rotation.y = atan2(-direction.x,-direction.y)
		Input.action_press("move_forward")
		var reached := false
		var frame_budget := ceili(a.distance_to(b)/player.walk_speed*60.0)+100
		for frame in frame_budget:
			await physics_frame
			worst_fall = minf(worst_fall,player.velocity.y)
			var position := Vector2(player.global_position.x,player.global_position.z)
			max_deviation = maxf(max_deviation,layout.segment_distance(position,a,b))
			if (position-a).dot(direction) >= a.distance_to(b)-.15:
				reached = true
				break
		Input.action_release("move_forward")
		if not reached:
			for contact in player.get_slide_collision_count():
				print("BLOCKED CONTACT ",player.get_slide_collision(contact).get_collider().get_path())
			failures.append(label+" blocked segment "+str(i)+" at "+str(player.global_position))
			break
		finished_segments += 1
	var ok := finished_segments == points.size()-1 and max_deviation < 1.5 and worst_fall > -3.0
	_check(ok,label+" actual Player traversal")
	routes.append({"route":label,"pass":ok,"start":str(beginning),"finish":str(player.global_position),"segments_reached":finished_segments,"segments_expected":points.size()-1,"max_lane_deviation_m":max_deviation,"worst_vertical_speed_mps":worst_fall,"jump_used":false})

func _well_check() -> void:
	var well: Node3D = world.get_node("Settlement/BhairavpurVillageWell")
	var body: StaticBody3D = well.get_node("WellBody")
	var p := Vector2(well.global_position.x,well.global_position.z+3.0)
	player.global_position = Vector3(p.x,_ground(p)+.95,p.y)
	player.velocity = Vector3.ZERO
	player.get_node("CameraPivot").global_rotation.y = 0.0
	for i in 12: await physics_frame
	var touched := false
	Input.action_press("move_forward")
	for i in 90:
		await physics_frame
		for index in player.get_slide_collision_count():
			touched = touched or player.get_slide_collision(index).get_collider() == body
	Input.action_release("move_forward")
	_check(touched and player.global_position.z > well.global_position.z+1.15,"Player cannot walk through the well shaft")
	var inventory: Node = player.get_node("InventoryComponent")
	inventory.consume_water(inventory.get_stored_water_liters())
	body.interact(player)
	_check(inventory.get_stored_water_liters() > 0.0,"well fills the existing water bag")
	if DisplayServer.get_name() != "headless":
		for layer in world.find_children("*","CanvasLayer",true,false): layer.hide()
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.fov = 60
		camera.global_position = player.global_position+Vector3(3,2.0,3.0)
		camera.look_at(well.global_position+Vector3.UP*.9)
		camera.make_current()
		for i in 4: await process_frame
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png("res://docs/world/captures/village_player_well.png") == OK,"Player/well Metal capture")
