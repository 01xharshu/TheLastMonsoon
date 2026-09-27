extends SceneTree
func _initialize() -> void: call_deferred("validate")
func validate() -> void:
	var world = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	for i in 5: await physics_frame
	var actor = world.get_node("Player")
	for label in ["TownHall","DistrictPolice"]:
		var store = world.get_node("Settlement/"+label)
		var occupied: Array[AABB] = []
		var pickups = store.find_children("*","StaticBody3D",true,false).filter(func(n): return n.is_in_group("weapon_pickups"))
		assert(pickups.size()==3)
		for pickup in pickups:
			var bounds: AABB = store.weapon_bounds(pickup.get_child(0),store)
			assert(absf(bounds.position.y-1.115)<.002)
			assert(bounds.position.x>=store.width*.5-4.2 and bounds.end.x<=store.width*.5-1.8)
			assert(bounds.position.z>=-store.depth*.5+1 and bounds.end.z<=-store.depth*.5+6)
			for previous in occupied: assert(not bounds.intersects(previous))
			occupied.append(bounds)
			actor.global_position = store.to_global(pickup.position+Vector3(-1.8,0,0))
			await physics_frame
			var ray = PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*.2,pickup.global_position)
			ray.exclude = [actor.get_rid()]
			assert(actor.get_world_3d().direct_space_state.intersect_ray(ray).get("collider")==pickup)
		if DisplayServer.get_name()!="headless":
			actor.get_node("UI").hide()
			var camera = Camera3D.new()
			world.add_child(camera)
			camera.global_position=store.to_global(Vector3(store.width*.5-4.7,2.7,-store.depth*.5+3.5))
			camera.look_at(store.to_global(Vector3(store.width*.5-3,1,-store.depth*.5+3.5)))
			camera.current=true
			for i in 3: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/world/captures/civic_weapon_"+label+".png")
	print("CIVIC WEAPON SHELVES: PASS | six supported, contained, separated and reachable weapons")
	quit()
