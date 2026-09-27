extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("validate")

func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)

func validate() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 5: await physics_frame
	var builder: Node3D = world.get_node("Settlement")
	var landing: Node3D = builder.get_node("BhairavpurBoatLanding")
	var planks: Array[Node3D] = []
	var buried := 0
	var max_burial := 0.0
	for node in landing.get_children():
		if not node.has_meta("deck_a"): continue
		planks.append(node)
		var a: Vector3 = node.get_meta("deck_a")
		var b: Vector3 = node.get_meta("deck_b")
		for t in [0.0,.5,1.0]:
			var surface: Vector3 = a.lerp(b,t)
			for dz in [-1.4,0.0,1.4]:
				var intrusion: float = builder.layout.height(surface.x,surface.z+dz)-surface.y
				max_burial = maxf(max_burial,intrusion)
				if intrusion > .025: buried += 1
	check(buried == 0,"Jetty deck intersects bank terrain")
	check(planks.size() == 63,"Jetty sample omitted a deck segment")
	var pile_count := 0
	for node in landing.get_children():
		if not node.has_meta("ground_y"): continue
		pile_count += 1
		var shape: BoxShape3D = node.find_children("*","CollisionShape3D",true,false)[0].shape
		check(node.position.y-shape.size.y*.5 <= float(node.get_meta("ground_y")),"Jetty pile floats above bank/river bed")
	var residence: Node3D = builder.get_node("GovernmentHouse")
	var posts := residence.find_children("*","Node3D",true,false).filter(func(node): return node.has_meta("floor_y"))
	check(posts.size() == 196,"Government House rails lack visible support")
	var house: Node3D = residence.get_node("MainHouse")
	for pair in [[20.0,0.0],[28.0,4.6]]:
		for side in [-1.0,1.0]:
			var query := PhysicsRayQueryParameters3D.create(house.to_global(Vector3(pair[0],pair[1]+2.8,0)),house.to_global(Vector3(pair[0]+side*2.5,pair[1]+2.8,0)))
			var hit := house.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and hit.collider.is_in_group("stair_guards"),"Stair guard lacks side collision")
	if DisplayServer.get_name() != "headless":
		world.get_node("Player/UI").hide()
		if world.has_node("LandscapeUI"): world.get_node("LandscapeUI").hide()
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.current = true
		var start: Vector3 = planks[0].global_position
		var finish: Vector3 = planks[-1].global_position
		camera.global_position = start.lerp(finish,.35)+Vector3(-8,8,13)
		camera.look_at(start.lerp(finish,.4))
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/world/captures/30_period_landing.png")
		camera.global_position = residence.to_global(Vector3(29,5,-25))
		camera.look_at(residence.to_global(Vector3(25,3,-35)))
		for i in 3: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/world/captures/31_period_stair_support.png")
	var actor: CharacterBody3D = world.get_node("Player")
	actor.set_process_input(false)
	var beginning: Vector3 = planks[0].get_meta("deck_a")
	var end: Vector3 = planks[-1].get_meta("deck_b")
	actor.global_position = beginning+Vector3(.7,.95,0)
	actor.velocity = Vector3.ZERO
	actor.get_node("CameraPivot").global_rotation.y = -PI/2
	for i in 12: await physics_frame
	Input.action_press("move_forward")
	var reached := false
	var max_fall := 0.0
	for i in 900:
		await physics_frame
		max_fall = maxf(max_fall,-actor.velocity.y)
		if actor.global_position.x >= end.x-1.5:
			reached = true
			break
	Input.action_release("move_forward")
	check(reached,"Player cannot walk from bank to jetty end")
	check(max_fall < 3.0,"Player falls between deck segments")
	var report := {"status":"PASS" if failures.is_empty() else "FAIL","deck_samples":planks.size()*9,"buried_samples":buried,"max_burial_m":max_burial,"grounded_piles":pile_count,"stair_support_count":posts.size(),"jetty_walk_reached":reached,"maximum_down_velocity_m_s":max_fall,"deck_end_y":end.y,"failures":failures}
	var file := FileAccess.open("res://docs/world/period_access_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	print("PERIOD ACCESS ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
