extends SceneTree
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for frame in 8: await physics_frame
	var district: Node3D = world.get_node("Settlement/AdministrativeDistrict")
	var actor: CharacterBody3D = world.get_node("Player")
	actor.set_physics_process(false)
	assert(get_nodes_in_group("administrative_buildings").size() == 3)
	
	var space := world.get_world_3d().direct_space_state
	var entrances: Dictionary = {}
	for building in get_nodes_in_group("administrative_buildings"):
		var entry: Vector3 = building.get_node("Entrance").global_position
		var center: Vector3 = building.to_global(Vector3(0,0.25,0.0))
		var ray := PhysicsRayQueryParameters3D.create(entry+Vector3.UP,center+Vector3.UP)
		ray.exclude = [actor.get_rid()]
		assert(space.intersect_ray(ray).is_empty(),"Blocked room entry: "+str(building.name))
		var floor_ray := PhysicsRayQueryParameters3D.create(center+Vector3.UP,center-Vector3.UP)
		var hit := space.intersect_ray(floor_ray)
		assert(not hit.is_empty() and absf(hit.position.y-10.24)<0.03,"Unsupported floor: "+str(building.name))
		actor.global_position = entry + Vector3.UP * (actor.get_node("CollisionShape3D").shape.height * 0.5)
		actor.velocity = Vector3.ZERO
		await physics_frame
		var walked := false
		for frame in 600:
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
			for i in actor.get_slide_collision_count(): print(actor.get_slide_collision(i).get_collider().get_path(), " ", actor.get_slide_collision(i).get_position())
			quit(1)
			return
		entrances[str(building.name)] = {"entry":str(entry),"floor":hit.position.y,"player_walk":walked}
	# Actual resident collider must match new survey grade, rather than a second ground sheet.
	var terrain_excludes: Array[RID] = [actor.get_rid()]
	for body in world.find_children("*", "StaticBody3D", true, false):
		if body.name != "GroundCollision": terrain_excludes.append(body.get_rid())
	var terrain_samples := 0
	for x in [460,480,500,520,540,560,580]:
		for z in [75,95,120,145,165]:
			var ray := PhysicsRayQueryParameters3D.create(Vector3(x,40,z),Vector3(x,-10,z),1)
			ray.exclude = terrain_excludes
			var hit := space.intersect_ray(ray)
			assert(not hit.is_empty())
			assert(absf(hit.position.y - 10.0) < 0.05,"Old terrain remains below the surveyed plot")
			terrain_samples += 1
	for area in [district,world.get_node("Settlement/BritishCantonment")]:
		assert(area.find_children("*","Label3D",true,false).is_empty(), "Building text remains")
		assert(area.find_children("PublicNotice","Node",true,false).is_empty(), "Posted building notice remains")
	assert(get_nodes_in_group("administrative_chairs").size() == 7)
	var chair_supports := 0
	for chair in get_nodes_in_group("administrative_chairs"):
		var probe := PhysicsRayQueryParameters3D.create(chair.global_position+Vector3.UP*.12,chair.global_position-Vector3.UP*.12)
		probe.exclude = [actor.get_rid()]
		var support := space.intersect_ray(probe)
		assert(not support.is_empty() and absf(support.position.y-chair.global_position.y)<.015,"Unsupported office chair")
		chair_supports += 1
	var open_front_windows := 0
	for building in get_nodes_in_group("administrative_buildings"):
		var dimensions: Vector2 = building.get_meta("room_dimensions")
		for side in [-1,1]:
			for offset in [-2.1,2.1]:
				var x: float = side*(dimensions.x/4+offset)+.13
				var probe := PhysicsRayQueryParameters3D.create(building.to_global(Vector3(x,2.1,dimensions.y/2-.5)),building.to_global(Vector3(x,2.1,dimensions.y/2+.5)))
				probe.exclude = [actor.get_rid()]
				assert(space.intersect_ray(probe).is_empty(),"Front window has a solid wall behind its frame")
				open_front_windows += 1
	var report := {"date":"2026-10-01","status":"prototype","buildings":entrances,"resident_terrain_samples":terrain_samples,"building_text_nodes":0,"supported_chairs":chair_supports,"open_front_windows":open_front_windows,"renderer":RenderingServer.get_current_rendering_method(),"open":"staff, treasury controlled access, revenue/court operations, historical art, full approach route, performance"}
	var file := FileAccess.open("res://docs/world/administrative_district_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	if DisplayServer.get_name() != "headless":
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.global_position = Vector3(610,70,215)
		camera.look_at(Vector3(520,10,120))
		camera.make_current()
		actor.get_node("UI").hide()
		for frame in 8: await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://docs/world/captures/administrative_district_overview.png") == OK)
		actor.get_node("VisualRoot").hide()
		for view in [
			["collectorate_exterior",Vector3(534,13.2,114),Vector3(520,12,99)],
			["treasury_exterior",Vector3(493,13.2,153),Vector3(477,12,137)],
			["courthouse_exterior",Vector3(579,13.2,154),Vector3(559,12,139)],
			["collectorate_workstation",Vector3(533,11.8,97),Vector3(530,11.25,92)],
			["collectorate_interior",Vector3(520,12.8,99),Vector3(520,11.8,91)],
			["treasury_interior",Vector3(477,12.8,138),Vector3(477,11.6,126)],
			["courthouse_interior",Vector3(559,12.8,137),Vector3(559,11.8,122)]
		]:
			camera.global_position = view[1]
			camera.look_at(view[2])
			for frame in 8: await process_frame
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png("res://docs/world/captures/"+view[0]+".png") == OK)

		var clock: Node = world.get_node("GameTimeSystem")
		clock.call("advance_minutes",22.0*60.0-fmod(float(clock.get("total_game_minutes")),1440.0))
		camera.global_position = Vector3(533,11.8,97)
		camera.look_at(Vector3(530,11.25,92))
		for frame in 12: await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://docs/world/captures/collectorate_night.png") == OK)

	print("ADMINISTRATIVE WORLD: PASS | three entrances/player walks, no building text, 35 terrain samples")
	quit()
