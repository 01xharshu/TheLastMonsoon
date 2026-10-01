extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280,720)
	var world = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 10: await physics_frame
	var home: Node3D = get_nodes_in_group("arjun_home")[0]
	var bed: Node3D = world.get_node("Charpai")
	var player = world.get_node("Player")
	player.set_physics_process(false)
	player.hide()
	player.get_node("UI").hide()
	world.get_node("LandscapeUI").hide()
	world.get_node("GameTimeSystem").clock_paused = true
	assert(home.to_local(bed.global_position).distance_to(Vector3(-2.35,0.24,-1.4)) < 0.02)
	var route := [Vector3(0,0,24),Vector3(0,0,5),Vector3(0,0,3),Vector3(-2.35,0,3),Vector3(-2.35,0,-0.3)]
	var count := 0
	for segment in range(route.size()-1):
		var a: Vector3 = route[segment]
		var b: Vector3 = route[segment+1]
		var steps := ceili(a.distance_to(b)/0.25)
		for step in steps+1:
			var p := home.to_global(a.lerp(b,float(step)/steps))
			var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP*2,p-Vector3.UP)
			ray.exclude = [player.get_rid(),bed.get_rid()]
			var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
			assert(not hit.is_empty(),"House route missing support")
			var q := PhysicsShapeQueryParameters3D.new()
			var shape := CapsuleShape3D.new()
			shape.radius = 0.34
			shape.height = 1.8
			q.shape = shape
			q.transform = Transform3D(Basis.IDENTITY,Vector3(p.x,hit.position.y+1.03,p.z))
			q.exclude = [player.get_rid()]
			assert(world.get_world_3d().direct_space_state.intersect_shape(q,8).is_empty(),"Blocked house route at "+str(home.to_local(p)))
			count += 1
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	for view in [{"name":"exterior","at":Vector3(11,6,15),"look":Vector3(0,1.2,2)},{"name":"interior","at":Vector3(-3.7,2.05,2.6),"look":Vector3(-1.2,1.1,-1.5)},{"name":"kitchen","at":Vector3(3.8,2.05,2.6),"look":Vector3(2.0,0.9,-2.0)}]:
		if view.name != (OS.get_environment("TLM_HOUSE_VIEW") if not OS.get_environment("TLM_HOUSE_VIEW").is_empty() else "exterior"): continue
		camera.global_position = home.to_global(view.at)
		camera.look_at(home.to_global(view.look))
		await create_timer(0.5).timeout
		for i in 8: await process_frame
		if DisplayServer.get_name() != "headless":
			root.get_texture().get_image().save_png("res://docs/world/captures/arjun_house_"+view.name+".png")
	var survival = player.get_node("SurvivalComponent")
	survival.energy = 20.0
	var before: float = world.get_node("GameTimeSystem").total_game_minutes
	bed.interact(player)
	await create_timer(4.2).timeout
	assert(not bed.resting and player.get_meta("rest_action", "") == "", "Home sleep did not release player")
	assert(is_equal_approx(world.get_node("GameTimeSystem").total_game_minutes-before,480.0),"Home sleep time jump failed")
	print("ARJUN HOUSE PASS | route samples ",count," | charpai inside ",home.to_local(bed.global_position))
	quit()
