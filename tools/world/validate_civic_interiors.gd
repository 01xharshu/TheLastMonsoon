extends SceneTree
var failed := false
func _initialize() -> void: call_deferred("run")
func check(value: bool,message: String) -> void:
	if not value:
		failed = true
		push_error(message)
func run() -> void:
	var world = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.set_physics_process(false)
	var player = world.get_node("Player")
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	for i in 6: await physics_frame
	var buildings: Array = world.find_children("TownHall","Node3D",true,false)+world.find_children("DistrictPolice","Node3D",true,false)
	check(buildings.size()==2,"Missing civic buildings")
	for building in buildings:
		player.position = building.to_global(Vector3(building.stair_x,.95,10.2))
		player.velocity = Vector3.ZERO
		for i in 370:
			player.velocity.z = -4
			player.velocity.y -= 9.8/60
			player.move_and_slide()
			await physics_frame
		var local: Vector3 = building.to_local(player.global_position)
		check(local.y>building.floor_y+.8,"Stair ascent failed: "+str(local))
		check(local.z < -9,"Stair landing not reached")
		for i in 370:
			player.velocity.z = 4
			player.velocity.y -= 9.8/60
			player.move_and_slide()
			await physics_frame
		local = building.to_local(player.global_position)
		check(local.y<1.4 and local.z>9,"Stair descent failed: "+str(local))
		# Enter through the open portal, with realistic capsule width and height.
		player.position = building.to_global(Vector3(0,.95,building.depth*.5+3))
		for i in 100:
			player.velocity = Vector3(0,player.velocity.y-9.8/60,-4)
			player.move_and_slide()
			await physics_frame
		check(building.to_local(player.position).z<building.depth*.5-2,"Entrance blocked")
		if DisplayServer.get_name() != "headless":
			player.hide()
			player.get_node("UI").hide()
			var camera := Camera3D.new()
			world.add_child(camera)
			camera.position = building.to_global(Vector3(18,13,37))
			camera.look_at(building.to_global(Vector3(0,4,0)))
			camera.make_current()
			for i in 4: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/world/captures/realism_"+building.name+"_exterior.png")
			camera.position = building.to_global(Vector3(-6,2.6,11))
			camera.look_at(building.to_global(Vector3(-7,3,-8)))
			for i in 4: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/world/captures/realism_"+building.name+"_interior.png")
			camera.queue_free()
	print("CIVIC INTERIORS ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
