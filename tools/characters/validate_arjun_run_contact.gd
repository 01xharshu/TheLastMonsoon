extends SceneTree
## Physical sprint diagnostic: travel, foot height, and low-foot world drift.

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
	box.size = Vector3(50,.4,50)
	collision.shape = box
	collision.position.y = -.2
	floor.add_child(collision)
	var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
	stage.add_child(actor)
	actor.global_position = Vector3(0,1,0)
	for i in 30: await physics_frame
	var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
	var skeleton: Skeleton3D = visual.skeleton
	var start := actor.global_position
	var low := INF
	var high := -INF
	var contact_drift := 0.0
	var contact_samples := 0
	var drifts: Array[float] = []
	var last_positions: Dictionary = {}
	Input.action_press("move_forward")
	Input.action_press("sprint")
	for frame in 90:
		await physics_frame
		if frame < 25: continue
		for side in ["l", "r"]:
			var index := skeleton.find_bone("foot_" + side)
			var foot: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(index).origin
			var height := foot.y - actor.global_position.y
			low = minf(low,height)
			high = maxf(high,height)
			# Only the lowest stance portion represents a planted-foot candidate.
			if last_positions.has(side) and height < -.87:
				var previous: Vector3 = last_positions[side]
				var drift := Vector2(foot.x-previous.x,foot.z-previous.z).length()
				contact_drift = maxf(contact_drift,drift)
				drifts.append(drift)
				contact_samples += 1
			last_positions[side] = foot
	Input.action_release("move_forward")
	Input.action_release("sprint")
	var distance := actor.global_position.distance_to(start)
	drifts.sort()
	var p90 := drifts[int(floorf((drifts.size()-1)*.9))] if not drifts.is_empty() else INF
	print("ARJUN RUN CONTACT | %.2f m in 90 frames, foot-relative %.3f..%.3f m, low-foot drift p90 %.3f / max %.3f m/frame across %d samples" % [distance,low,high,p90,contact_drift,contact_samples])
	if not actor.is_on_floor() or distance < 7.0 or contact_samples < 4 or p90 > .12 or contact_drift > .4:
		push_error("ARJUN RUN CONTACT: sprint travel or low-foot drift failed")
		quit(1)
		return
	quit()
