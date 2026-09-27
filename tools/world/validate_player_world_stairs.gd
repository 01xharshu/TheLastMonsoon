extends Node
## Drives the actual Player controller up staircases already built in Suryagarh.
var failures: Array[String] = []
var player: CharacterBody3D
var world: Node3D
var results: Array[Dictionary] = []

func _ready() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures.append(label)

func ascend(building: Node3D, start_local: Vector3, yaw: float, frames: int, min_local_y: float, end_z: float, label: String) -> void:
	player.global_position = building.to_global(start_local)
	player.velocity = Vector3.ZERO
	player.get_node("CameraPivot").global_rotation.y = yaw
	for i in 12: await get_tree().physics_frame
	var beginning: Vector3 = building.to_local(player.global_position)
	Input.action_press("move_forward")
	var jumped := false
	for i in frames:
		await get_tree().physics_frame
		jumped = jumped or Input.is_action_pressed("jump")
		if i == 200 and label == "Government House second flight" and DisplayServer.get_name() != "headless":
			player.get_node("UI").hide()
			world.get_node("LandscapeUI").hide()
			var camera := Camera3D.new()
			world.add_child(camera)
			camera.global_position = building.to_global(Vector3(29.2,9,5))
			camera.look_at(player.global_position + Vector3.UP * 0.15)
			camera.make_current()
			for frame in 3: await get_tree().process_frame
			check(get_tree().root.get_texture().get_image().save_png("res://docs/world/captures/29_player_world_stairs.png") == OK,"world stair capture")
	Input.action_release("move_forward")
	for i in 8: await get_tree().physics_frame
	var ending: Vector3 = building.to_local(player.global_position)
	print(label," from=",beginning," to=",ending)
	check(not jumped,label + " requires no jump")
	check(ending.y > min_local_y and ((ending.z < end_z) if yaw == 0.0 else (ending.z > end_z)),label + " reaches upper landing")
	results.append({"stair":label,"direction":"up","start":str(beginning),"finish":str(ending),"jump_used":jumped})

func descend(building: Node3D, start_local: Vector3, yaw: float, frames: int, max_y: float, end_z: float, label: String) -> void:
	player.global_position = building.to_global(start_local)
	player.velocity = Vector3.ZERO
	player.get_node("CameraPivot").global_rotation.y = yaw
	for i in 12: await get_tree().physics_frame
	Input.action_press("move_forward")
	var max_fall := 0.0
	for i in frames:
		await get_tree().physics_frame
		max_fall = minf(max_fall, player.velocity.y)
	Input.action_release("move_forward")
	for i in 8: await get_tree().physics_frame
	var ending: Vector3 = building.to_local(player.global_position)
	print(label," descent to=",ending," fall=",max_fall)
	check(ending.y < max_y and ((ending.z < end_z) if yaw == 0.0 else (ending.z > end_z)),label + " reaches lower landing")
	check(max_fall > -3.0,label + " descends without a large fall")
	results.append({"stair":label,"direction":"down","finish":str(ending),"max_fall_speed":max_fall})

func _run() -> void:
	world = preload("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	player = world.get_node("Player")
	player.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Input.action_release("jump")
	for i in 12: await get_tree().physics_frame
	var hall: Node3D = world.find_child("TownHall",true,false)
	var police: Node3D = world.find_child("DistrictPolice",true,false)
	check(hall != null and police != null,"civic staircases exist")
	if hall == null or police == null:
		get_tree().quit(1)
		return
	await ascend(hall,Vector3(hall.stair_x,.95,10.2),0.0,370,hall.floor_y+.8,-9.0,"Town Hall stairs")
	await ascend(police,Vector3(police.stair_x,.95,10.2),0.0,370,police.floor_y+.8,-9.0,"Police stairs")
	var main: Node3D = world.get_node("Settlement/GovernmentHouse/MainHouse")
	await ascend(main,Vector3(20,.95,13.2),0.0,450,5.25,-12.0,"Government House first flight")
	await ascend(main,Vector3(28,5.55,-13.2),PI,450,9.8,12.0,"Government House second flight")
	await descend(hall,Vector3(hall.stair_x,hall.floor_y+.95,-10.2),PI,370,1.4,9.0,"Town Hall stairs")
	await descend(police,Vector3(police.stair_x,police.floor_y+.95,-10.2),PI,370,1.4,9.0,"Police stairs")
	await descend(main,Vector3(20,5.55,-13.2),PI,450,1.7,12.0,"Government House first flight")
	await descend(main,Vector3(28,10.15,13.2),0.0,450,6.0,-12.0,"Government House second flight")
	check(results.size() == 8,"all eight stair traversals completed")
	var file := FileAccess.open("res://docs/world/player_world_stairs_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","renderer":RenderingServer.get_current_rendering_method(),"display_server":DisplayServer.get_name(),"results":results,"failures":failures},"\t")+"\n")
	print("PLAYER WORLD STAIRS ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
