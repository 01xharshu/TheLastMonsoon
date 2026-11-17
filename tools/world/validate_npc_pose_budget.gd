extends SceneTree
const Startup=preload("res://systems/world_startup.gd")
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(value:bool,label:String) -> void:
	checks+=1
	assert(value,label)
func reset_driver(driver:Node) -> void:
	driver.driver_lean=.18;driver.driver_turn=0.0;driver.driving_phase=0.0
	driver._pose_elapsed=0.0;driver._clock=0.0
	driver.locomotion_blend=0.0;driver.turn_blend=0.0;driver.walk_playback_rate=1.0
	driver.animation_tree.active=false;driver.animation_tree.active=true
	await driver._process(0.0)
	driver.pose_updates=0
func pose(driver:Node) -> Array:
	var result:Array=[driver.transform]
	for bone in driver._skeleton.get_bone_count():result.append(driver._skeleton.get_bone_pose(bone))
	return result
func maximum_contact(driver:Node,cart:Node) -> float:
	var maximum:=0.0
	for side in ["l","r"]:
		maximum=maxf(maximum,driver.palm_world(side).distance_to(cart.rein_grip_world(side)))
		var rig:Skeleton3D=driver._skeleton
		var foot:=rig.find_bone("foot_"+side)
		maximum=maxf(maximum,rig.to_global(rig.get_bone_global_pose(foot).origin).distance_to(driver.foot_target_world(side)))
	return maximum
func run() -> void:
	check(OS.get_user_data_dir()==OS.get_environment("TLM_EXPECT_USER_DATA"),"Disposable userdata required")
	if "--world" in OS.get_cmdline_user_args():await world_check();return
	paused=true
	var session:=Startup.start(self)
	var world:=Node3D.new();root.add_child(world);current_scene=world
	var clock:=Node.new();clock.name="GameTimeSystem";world.add_child(clock)
	# Logical camera/control probe only; no placeholder human geometry.
	var viewer:=CharacterBody3D.new();viewer.name="Player";world.add_child(viewer)
	var camera:=Camera3D.new();world.add_child(camera);camera.make_current()
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-30,0);world.add_child(sun)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.18,.23,.28);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_energy=.6;world.add_child(env)
	for bullock in [false,true]:
		var cart:Node3D=load("res://vehicles/bullock_cart.gd" if bullock else "res://vehicles/family_carriage_candidate.gd").new()
		cart.name="PoseTestCart";world.add_child(cart)
		await process_frame
		while not session.tasks.is_empty():await process_frame
		var driver:Node=cart.visual_root.get_node("MPFBBullockDriver" if bullock else "CoachmanMakeHuman")
		check(driver.get_meta("startup_cloth_cache",false),"Exact startup clothing cache missed")
		var body_meshes:=driver.find_children("*","MeshInstance3D",true,false).size()
		var times:Array=[]
		var full_rate_poses:Array=[]
		var full_rate_pixels:Array[PackedByteArray]=[]
		for budget in [false,true]:
			driver.pose_budget_enabled=budget
			viewer.position=Vector3.ZERO;cart.position=Vector3(8,0,0);cart.rotation.y=.2
			await reset_driver(driver)
			# Nearby movement, hand/ankle contacts and rendered poses must be exact.
			for frame in 24:
				cart.position.x+=.025;cart.rotation.y+=.002
				cart.boarding.rider_acceleration=sin(float(frame))*.5
				cart.boarding.rider_turn=sin(float(frame)*.2)*.4
				await driver._process(1.0/60.0)
				if not budget:full_rate_poses.append(pose(driver))
				else:check(pose(driver)==full_rate_poses[frame],"Nearby pose changed")
				if frame in [0,12,23] and DisplayServer.get_name()!="headless":
					camera.position=driver.global_position+cart.global_basis*Vector3(2,1.3,-2);camera.look_at(driver.global_position+Vector3.UP*.45)
					for warm in 5:await process_frame
					RenderingServer.force_draw()
					var pixels:=root.get_texture().get_image().get_data()
					if not budget:full_rate_pixels.append(pixels)
					else:check(pixels==full_rate_pixels[[0,12,23].find(frame)],"Nearby native pixels changed")
			check(driver.pose_updates==24,"Nearby pose was throttled")
			cart.position=Vector3(400,0,0);cart.rotation.y=0
			cart.boarding.rider_acceleration=0;cart.boarding.rider_turn=0
			await reset_driver(driver)
			var start:=Time.get_ticks_usec();var contact:=0.0
			for frame in 600:
				cart.position.x+=.02;cart.rotation.y+=.0005
				await driver._process(1.0/60.0)
				if frame%30==0:contact=maxf(contact,maximum_contact(driver,cart))
			var usec:=Time.get_ticks_usec()-start
			check(contact<.005,"Remote cart contact separated: "+str(contact))
			check(is_equal_approx(driver.driving_phase+driver._pose_elapsed,10.0),"Elapsed animation time lost")
			check(driver.pose_updates<=21 if budget else driver.pose_updates==600,"Remote pose count wrong")
			times.append({"budget":budget,"ticks":600,"pose_updates":driver.pose_updates,"usec":usec,"maximum_contact_m":contact})
		print("NPC DRIVER A/B bullock=",bullock," ",times)
		# Medium distance tier, immediate approach, occupied and cinematic promotion.
		driver.pose_budget_enabled=true;cart.position=Vector3(120,0,0);await reset_driver(driver)
		for frame in 60:await driver._process(1.0/60.0)
		check(driver.pose_updates>=8 and driver.pose_updates<=10,"Intermediate tier not10Hz")
		cart.position=Vector3(400,0,0);await reset_driver(driver);await driver._process(.03)
		check(driver.pose_updates==0,"Remote short tick should wait")
		viewer.position=cart.position;await driver._process(1.0/60.0)
		check(driver.pose_updates==1,"Approach did not promote immediately")
		viewer.position=Vector3.ZERO;await reset_driver(driver);cart.boarding.rider=viewer;cart.boarding.role="passenger"
		for frame in 12:await driver._process(1.0/60.0)
		check(driver.pose_updates==12,"Occupied cart was throttled")
		cart.boarding.rider=null;cart.boarding.role="driver"
		viewer.set_meta("story_cinematic",true);camera.position=cart.position;await reset_driver(driver)
		for frame in 12:await driver._process(1.0/60.0)
		check(driver.pose_updates==12,"Cinematic camera was throttled")
		viewer.remove_meta("story_cinematic")
		cart.set_meta("local_driver_pose",false);await reset_driver(driver)
		for frame in 12:await driver._process(1.0/60.0)
		check(driver.pose_updates==12,"Legacy seating was throttled")
		cart.set_meta("local_driver_pose",true)
		for flag in ["mission_active","combat_action"]:
			driver.set_meta(flag,true if flag=="mission_active" else "hit");await reset_driver(driver)
			for frame in 12:await driver._process(1.0/60.0)
			check(driver.pose_updates==12,"Essential driver was throttled")
			driver.remove_meta(flag)
		check(driver.find_children("*","MeshInstance3D",true,false).size()==body_meshes,"Driver meshes changed")
		cart.hide();cart.queue_free();await process_frame
	Startup.close(session)
	print("NPC POSE BUDGET PASS checks=",checks," native=",DisplayServer.get_name()!="headless")
	root.get_node("SaveManager").quit_game()
func world_check() -> void:
	var saves:=root.get_node("SaveManager")
	saves.options.graphics_quality=1;saves.options.fullscreen=false;saves.options.vsync=false;saves.apply_options()
	var session:=Startup.start(self);paused=true
	saves.start_new_game();await scene_changed
	var world:Node3D=current_scene
	while not session.tasks.is_empty():await process_frame
	while saves.pending_slot>=0:await process_frame
	world.show();Startup.close(session);paused=false
	var opening:=world.get_node("OpeningSequence")
	var skip:=InputEventKey.new();skip.keycode=KEY_ESCAPE;skip.pressed=true
	opening._input(skip);await process_frame;opening._input(skip)
	while opening.state!="done":await process_frame
	var player:CharacterBody3D=world.get_node("Player");player.set_physics_process(false)
	var camera:=Camera3D.new();world.add_child(camera);camera.make_current()
	for location in [["village",Vector2(-310,245)],["city",Vector2(-350,-310)]]:
		var point:Vector2=location[1]
		player.global_position=Vector3(point.x,world.layout.height(point.x,point.y)+1,point.y)
		camera.position=player.global_position+Vector3.UP;camera.look_at(camera.position+Vector3(20,-1.4,-20))
		for frame in 40:await process_frame
		var drivers:Array[Node]=[]
		for node in world.find_children("*","Node3D",true,false):
			if node.get_script()!=null and node.get_script().resource_path in ["res://vehicles/seated_coachman.gd","res://vehicles/bullock_driver.gd"]:drivers.append(node)
		check(drivers.size()>=20,"Live driver population missing")
		var before:Dictionary={}
		var distant:Array[Node]=[]
		for driver in drivers:
			check(driver._pose_viewer==player,"Driver cached another world viewer")
			if driver.global_position.distance_squared_to(player.global_position)>40000 and driver.coach.boarding.rider==null:
				distant.append(driver);before[driver]=driver.pose_updates
		var frames:Array[float]=[];var tick:=Time.get_ticks_usec();var started:=tick
		for frame in 120:
			await process_frame
			var now:=Time.get_ticks_usec();frames.append((now-tick)/1000.0);tick=now
		var elapsed:=float(Time.get_ticks_usec()-started)/1000000.0
		var updates:=0
		for driver in distant:
			if not is_instance_valid(driver):continue
			updates+=driver.pose_updates-before[driver]
			check(driver.pose_updates-before[driver]<=ceili(elapsed/.5)+2,"Distant live cadence exceeded2Hz")
		frames.sort()
		print("NPC LIVE WORLD region=",location[0]," drivers=",drivers.size()," distant=",distant.size()," distant_updates=",updates," wall_seconds=",elapsed," p50/p95_ms=",[frames[60],frames[114]]," viewport=",root.size," scale=",root.scaling_3d_scale," scope=post-change native sample, no FPS attribution")
	print("NPC POSE BUDGET PASS actual-world checks=",checks)
	saves.quit_game()
