extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	create_timer(160).timeout.connect(func():push_error("Route market world timed out");quit(2))
	root.size=Vector2i(960,540);root.content_scale_size=root.size
	var world: Node3D=load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world);current_scene=world
	var viewport:=SubViewport.new();viewport.size=Vector2i(960,540);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(viewport);root.disable_3d=true
	for frame in 1600:
		await process_frame
		if world.get_node_or_null("RouteAndMarketDetail")!=null:break
	var detail: Node3D=world.get_node_or_null("RouteAndMarketDetail")
	print("DETAIL READY ",detail)
	assert(detail!=null)
	assert(detail.stones.size()>100)
	assert(detail.prop_count>=64)
	for point: Vector3 in detail.stone_positions:
		assert(world.layout.road_distance(point.x,point.z)>5.3)
	var capsule := CapsuleShape3D.new();capsule.radius=.3;capsule.height=1.7
	var query := PhysicsShapeQueryParameters3D.new();query.shape=capsule;query.collision_mask=1
	var clearance_samples := 0
	for route_name in ["fort_trail","village_spine","village_market_lane","cantonment_bazaar_lane"]:
		var route: Array=world.layout.ROUTES[route_name]
		for segment in route.size()-1:
			var a: Vector2=route[segment];var b: Vector2=route[segment+1]
			var steps:=maxi(1,ceili(a.distance_to(b)/1.5))
			for step in steps+1:
				var p:=a.lerp(b,float(step)/steps)
				query.transform=Transform3D(Basis.IDENTITY,detail.ground(p)+Vector3.UP*.9)
				for hit in world.get_world_3d().direct_space_state.intersect_shape(query,32):
					var node: Node=hit.collider
					assert(not detail.is_ancestor_of(node))
					while node!=null:
						assert(not str(node.name).begins_with("PeriodDetail"))
						node=node.get_parent()
				clearance_samples+=1
	print("NEW DETAIL ROAD CLEARANCE PASS samples=",clearance_samples)
	var camera:=Camera3D.new();viewport.add_child(camera);camera.make_current();camera.fov=65;camera.far=450
	for path in ["Player","Player/UI","LandscapeUI"]:world.get_node(path).hide()
	world.get_node("Player").set_physics_process(false)
	var views: Array = [["mountain",Vector2(533,-170),Vector2(513,-170)],["village",Vector2(-352,224),Vector2(-339,214)],["market",Vector2(-342,272),Vector2(-336,268)],["bazaar",Vector2(643,456),Vector2(640,450)]]
	for view in views:
		camera.global_position=detail.ground(view[1])+Vector3.UP*1.8
		camera.look_at(detail.ground(view[2])+Vector3.UP*1.2)
		print("REVIEW VIEW ",view[0])
		for frame in 4:await process_frame
		if DisplayServer.get_name()!="headless":
			RenderingServer.force_draw()
			var output:=OS.get_environment("TLM_TEST_OUTPUT_DIR")
			if not output.is_empty():viewport.get_texture().get_image().save_png(output+"/"+view[0]+".png")
	print("ROUTE MARKET MAIN WORLD PASS stones=",detail.stones.size()," props=",detail.prop_count," verge clear >5.3m; four views")
	world.queue_free();await process_frame;quit()
