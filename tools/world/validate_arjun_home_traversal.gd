extends SceneTree
var player: CharacterBody3D
var home: Node3D
var results: Array[Dictionary] = []
func _initialize() -> void: run.call_deferred()
func walk_to(point: Vector3, label: String) -> bool:
	var target := home.to_global(point)
	var reached := false
	for frame in 900:
		var offset := target-player.global_position
		offset.y = 0
		if offset.length() < 0.22:
			reached = true
			break
		player.get_node("CameraPivot").global_rotation.y = atan2(-offset.x,-offset.z)
		Input.action_press("move_forward")
		await physics_frame
	Input.action_release("move_forward")
	for i in 8: await physics_frame
	results.append({"label":label,"reached":reached,"position":str(home.to_local(player.global_position))})
	print(label, " reached=",reached," position=",home.to_local(player.global_position))
	return reached
func run() -> void:
	var world = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 15: await physics_frame
	home = get_nodes_in_group("arjun_home")[0]
	player = world.get_node("Player")
	world.get_node("GameTimeSystem").clock_paused = true
	player.global_position = home.to_global(Vector3(0,1.0,24))
	player.velocity = Vector3.ZERO
	var door = home.get_node_or_null("EntranceDoor")
	if door != null and not door.opened: door.interact(player)
	for i in 20: await physics_frame
	var ok := true
	for stop in [[Vector3(0,0,5),"courtyard"],[Vector3(0,0,3),"doorway"],[Vector3(-2.35,0,3),"sleep room"],[Vector3(-2.35,0,-0.3),"bed approach"]]:
		if not await walk_to(stop[0],stop[1]):
			ok = false
			break
	if ok:
		if DisplayServer.get_name() != "headless":
			player.get_node("UI").hide()
			world.get_node("LandscapeUI").hide()
			for i in 5: await process_frame
			root.get_texture().get_image().save_png("res://docs/world/captures/arjun_home_player_camera.png")
		world.get_node("Charpai").interact(player)
		await create_timer(4.2).timeout
		ok = player.get_meta("rest_action","") == ""
		for stop in [[Vector3(-2.35,0,3),"wake exit room"],[Vector3(0,0,3),"exit doorway"],[Vector3(0,0,5),"exit courtyard"],[Vector3(0,0,24),"south lane"]]:
			if not await walk_to(stop[0],stop[1]):
				ok = false
				break
	var file := FileAccess.open("res://docs/world/arjun_home_traversal.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"PASS" if ok else "FAIL","display":DisplayServer.get_name(),"results":results},"\t")+"\n")
	print("ARJUN HOME CONTROLLER ","PASS" if ok else "FAIL")
	quit(0 if ok else 1)
