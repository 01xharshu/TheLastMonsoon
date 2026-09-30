extends "res://tools/world/validate_village_area.gd"
## Exercise every doorway/courtyard and all three newly occupied workstations.
var homes: Array[Node] = []
var workstation_results: Array[Dictionary] = []

func _ground(p: Vector2) -> float:
	# A start inside a house must sit above the real plinth, not penetrate it.
	var floor_height: float = super._ground(p)
	for home: Node3D in homes:
		var local: Vector3 = home.to_local(Vector3(p.x,home.global_position.y,p.y))
		var plinth: Node3D = home.get_node("Plinth")
		var collision: CollisionShape3D = plinth.find_children("*","CollisionShape3D",true,false)[0]
		var half: Vector3 = collision.shape.size*.5
		if absf(local.x) <= half.x and absf(local.z) <= half.z:
			floor_height = maxf(floor_height,home.global_position.y+plinth.position.y+half.y)
	return floor_height

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
	if DisplayServer.get_name() != "headless": DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	homes = get_nodes_in_group("bhairavpur_home")
	var styles: Dictionary = {}
	for home in homes:
		var style: String = home.get_meta("roof_style","")
		styles[style] = styles.get(style,0)+1
	_check(styles.size() == 3 and not styles.has(""),"three roof families have live homes")
	_check(get_nodes_in_group("bhairavpur_workshop").size() == 3,"three craft homes exist")
	var subset := "--metal-samples" in OS.get_cmdline_user_args()
	for home: Node3D in homes:
		var id := int(str(home.name).trim_prefix("BhairavpurHouse"))
		if subset and not id in [0,1,2,18,25,27,30]: continue
		var collision: CollisionShape3D = home.get_node("Plinth").find_children("*","CollisionShape3D",true,false)[0]
		var d: float = collision.shape.size.z-1.0
		var start := home.to_global(Vector3(0,0,d*.5+6.6))
		var inside := home.to_global(Vector3(0,0,-.1))
		var points := [Vector2(start.x,start.z),Vector2(inside.x,inside.z)]
		await _walk_route(str(home.name)+" entry",points)
		points.reverse()
		await _walk_route(str(home.name)+" exit",points)
	for home: Node3D in get_nodes_in_group("bhairavpur_workshop"):
		await _workstation(home)
	# Samples of the lanes next to the changed porches and courtyards.
	await _walk_route("detailed west lane",[Vector2(-374,230),Vector2(-374,280)])
	await _walk_route("detailed market lane",[Vector2(-352,275),Vector2(-278,275)])
	var report := {"status":"PASS" if failures.is_empty() else "FAIL","renderer":RenderingServer.get_current_rendering_method(),"display_server":DisplayServer.get_name(),"entrance_scope":"seven representative homes" if subset else "all 33 homes","roof_families":styles,"routes":routes,"workstations":workstation_results,"failures":failures}
	var path := "res://docs/world/village_detail_metal.json" if DisplayServer.get_name() != "headless" else "res://docs/world/village_detail_headless.json"
	var output := FileAccess.open(path,FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t")+"\n")
	print("VILLAGE DETAIL ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _workstation(home: Node3D) -> void:
	var collision: CollisionShape3D = home.get_node("Plinth").find_children("*","CollisionShape3D",true,false)[0]
	var d: float = collision.shape.size.z-1.0
	var start := home.to_global(Vector3(2.25,0,d*.5+3.0))
	player.global_position = Vector3(start.x,_ground(Vector2(start.x,start.z))+.95,start.z)
	player.velocity = Vector3.ZERO
	player.get_node("CameraPivot").global_rotation.y = home.global_rotation.y
	for i in 12: await physics_frame
	var touched := false
	var craft: String = home.get_meta("craft")
	var pieces := ["CarpenterBench"] if craft == "carpenter" else (["LoomEnvelope"] if craft == "weaver" else ["PotterFlywheel","WheelAxle","WheelHead"])
	Input.action_press("move_forward")
	for i in 100:
		await physics_frame
		for index in player.get_slide_collision_count():
			var collider: Object = player.get_slide_collision(index).get_collider()
			for name in pieces:
				var piece: Node = home.get_node(name)
				touched = touched or collider == piece or (collider is Node and piece.is_ancestor_of(collider))
	Input.action_release("move_forward")
	var ending: Vector3 = home.to_local(player.global_position)
	var ok := touched and ending.z > d*.5+.8
	_check(ok,craft+" workstation stops actual Player")
	workstation_results.append({"craft":craft,"pass":ok,"contact":touched,"finish_local":str(ending)})
