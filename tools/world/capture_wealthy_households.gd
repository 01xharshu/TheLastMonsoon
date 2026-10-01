extends SceneTree
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	var world:=load("res://world/suryagarh/suryagarh_world.tscn").instantiate() as Node3D
	root.add_child(world);current_scene=world
	world.get_node("Player").hide();world.get_node("Player").set_physics_process(false)
	world.get_node("Player/UI").hide();world.get_node("LandscapeUI").hide()
	for frame in 8:await physics_frame
	world.get_node("GameTimeSystem").clock_paused=true
	for coach in get_nodes_in_group("household_coach"):coach.get_node("HouseholdTravel").set_physics_process(false)
	for actor in get_nodes_in_group("household_staff")+get_nodes_in_group("household_resident"):actor.set_process(false)
	var camera:=Camera3D.new();world.add_child(camera);camera.fov=46;camera.make_current()
	var manager:=world.get_node("WealthyHouseholds")
	for name in ["LandownerHousehold","MerchantHousehold","BritishHousehold"]:
		var home:=manager.get_node(name) as Node3D
		camera.global_position=home.global_position+Vector3(26,17,32)
		camera.look_at(home.global_position+Vector3(0,1,0))
		await _save(name.to_snake_case()+"_home")
		var kitchen:Vector3=home.to_global(home.get_meta("kitchen_position"))
		camera.global_position=kitchen+Vector3(0,2.3,2.5)
		camera.look_at(kitchen+Vector3(0,1,-.7))
		await _save(name.to_snake_case()+"_staff")
		var worker:=manager.get_node(name+"WaterBearer") as Node3D
		camera.global_position=worker.global_position+Vector3(2,1.8,3)
		camera.look_at(worker.global_position+Vector3.UP*.9)
		await _save(name.to_snake_case()+"_water_bearer")
		var owner:Node3D
		if name=="BritishHousehold":owner=world.get_node("BritishNpcRosterCandidate/OfficialMan")
		else:owner=manager.get_node(name+("Landowner" if name=="LandownerHousehold" else "Merchant"))
		camera.global_position=owner.global_position+Vector3(1.8,1.6,2.8)
		camera.look_at(owner.global_position+Vector3.UP*.9)
		await _save(name.to_snake_case()+"_resident")
		if name!="BritishHousehold":
			camera.global_position=owner.global_position+Vector3(.45,1.6,1.05)
			camera.look_at(owner.global_position+Vector3.UP*1.48)
			await _save(name.to_snake_case()+"_face")
	var coach:=manager.get_node("BritishHouseholdCoach") as Node3D
	for frame in 1200:
		coach.get_node("HouseholdTravel").step(.1)
		await physics_frame
		if coach.get_node("HouseholdTravel").phase=="departing":break
	if coach.get_node("HouseholdTravel").phase!="departing":
		push_error("Household boarding did not finish");quit(1);return
	camera.global_position=coach.global_position+Vector3(6,4,-6)
	camera.look_at(coach.global_position+Vector3(0,1.5,1))
	await _save("household_occupied_coach")
	camera.global_position=coach.to_global(Vector3(2.8,2.8,-2))
	camera.look_at(coach.seat_world("CoachmanSeat")+Vector3.UP*.35)
	await _save("household_indian_coachman")
	var driver:Node3D=coach.get_node("HouseholdTravel").driver
	var skeleton:Skeleton3D=driver.get("_skeleton")
	print("DRIVER_POSITION ",driver.global_position," head ",skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("head")).origin))
	print("DRIVER_CONTACT ",driver.get_meta("hand_contact_l",-1)," ",driver.get_meta("hand_contact_r",-1))
	quit()
func _save(label:String) -> void:
	for frame in 4:await process_frame
	RenderingServer.force_draw(false)
	var path:="res://docs/world/captures/"+label+".png"
	print("HOUSEHOLD_CAPTURE ",path," ",root.get_texture().get_image().save_png(path))
