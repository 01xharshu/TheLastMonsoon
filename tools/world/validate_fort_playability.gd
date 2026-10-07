extends SceneTree
var failures := 0
func check(value: bool, label: String) -> void:
	if not value: failures += 1; push_error("FORT FAIL: "+label)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var fort: Node3D = load("res://world/ruined_fort/ruined_fort.tscn").instantiate()
	root.add_child(fort)
	var encounter := fort.get_node("Gameplay/FortEncounter")
	encounter.set_physics_process(false)
	var actor: CharacterBody3D = fort.get_node("Gameplay/Player")
	actor.set_physics_process(false)
	actor.set_process(false)
	var climb := actor.get_node("ClimbComponent")
	climb.set_physics_process(false)
	var visual := actor.get_node("VisualRoot/CharacterVisual")
	visual.set_process(false)
	actor.get_node("StairFootContact").set_process(false)
	for frame in range(4): await physics_frame
	var map: RID = fort.get_node("Navigation/FortWalkableRoutes").get_navigation_map()
	await create_timer(.3).timeout
	NavigationServer3D.map_force_update(map)
	var region: NavigationRegion3D = fort.get_node("Navigation/FortWalkableRoutes")
	print("NAV REGION enabled ",region.enabled," polygons ",region.navigation_mesh.get_polygon_count()," verts ",region.navigation_mesh.vertices.size()," first ",region.navigation_mesh.vertices[0])
	print("NAV ACTIVE ",NavigationServer3D.map_is_active(map)," closest ",NavigationServer3D.map_get_closest_point(map,Vector3(0,1,40)))
	print("NAV MAP ",NavigationServer3D.map_get_iteration_id(map)," regions ",NavigationServer3D.map_get_regions(map).size())
	var start := Vector3(0,fort.height_at(0,40),40)
	var finish := Vector3(0,fort.height_at(0,-42),-42)
	for route in [[Vector2(0,17),Vector2(-7,4),Vector2(8,-21)],[Vector2(-37,17),Vector2(-37,-14),Vector2(-30,-34)],[Vector2(35,20),Vector2(35,-6),Vector2(34,-28)]]:
		var cursor: Vector3 = start
		var total := 0.0
		for site in route+[Vector2(finish.x,finish.z)]:
			var target := Vector3(site.x,fort.height_at(site.x,site.y),site.y)
			var path := NavigationServer3D.map_get_path(map,cursor,target,true)
			check(path.size() >= 2,"flank path missing")
			if path.is_empty(): continue
			check(path[-1].distance_to(target) < 2.0,"flank goal is isolated")
			for index in range(1,path.size()): total += path[index].distance_to(path[index-1])
			cursor = path[-1]
		print("FORT ROUTE LENGTH ",total)
	# Real launch, grip transfer and mantle on the authored west wall.
	var wall := fort.get_node("Architecture/WestClimbWall")
	actor.global_position = Vector3(wall.global_position.x-1.1,fort.height_at(-35.1,-18)+.94,-18)
	actor.visual_root.global_rotation.y = PI/2
	for frame in range(12):
		actor.velocity = Vector3.DOWN
		actor.move_and_slide()
		await physics_frame
	check(actor.is_on_floor(),"climb approach has no ground")
	check(not climb.try_start(),"grounded tall catch accepted")
	actor.survival.stamina = 100
	await process_frame
	Input.action_press("jump")
	actor._handle_jump()
	print("CLIMB LAUNCH ",actor.global_position," velocity=",actor.velocity," catch=",climb.catch_seconds)
	Input.action_release("jump")
	for frame in range(40):
		actor.velocity.y -= actor.gravity/60
		actor.move_and_slide()
		climb._physics_process(1.0/60)
		visual._process(1.0/60)
		await physics_frame
		if climb.active: break
		if frame % 10 == 0: print("CLIMB AIR ",actor.global_position," launch=",climb.launch_y," facing=",actor.visual_root.global_basis.z)
	check(climb.active,"real jump did not catch authored west wall")
	if climb.active:
		for frame in range(1200):
			if climb.waiting_for_move: climb.request_move()
			climb._physics_process(1.0/60)
			visual._process(1.0/60)
			if not climb.active: break
		check(not climb.active and absf(actor.global_position.y-(float(wall.get_meta("top_y"))+.94)) < .15,"west mantle did not reach supported landing")
	# Physical low-cover entry and stance transition.
	var cover: Node3D = fort.get_node("Cover").get_child(1)
	var marker := cover.get_node("CoverPoint")
	actor.global_position = marker.global_position+Vector3.UP*.94
	actor.get_node("CameraPivot").global_rotation.y = cover.global_rotation.y+PI
	for frame in range(12):
		actor.velocity = Vector3.DOWN
		actor.move_and_slide()
		await physics_frame
	var stance := actor.get_node("StealthStance")
	check(stance.try_cover(),"cover stance failed at marked low wall")
	stance.stand()
	# Firing must respect solid architecture and finite cartridges.
	actor.global_position = Vector3(0,fort.height_at(0,48)+.94,48)
	encounter.player = actor
	encounter.activate()
	for frame in range(3): await physics_frame
	var guard: Dictionary = encounter.guards[0]
	guard.actor.global_position = Vector3(0,fort.height_at(0,42),42)
	guard.actor.body_collider.force_update_transform()
	var gun: Node3D = guard.weapon
	gun.set_process(false)
	gun.hostile = true
	gun.moving = false
	var barrier := StaticBody3D.new()
	barrier.position = Vector3(0,fort.height_at(0,45)+1.5,45)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4,3,.4)
	collision.shape = box
	barrier.add_child(collision)
	fort.add_child(barrier)
	await physics_frame
	var health: float = actor.health
	for frame in range(12): gun._process(.1)
	check(gun.shots == 0 and actor.health == health,"guard fired through masonry")
	barrier.queue_free()
	await physics_frame
	for frame in range(12): gun._process(.1)
	check(gun.shots == 1 and actor.health == health-18,"exposed player was not hit")
	check(gun.cartridges == 3 and gun.cooldown > 0,"cartridge/reload timing failed")
	print("GUARD CONTACT ",guard.actor.get_meta("hand_contact_r",1)," ",guard.actor.get_meta("hand_contact_l",1))
	for side in ["r","l"]:
		check(float(guard.actor.get_meta("hand_contact_"+side,1)) < .03,"guard hand missed weapon contact")
	print("FORT PLAYABILITY ","PASS" if failures == 0 else "FAIL"," | failures=",failures," | three routes, real jump/mantle, cover, occluded/exposed firearm")
	quit(0 if failures == 0 else 1)
