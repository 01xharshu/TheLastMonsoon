extends SceneTree
## Fast real-player contact and open-route checks for placed period props.

const SMALL_PROPS := ["BhairavpurWoodenBucket", "BhairavpurBrassPot", "BhairavpurWickerBasket"]
var failures: Array[String] = []
var results: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	var player: CharacterBody3D = world.get_node("Player")
	var settlement: Node3D = world.get_node("Settlement")
	player.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 12:
		await physics_frame
	for name in SMALL_PROPS:
		var prop: StaticBody3D = settlement.get_node(name)
		player.global_position = prop.global_position + Vector3(0,.95,2.0)
		player.velocity = Vector3.ZERO
		player.get_node("CameraPivot").global_rotation.y = 0.0
		for i in 12:
			await physics_frame
		var touched := false
		Input.action_press("sprint")
		Input.action_press("move_forward")
		for i in 95:
			await physics_frame
			for index in player.get_slide_collision_count():
				if player.get_slide_collision(index).get_collider() == prop:
					touched = true
		Input.action_release("move_forward")
		Input.action_release("sprint")
		for i in 8:
			await physics_frame
		var crossed := player.global_position.z < prop.global_position.z - .35
		var ok := touched and not crossed
		print(("PASS " if ok else "FAIL ") + name + " sprint touched=" + str(touched) + " crossed=" + str(crossed))
		if not ok:
			failures.append(name + " sprint")
		results.append({"check":name + " sprint","pass":ok,"touched":touched,"crossed":crossed})
	await walk_route(player, "compound gate lane", Vector3(345,12.98,256), PI, 330, Vector3(345,12.98,274), true)
	await walk_route(player, "village aisle", Vector3(-336,8.1,230), -PI*.5, 360, Vector3(-316,8.1,230), false)
	var output := FileAccess.open("res://docs/world/period_prop_route_validation.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","renderer":RenderingServer.get_current_rendering_method(),"results":results,"failures":failures},"\t")+"\n")
	print("PERIOD PROP ROUTES ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)

func walk_route(player: CharacterBody3D, label: String, start: Vector3, yaw: float, frames: int, goal: Vector3, along_z: bool) -> void:
	player.global_position = start
	player.velocity = Vector3.ZERO
	player.get_node("CameraPivot").global_rotation.y = yaw
	for i in 12:
		await physics_frame
	var touched_prop := false
	Input.action_press("move_forward")
	for i in frames:
		await physics_frame
		for index in player.get_slide_collision_count():
			var collider := player.get_slide_collision(index).get_collider()
			if collider is Node and collider.is_in_group("solid_period_prop"):
				touched_prop = true
	Input.action_release("move_forward")
	var finish := player.global_position
	var reached := finish.z >= goal.z - 1.0 if along_z else finish.x >= goal.x - 1.0
	var ok := reached and not touched_prop
	print(("PASS " if ok else "FAIL ") + label + " finish=" + str(finish) + " touched_prop=" + str(touched_prop))
	if not ok:
		failures.append(label)
	results.append({"check":label,"pass":ok,"finish":str(finish),"touched_prop":touched_prop})
