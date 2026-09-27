extends Node
## Existing solid entrance treads and compound wall-walk treads; real Player input.
var world: Node3D
var player: CharacterBody3D
var failures: Array[String] = []
var results: Array[Dictionary] = []

func _ready() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures.append(label)

func position_actor(parent: Node3D, at: Vector3, yaw: float) -> void:
	player.global_position = parent.to_global(at)
	player.velocity = Vector3.ZERO
	player.get_node("CameraPivot").global_rotation.y = yaw
	for i in 12: await get_tree().physics_frame

func walk_to(parent: Node3D, axis: String, target: float, increasing: bool, budget: int) -> Dictionary:
	Input.action_press("move_forward")
	var reached := false
	var fall := 0.0
	var fall_at := Vector3.ZERO
	for i in budget:
		await get_tree().physics_frame
		if player.velocity.y < fall:
			fall = player.velocity.y
			fall_at = parent.to_local(player.global_position)
		var local := parent.to_local(player.global_position)
		var value: float = local.z if axis == "z" else local.x
		if (value >= target) if increasing else (value <= target):
			reached = true
			break
	Input.action_release("move_forward")
	for i in 24: await get_tree().physics_frame
	var local := parent.to_local(player.global_position)
	return {"reached":reached,"position":local,"fall":fall,"fall_at":fall_at,"grounded":player.is_on_floor()}

func test(parent: Node3D, at: Vector3, yaw: float, target_z: float, increasing: bool, min_y: float, max_y: float, label: String) -> void:
	await position_actor(parent, at, yaw)
	var result := await walk_to(parent,"z",target_z,increasing,600)
	var p: Vector3 = result.position
	print(label," position=",p," fall=",result.fall," fall_at=",result.fall_at)
	check(result.reached and p.y >= min_y and p.y <= max_y,label)
	if label.ends_with("descent"):
		check(result.fall > -3.0,label + " avoids a large fall")
	results.append({"label":label,"reached":result.reached,"position":str(p),"fall_speed":result.fall})

func run() -> void:
	world = preload("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	player = world.get_node("Player")
	player.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Input.action_release("jump")
	for i in 15: await get_tree().physics_frame
	var main: Node3D = world.get_node("Settlement/GovernmentHouse/MainHouse")
	await test(main,Vector3(0,.95,31.2),0,26,false,1.25,1.55,"Government entrance straight")
	await test(main,Vector3(-2,.95,31.2),-.25,26,false,1.25,1.55,"Government entrance angled right")
	await test(main,Vector3(2,.95,31.2),.25,26,false,1.25,1.55,"Government entrance angled left")
	await test(main,Vector3(0,1.4,26),PI,31.2,true,.85,1.15,"Government entrance descent")
	var compound: Node3D = world.find_child("ColonialCompound",true,false)
	await test(compound,Vector3(-47.2,.95,-5.8),PI,3.0,true,5.5,5.9,"Compound narrow stairs straight")
	player.get_node("CameraPivot").global_rotation.y = PI/2
	var connection := await walk_to(compound,"x",-50.3,false,180)
	print("Compound wall-walk connection ",connection)
	check(connection.reached and connection.position.y > 5.5,"Compound top connects to wall-walk")
	results.append({"label":"Compound top connects to wall-walk","reached":connection.reached,"position":str(connection.position)})
	await test(compound,Vector3(-47.65,.95,-5.8),PI+.08,3.0,true,5.5,5.9,"Compound narrow stairs angled")
	await test(compound,Vector3(-47.2,5.7,3.5),0,-5.8,false,.85,1.2,"Compound narrow stairs descent")
	var output := FileAccess.open("res://docs/world/exterior_stairs_validation.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","results":results,"failures":failures},"\t")+"\n")
	print("EXTERIOR STAIRS ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
