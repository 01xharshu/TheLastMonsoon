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
	assert(get_nodes_in_group("cantonment_buildings").size() == 12)
	assert(get_nodes_in_group("british_barracks").size() == 1)
	assert(get_nodes_in_group("officers_quarters").size() == 1)
	assert(get_nodes_in_group("fort_guards").size() == 2)
	assert(get_nodes_in_group("fort_cannons").size() == 2)
	assert(get_nodes_in_group("fort_armoury").size() == 1)
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
	var cemetery: Node3D = district.get_node("MilitaryCemetery")
	actor.global_position = cemetery.to_global(Vector3(0,1.0,12))
	actor.velocity = Vector3.ZERO
	var cemetery_walk := false
	for frame in 360:
		var target: Vector3 = cemetery.to_global(Vector3(0,0,0))-actor.global_position
		target.y = 0
		if target.length() < .35:
			cemetery_walk = true
			break
		actor.velocity = target.normalized()*2.5+Vector3(0,-2,0)
		actor.move_and_slide()
		await physics_frame
	assert(cemetery_walk,"Cemetery gate/central path blocked")
	# Actual resident collider must match new survey grade, rather than a second ground sheet.
	var terrain_excludes: Array[RID] = [actor.get_rid()]
	for body in world.find_children("*", "StaticBody3D", true, false):
		if body.name != "GroundCollision": terrain_excludes.append(body.get_rid())
	var fort: Node3D = get_nodes_in_group("occupied_command_fort")[0]
	var armoury: Node3D = fort.get_node("FortArmoury")
	var armoury_ray := PhysicsRayQueryParameters3D.create(armoury.to_global(Vector3(0,1.2,9)),armoury.to_global(Vector3(0,1.2,0)))
	armoury_ray.exclude = [actor.get_rid()]
	assert(space.intersect_ray(armoury_ray).is_empty(),"Fort armoury entrance obstructed")
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
	var report := {"date":"2026-10-05","status":"prototype","buildings":entrances,"cemetery_gate_walk":cemetery_walk,"resident_terrain_samples":terrain_samples,"magazine_open_vents":3,"fort_guards":2,"fort_cannons":2,"armoury_entrance_clear":true,"renderer":RenderingServer.get_current_rendering_method(),"open":"sepoy population, horse population, working hospital/depot, historical art, full approach route, performance"}
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
		for spec in [
			["GrainFodderWarehouse","warehouse_interior",Vector3(0,2.1,4.4),Vector3(0,1.2,-2)],
			["GrainFodderWarehouse","warehouse_fodder",Vector3(1,2.0,0),Vector3(6,.7,2)],
			["GrainFodderWarehouse","warehouse_exterior",Vector3(13,6,17),Vector3(0,1.5,0)],
			["CavalryStables","stables_interior",Vector3(12,2.1,3.8),Vector3(-7,1.1,-1.5)],
			["CavalryStables","stables_exterior",Vector3(22,7,19),Vector3(0,1.5,0)],
			["MilitaryHospital","hospital_interior",Vector3(0,2.1,4.3),Vector3(-3,1,-2)],
			["MilitaryHospital","hospital_exterior",Vector3(18,6,17),Vector3(0,1.5,0)],
			["CantonmentChurch","church_interior",Vector3(0,2.1,6.3),Vector3(0,1.3,-5)],
			["CantonmentChurch","church_exterior",Vector3(12,6,16),Vector3(0,2,0)],
			["MilitaryCemetery","cemetery_gate",Vector3(8,3,16),Vector3(0,1,0)],
			["MilitaryCemetery","cemetery_inside",Vector3(0,1.8,8),Vector3(-3,1,-5)]
		]:
			var site: Node3D = district.get_node(spec[0])
			camera.global_position = site.to_global(spec[2])
			camera.look_at(site.to_global(spec[3]))
			for frame in 8: await process_frame
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png("res://docs/world/captures/service_"+spec[1]+".png") == OK)
		camera.global_position = fort.to_global(Vector3(105,60,115))
		camera.look_at(fort.to_global(Vector3(30,0,0)))
		for frame in 8: await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://docs/world/captures/military_fort_overview.png") == OK)
	print("CANTONMENT WORLD: PASS | twelve room entrances/player walks, four barrack lines, 35 terrain samples")
	quit()
