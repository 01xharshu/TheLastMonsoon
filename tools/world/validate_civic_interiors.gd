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
		# Reach the upper weapons display from the same walkable upper floor.
		var supplies: Array = building.find_children("*", "Interactable", true, false)
		var acquired := 0
		for pickup in supplies:
			if not pickup.is_in_group("period_supplies"): continue
			player.global_position = pickup.global_position+Vector3(1,0,0)
			pickup.interact(player)
			acquired += 1
		check(acquired>=3,"Upper-floor sidearm, knife or lead ammunition absent")
		# Enter through the open portal, with realistic capsule width and height.
		player.position = building.to_global(Vector3(0,.95,building.depth*.5+3))
		for i in 100:
			player.velocity = Vector3(0,player.velocity.y-9.8/60,-4)
			player.move_and_slide()
			await physics_frame
		check(building.to_local(player.position).z<building.depth*.5-2,"Entrance blocked")
		check(player.inventory.has_item("pistol") and player.inventory.has_item("utility_knife") and player.inventory.has_item("paper_cartridges"),"Period display items could not be collected")
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
	var gear = player.get_node("VisualRoot/CharacterVisual").equipment
	check(gear.owns(3) and gear.owns(4),"Revolver and knife were not unlocked by pickups")
	gear.selected = 4
	gear.stowed = false
	gear._refresh()
	check(gear.knife_hand.visible and not gear.knife_hip.visible,"Knife did not draw into the hand")
	player.position = Vector3(-230,40,180)
	player.get_node("CameraPivot/SpringArm3D").collision_mask = 0
	var view: Camera3D = player.get_node("CameraPivot/SpringArm3D/Camera3D")
	var dummy := StaticBody3D.new()
	dummy.set_script(load("res://tools/weapons/damage_dummy.gd"))
	world.add_child(dummy)
	dummy.global_position = view.global_position-view.global_basis.z*1.0
	var shape := SphereShape3D.new()
	shape.radius = .28
	var collider := CollisionShape3D.new()
	collider.shape = shape
	dummy.add_child(collider)
	for i in 3: await physics_frame
	dummy.global_position = view.global_position-view.global_basis.z*1.0
	for i in 2: await physics_frame
	var strike = player.get_node("KnifeStrike")
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	var probe := PhysicsRayQueryParameters3D.create(view.global_position,view.global_position-view.global_basis.z*1.45)
	probe.exclude = [player.get_rid()]
	strike._unhandled_input(event)
	check(dummy.damage_received >= 18.0,"Utility knife did not strike a reachable target")
	print("CIVIC INTERIORS ","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
