extends SceneTree
## Walk Arjun at gameplay speed over a physical floor and measure foot-bone
## height variation. This is a contact diagnostic, not a visual approval.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var clock := Node.new()
	clock.name = "GameTimeSystem"
	clock.set_script(load("res://world/suryagarh/systems/game_time_system.gd"))
	stage.add_child(clock)
	var floor := StaticBody3D.new()
	stage.add_child(floor)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(30, 0.4, 30)
	collision.shape = box
	collision.position.y = -0.2
	floor.add_child(collision)
	var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
	stage.add_child(actor)
	actor.global_position = Vector3(0, 1, 0)
	for i in 30: await physics_frame
	if not actor.is_on_floor():
		push_error("ARJUN WALK CONTACT: player did not settle on the floor")
		quit(1)
		return
	var skeleton: Skeleton3D = actor.get_node("VisualRoot/CharacterVisual").skeleton
	var idle_foot_y := _lowest_foot_y(skeleton)
	var start := actor.global_position
	var thigh := skeleton.find_bone("thigh_l")
	var last_rotation := skeleton.get_bone_pose_rotation(thigh)
	var largest_step := 0.0
	Input.action_press("move_forward")
	var lowest := INF
	var highest := -INF
	for i in 90:
		await physics_frame
		var difference := _lowest_foot_y(skeleton) - idle_foot_y
		lowest = minf(lowest, difference)
		highest = maxf(highest, difference)
		var rotation := skeleton.get_bone_pose_rotation(thigh)
		largest_step = maxf(largest_step, last_rotation.angle_to(rotation))
		last_rotation = rotation
	Input.action_release("move_forward")
	for i in 30:
		await physics_frame
		var rotation := skeleton.get_bone_pose_rotation(thigh)
		largest_step = maxf(largest_step, last_rotation.angle_to(rotation))
		last_rotation = rotation
	var distance := actor.global_position.distance_to(start)
	if not actor.is_on_floor() or distance < 3.0 or lowest < -0.09 or highest > 0.08 or largest_step > 0.35:
		push_error("ARJUN WALK CONTACT: floor=%s travel=%.2f m foot_delta=%.3f..%.3f m max_step=%.3f rad" % [actor.is_on_floor(), distance, lowest, highest, largest_step])
		quit(1)
		return
	print("ARJUN WALK CONTACT: PASS | travel %.2f m, foot-bone delta %.3f..%.3f m, max pose step %.3f rad" % [distance, lowest, highest, largest_step])
	quit()

func _lowest_foot_y(skeleton: Skeleton3D) -> float:
	var lowest := INF
	for name in ["foot_l", "foot_r"]:
		var index := skeleton.find_bone(name)
		lowest = minf(lowest, (skeleton.global_transform * skeleton.get_bone_global_pose(index)).origin.y)
	return lowest
