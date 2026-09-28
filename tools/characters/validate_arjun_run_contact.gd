extends SceneTree
## Physical sprint diagnostic: travel, foot height, and low-foot world drift.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-35,0)
	sun.light_energy = 1.8
	stage.add_child(sun)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(.45,.52,.56)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(.8,.8,.78)
	environment.environment = env
	stage.add_child(environment)
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
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(50,50)
	ground.mesh = plane
	stage.add_child(ground)
	var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
	stage.add_child(actor)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.fov = 50.0
	camera.current = true
	actor.get_node("UI").hide()
	actor.global_position = Vector3(0,1,0)
	for i in 30: await physics_frame
	var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
	var skeleton: Skeleton3D = visual.skeleton
	var start := actor.global_position
	var low := INF
	var high := -INF
	var contact_drift := 0.0
	var contact_samples := 0
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
				contact_drift = maxf(contact_drift,Vector2(foot.x-previous.x,foot.z-previous.z).length())
				contact_samples += 1
			last_positions[side] = foot
	Input.action_release("move_forward")
	Input.action_release("sprint")
	if DisplayServer.get_name() != "headless":
		actor.set_physics_process(false)
		visual.set_process(false)
		camera.global_position = actor.global_position + Vector3(3.3,1.2,1.5)
		camera.look_at(actor.global_position + Vector3(0,0,0))
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://docs/characters/arjun/animation_tree_run_contact.png") == OK)
	var distance := actor.global_position.distance_to(start)
	print("ARJUN RUN CONTACT | %.2f m in 90 frames, foot-relative %.3f..%.3f m, low-foot drift %.3f m/frame across %d samples" % [distance,low,high,contact_drift,contact_samples])
	if not actor.is_on_floor() or distance < 8.0 or contact_samples < 4 or contact_drift > .15:
		push_error("ARJUN RUN CONTACT: sprint travel or low-foot drift failed")
		quit(1)
		return
	quit()
