extends SceneTree
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for frame in 8: await physics_frame
	var district: Node3D = world.get_node("Settlement/BritishCantonment")
	var actor: CharacterBody3D = world.get_node("Player")
	actor.set_physics_process(false)
	assert(get_nodes_in_group("sepoy_barracks").size() == 4)
	assert(get_nodes_in_group("cantonment_buildings").size() == 9)
	var space := world.get_world_3d().direct_space_state
	var entrances: Dictionary = {}
	for building in get_nodes_in_group("cantonment_buildings"):
		var entry: Vector3 = building.get_node("Entrance").global_position
		var center: Vector3 = building.to_global(Vector3(0,0.25,2.0 if building.name == "CavalryStables" else 0.0))
		var ray := PhysicsRayQueryParameters3D.create(entry+Vector3.UP,center+Vector3.UP)
		ray.exclude = [actor.get_rid()]
		assert(space.intersect_ray(ray).is_empty(),"Blocked room entry: "+str(building.name))
		var floor_ray := PhysicsRayQueryParameters3D.create(center+Vector3.UP,center-Vector3.UP)
		var hit := space.intersect_ray(floor_ray)
		assert(not hit.is_empty() and absf(hit.position.y-8.74)<0.03,"Unsupported floor: "+str(building.name))
		actor.global_position = entry + Vector3.UP * (actor.get_node("CollisionShape3D").shape.height * 0.5)
		actor.velocity = Vector3.ZERO
		await physics_frame
		var walked := false
		for frame in 240:
			var toward: Vector3 = center-actor.global_position
			toward.y = 0
			if toward.length() < 0.35:
				walked = true
				break
			actor.velocity = toward.normalized()*2.5 + Vector3(0,-2,0)
			actor.move_and_slide()
			actor.call("_try_walk_step", 1.0/60.0, toward.normalized()*2.5/60.0)
			await physics_frame
		if not walked:
			print("WALK DEBUG ",building.name," actor=",actor.global_position," target=",center," on_floor=",actor.is_on_floor())
			for i in actor.get_slide_collision_count(): print(actor.get_slide_collision(i).get_collider())
			quit(1)
			return
		entrances[str(building.name)] = {"entry":str(entry),"floor":hit.position.y,"player_walk":walked}
	# Actual resident collider must match new survey grade, rather than a second ground sheet.
	var terrain_excludes: Array[RID] = [actor.get_rid()]
	for body in world.find_children("*", "StaticBody3D", true, false):
		if body.name != "GroundCollision": terrain_excludes.append(body.get_rid())
	var terrain_samples := 0
	for x in [440,460,480,500,520,540,560]:
		for z in [415,430,470,505,525]:
			var ray := PhysicsRayQueryParameters3D.create(Vector3(x,40,z),Vector3(x,-10,z),1)
			ray.exclude = terrain_excludes
			var hit := space.intersect_ray(ray)
			assert(not hit.is_empty())
			assert(absf(hit.position.y - 8.5) < 0.05,"Old terrain remains below the surveyed plot")
			terrain_samples += 1
	var magazine: Node3D = district.get_node("GunpowderMagazine")
	for x in [-4.0,0.0,4.0]:
		var vent := PhysicsRayQueryParameters3D.create(magazine.to_global(Vector3(x,3.1,-4.5)),magazine.to_global(Vector3(x,3.1,-5.6)))
		vent.exclude = [actor.get_rid()]
		assert(space.intersect_ray(vent).is_empty(), "Magazine vent is blocked")
	var report := {"date":"2026-10-01","status":"prototype","buildings":entrances,"resident_terrain_samples":terrain_samples,"magazine_open_vents":3,"renderer":RenderingServer.get_current_rendering_method(),"open":"sepoy population, horse population, working hospital/depot, historical art, full approach route, performance"}
	var file := FileAccess.open("res://docs/world/cantonment_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	if DisplayServer.get_name() != "headless":
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.global_position = Vector3(570,80,365)
		camera.look_at(Vector3(500,8.5,470))
		camera.make_current()
		actor.get_node("UI").hide()
		for frame in 8: await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://docs/world/captures/cantonment_overview.png") == OK)
	print("CANTONMENT WORLD: PASS | nine room entrances/player walks, four barrack lines, 35 terrain samples")
	quit()
