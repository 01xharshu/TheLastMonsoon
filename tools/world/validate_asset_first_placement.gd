extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for frame in 6: await physics_frame
	world.get_node("Player").set_physics_process(false)
	var report := {"placements":[],"limits":"Support and final 0.8 m capsule approach strip; not full walking routes, animation or final art approval"}
	var failures: Array[String] = []
	var bodies: Array[RID] = []
	var props := get_nodes_in_group("asset_first_placed")
	for prop in props:
		if prop is CollisionObject3D: bodies.append(prop.get_rid())
		for body in prop.find_children("*","CollisionObject3D",true,false): bodies.append(body.get_rid())
	for prop in props:
		if prop.name in ["SharedBandageVisual","CourtyardRoti","SpareWaterPouch"]: continue
		var origin: Vector3 = prop.global_position
		var ray := PhysicsRayQueryParameters3D.create(origin+Vector3.UP*.15,origin-Vector3.UP*2)
		ray.exclude = bodies
		var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
		var expected: float = .4 if "WaterSource" in str(prop.name) else 0
		var gap: float = origin.y-expected-hit.position.y if not hit.is_empty() else INF
		if absf(gap) > .07: failures.append(str(prop.name)+" support gap "+str(gap))
		report.placements.append({"name":str(prop.name),"position":str(origin),"support_gap_m":gap})
		var approach := prop.get_node_or_null("Approach") as Node3D
		if approach == null: approach = prop.get_node_or_null("CookApproach") as Node3D
		if approach == null: approach = prop.get_node_or_null("StandingApproach") as Node3D
		if approach != null:
			var shape := CapsuleShape3D.new()
			shape.radius = .3
			shape.height = 1.7
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = shape
			query.transform.origin = approach.global_position+Vector3.UP*.94
			query.exclude = [world.get_node("Player").get_rid()]
			var overlaps := world.get_world_3d().direct_space_state.intersect_shape(query)
			if not overlaps.is_empty(): failures.append(str(prop.name)+" approach overlaps "+str(overlaps[0].collider.get_path()))
			for sample in 6:
				var foot := approach.global_position+approach.global_basis*Vector3(0,0,float(sample)*.16)
				var ground_ray := PhysicsRayQueryParameters3D.create(foot+Vector3.UP*.35,foot-Vector3.UP)
				ground_ray.exclude = bodies
				var support := world.get_world_3d().direct_space_state.intersect_ray(ground_ray)
				if not support.is_empty(): foot.y = support.position.y
				query.transform.origin = foot+Vector3.UP*.94
				var route_hits := world.get_world_3d().direct_space_state.intersect_shape(query)
				if not route_hits.is_empty():
					failures.append(str(prop.name)+" final approach strip blocked: "+str(route_hits[0].collider.get_path()))
					break

	if DisplayServer.get_name() != "headless":
		root.size = Vector2i(1440,900)
		root.content_scale_size = root.size
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.make_current()
		camera.fov = 60
		for label in ["ArjunRestDressing","CourtyardCooking","TownRecordsDesk","GrainStoreCounter","ArmourySupplyShelf","StoreOpenGate","StoresBarricade","IndoorWaterSource","SpareWaterPouch","CourtyardRoti"]:
			var prop: Node3D = world.find_child(label,true,false)
			var offset := Vector3(.5,.45,.65) if label in ["SpareWaterPouch","CourtyardRoti"] else Vector3(2.4,1.8,3.3)
			if label == "IndoorWaterSource": offset = Vector3(.8,.7,1.2)
			camera.global_position = prop.global_position+prop.global_basis*offset
			camera.look_at(prop.global_position+Vector3.UP*(.05 if label in ["SpareWaterPouch","CourtyardRoti"] else .45))
			for frame in 8: await process_frame
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("res://docs/assets/placed_"+label.to_snake_case()+".png")
	var saves := root.get_node("SaveManager")
	saves.save_root = "user://asset_first_placement_validation"
	assert(saves.save_game(world,1))
	assert(saves.read_slot(1).remaining_household_ids.size()==2)
	# New pickup transactions, no duplicate grants; no save-slot writes.
	var actor: Node3D = world.get_node("Player")
	var inventory = actor.get_node("InventoryComponent")
	for label in ["CourtyardRoti","SpareWaterPouch"]:
		var pickup: Node3D = world.find_child(label,true,false)
		var id: String = pickup.item_id
		var before: int = inventory.items.get(id,0)
		pickup.interact(actor)
		pickup.interact(actor)
		assert(inventory.items.get(id,0)==before+1,"Duplicate pickup reward")
	assert(root.get_node("SaveManager")._remaining_household_ids(world).is_empty())
	assert(saves.save_game(world,1))
	assert(saves.read_slot(1).remaining_household_ids.is_empty())
	root.get_node("SaveManager").restore_household_pickups(world,{})
	root.get_node("SaveManager").restore_household_pickups(world,{"remaining_household_ids":[]})
	for id in ["restore_roti","restore_pouch"]:
		var restored: Node3D = load("res://objects/roti.tscn" if id == "restore_roti" else "res://objects/water_bag.tscn").instantiate()
		restored.set_meta("pickup_id",id)
		restored.add_to_group("household_pickups")
		world.add_child(restored)
	root.get_node("SaveManager").restore_household_pickups(world,{})
	assert(root.get_node("SaveManager")._remaining_household_ids(world).size()==2,"Old save keeps new pickups")
	root.get_node("SaveManager").restore_household_pickups(world,{"remaining_household_ids":[]})
	assert(root.get_node("SaveManager")._remaining_household_ids(world).is_empty(),"Collected items removed from rebuilt world")
	var pot: Node3D = world.find_child("IndoorWaterSource",true,false)
	inventory.consume_water(2)
	pot.interact(actor)
	assert(inventory.get_stored_water_liters() == inventory.get_total_water_capacity_liters())
	report["transactions"] = "PASS: two pickups once; persistence list excludes queued pickups; legacy field accepted; indoor water fills"
	report["failures"] = failures
	var suffix := "headless" if DisplayServer.get_name()=="headless" else "metal"
	var file := FileAccess.open("res://docs/assets/placement_validation_"+suffix+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("PLACEMENT ","PASS" if failures.is_empty() else "FAIL",": ",failures)
	quit(0 if failures.is_empty() else 1)
