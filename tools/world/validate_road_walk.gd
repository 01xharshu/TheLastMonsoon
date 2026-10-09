extends SceneTree
var world: Node3D
var player: CharacterBody3D
var capture_viewport: Viewport
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DisplayServer.window_set_size(Vector2i(1280,720))
	if "--motion" in OS.get_cmdline_user_args(): DirAccess.make_dir_recursive_absolute("/tmp/tlm_road_motion_oct08")
	world = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	player = world.get_node("Player")
	player.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Isolate the real controller/animation, retaining world collision and clothing.
	for node in [world]+world.find_children("*","",true,false):
		if node==player or player.is_ancestor_of(node): continue
		node.set_process(false)
		node.set_physics_process(false)
		if node is AnimationTree: node.active = false
		elif node is AnimationPlayer: node.pause()
	capture_viewport = root
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280,720))
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1280,720)
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		world.reparent(viewport)
		capture_viewport = viewport
	player.get_node("UI").hide()
	world.get_node("LandscapeUI").hide()
	var rows: Array = []
	var errors: Array[String] = []
	var routes := [["switchback",Vector2(479,-250.7),Vector2(501,-251.8)],["uphill_join",Vector2(488,-239.8),Vector2(465,-250)],["downhill_join",Vector2(465,-250),Vector2(488,-239.8)]]
	var space := world.get_world_3d().direct_space_state
	var camera := Camera3D.new()
	world.add_child(camera)
	for route in routes:
		var a: Vector2 = route[1]
		var b: Vector2 = route[2]
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(a.x,180,a.y),Vector3(a.x,80,a.y)))
		assert(not hit.is_empty())
		player.global_position = hit.position+Vector3.UP*1.05
		player.velocity = Vector3.ZERO
		var direction := (b-a).normalized()
		player.get_node("CameraPivot").global_rotation.y = atan2(-direction.x,-direction.y)
		for i in 15: await physics_frame
		var start := player.global_position
		var min_fall := 0.0
		var airborne := 0
		var frames := 0
		camera.global_position = player.global_position+Vector3(-4,2,4)
		camera.look_at(player.global_position+Vector3.UP*.9)
		camera.make_current()
		Input.action_press("move_forward")
		while frames < 700:
			await physics_frame
			frames += 1
			min_fall = minf(min_fall,player.velocity.y)
			if not player.is_on_floor(): airborne += 1
			if Vector2(player.global_position.x,player.global_position.z).distance_to(b)<.8: break
			if "--motion" in OS.get_cmdline_user_args() and route[0] == "switchback" and frames % 6 == 0:
				camera.global_position = player.global_position+Vector3(-4,2,4)
				camera.look_at(player.global_position+Vector3.UP*.9)
				RenderingServer.force_draw()
				capture_viewport.get_texture().get_image().save_png("/tmp/tlm_road_motion_oct08/frame_%04d.png" % (frames/6))
			if frames == 130 and DisplayServer.get_name() != "headless":
				camera.global_position = player.global_position+Vector3(-4,2,4)
				camera.look_at(player.global_position+Vector3.UP*.9)
				camera.make_current()
				RenderingServer.force_draw()
				capture_viewport.get_texture().get_image().save_png("res://docs/world/captures/terrain_2026-10-08/player_"+route[0]+".png")
		Input.action_release("move_forward")
		var reached := Vector2(player.global_position.x,player.global_position.z).distance_to(b)<1.0
		if not reached: errors.append(route[0]+" failed to reach destination")
		if min_fall < -3.0: errors.append(route[0]+" exposed an unsupported fall")
		rows.append({"route":route[0],"start":start,"finish":player.global_position,"reached":reached,"frames":frames,"airborne_frames":airborne,"minimum_vertical_velocity":min_fall,"jump_input":Input.is_action_pressed("jump")})
		print("ROAD WALK ",JSON.stringify(rows[-1]))
	var report := {"passed":errors.is_empty(),"routes":rows,"errors":errors,"scope":"real controller forward input at 1x physics; other actors paused; clothing/animation untouched"}
	FileAccess.open("res://docs/world/road_walk_2026-10-08.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("ROAD WALK RESULT ",JSON.stringify(report))
	await root.get_node("SaveManager").quit_game(0 if errors.is_empty() else 1)
