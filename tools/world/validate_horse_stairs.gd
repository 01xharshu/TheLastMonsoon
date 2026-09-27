extends Node
var world: Node3D
var horse: CharacterBody3D
var failures: Array[String] = []
var results: Array[Dictionary] = []

func _ready() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)

func route(parent: Node3D, start: Vector3, yaw: float, target: float, increasing: bool, min_y: float, max_y: float, label: String) -> void:
	horse.global_position = parent.to_global(start)
	horse.global_rotation.y = yaw
	horse.velocity = Vector3.ZERO
	horse.pace = 0.0
	horse.step_ground_grace = 0.0
	horse.step_up_grace = 0.0
	for i in 15: await get_tree().physics_frame
	Input.action_press("move_forward")
	var reached := false
	var fall := 0.0
	var jumped := false
	for i in 600:
		await get_tree().physics_frame
		fall = minf(fall,horse.velocity.y)
		jumped = jumped or Input.is_action_pressed("jump")
		var p := parent.to_local(horse.global_position)
		if (p.z >= target) if increasing else (p.z <= target):
			reached = true
			break
	Input.action_release("move_forward")
	for i in 60: await get_tree().physics_frame
	var ending := parent.to_local(horse.global_position)
	print(label," finish=",ending," fall=",fall)
	check(reached and ending.y >= min_y and ending.y <= max_y and not jumped,label)
	if label.ends_with("down"): check(fall > -3.0,label+" avoids a large fall")
	results.append({"route":label,"finish":str(ending),"reached":reached,"fall_speed":fall,"jump_used":jumped})
	if label == "Compound stairs up" and DisplayServer.get_name() != "headless":
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.global_position = parent.to_global(Vector3(-40,8,8))
		camera.look_at(horse.global_position+Vector3.UP*1.3)
		camera.make_current()
		for i in 4: await get_tree().process_frame
		RenderingServer.force_draw(false)
		check(get_tree().root.get_texture().get_image().save_png("res://docs/world/captures/horse_compound_stairs.png")==OK,"horse stair capture")

func run() -> void:
	world = preload("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	for i in 15: await get_tree().physics_frame
	horse = world.get_node("VillageHorse")
	var actor: CharacterBody3D = world.get_node("Player")
	actor.set_process_unhandled_input(false)
	actor.get_node("UI").hide()
	world.get_node("LandscapeUI").hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Input.action_release("jump")
	actor.global_position = horse.global_position + Vector3(0,1,2)
	check(horse.board(actor),"horse boards for stair test")
	for i in 60: await get_tree().physics_frame
	var main: Node3D = world.get_node("Settlement/GovernmentHouse/MainHouse")
	await route(main,Vector3(0,.1,31.2),0,26,false,.4,.55,"Government entrance up")
	await route(main,Vector3(0,.5,26),PI,31.2,true,0,.2,"Government entrance down")
	await route(main,Vector3(20,.4,13.2),0,-12,false,4.5,4.75,"Government first flight up")
	await route(main,Vector3(20,4.7,-13.2),PI,12,true,.25,.5,"Government first flight down")
	var compound: Node3D = world.find_child("ColonialCompound",true,false)
	await route(compound,Vector3(-47.2,.15,-5.8),PI,4.0,true,4.7,4.95,"Compound stairs up")
	await route(compound,Vector3(-47.2,4.9,4.5),0,-5.8,false,.05,.2,"Compound stairs down")
	Input.action_press("jump")
	for i in 3: await get_tree().physics_frame
	Input.action_release("jump")
	check(horse.velocity.y > 2.0 and horse.rigged_anim.current_animation.ends_with("Gallop_Jump"),"horse still performs an actual jump")
	for i in 100: await get_tree().physics_frame
	check(horse.is_on_floor(),"horse jump lands after stair traversal")
	check(results.size() == 6,"all six horse stair routes completed")
	var file := FileAccess.open("res://docs/world/horse_stairs_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","routes":results,"failures":failures},"\t")+"\n")
	print("HORSE STAIRS ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
