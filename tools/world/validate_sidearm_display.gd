extends SceneTree
var failures: Array[String] = []
func _initialize(): call_deferred("run")
func check(ok: bool,label: String):
	if not ok: failures.append(label)
func run():
	var world=load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	var actor=world.get_node("Player")
	for i in 5: await physics_frame
	for label in ["TownHall","DistrictPolice"]:
		var store=world.get_node("Settlement/"+label)
		var boxes: Array[AABB] = []
		for id in ["pistol","utility_knife","paper_cartridges"]:
			var pickup=store.get_node("SidearmSupply_"+id)
			var bounds: AABB=store.weapon_bounds(pickup.get_child(0),store)
			check(absf(bounds.position.y-store.floor_y-.925)<.002,label+" "+id+" support")
			check(bounds.position.x>-1 and bounds.end.x<7 and bounds.position.z>3.25 and bounds.end.z<4.75,label+" "+id+" containment")
			for box in boxes: check(not box.intersects(bounds),label+" overlapping supplies")
			boxes.append(bounds)
			var origin=store.to_global(Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z))
			var ray=PhysicsRayQueryParameters3D.create(origin,origin-Vector3.UP*.1)
			ray.exclude=[pickup.get_rid(),actor.get_rid()]
			var hit=actor.get_world_3d().direct_space_state.intersect_ray(ray)
			check(not hit.is_empty(),label+" "+id+" physical table")
			if not hit.is_empty(): check(absf(store.to_local(hit.position).y-store.floor_y-.91)<.002,label+" tabletop height")
			actor.global_position=store.to_global(Vector3(pickup.position.x,store.floor_y+.95,6))
			await physics_frame
			ray=PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*.4,pickup.global_position)
			ray.exclude=[actor.get_rid()]
			check(actor.get_world_3d().direct_space_state.intersect_ray(ray).get("collider")==pickup,label+" "+id+" reachable")
		if DisplayServer.get_name()!="headless" and label == ("DistrictPolice" if "--police" in OS.get_cmdline_user_args() else "TownHall"):
			actor.get_node("UI").hide()
			var camera=Camera3D.new()
			world.add_child(camera)
			camera.global_position=store.to_global(Vector3(4.6,store.floor_y+2.5,6.4))
			camera.look_at(store.to_global(Vector3(4.75,store.floor_y+.95,4)))
			camera.current=true
			for i in 3: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/world/captures/sidearm_table_"+label+".png")
	print("SIDEARM TABLE ","PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
