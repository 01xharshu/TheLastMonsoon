extends SceneTree
var failures:Array[String]=[]
var output:=OS.get_environment("TLM_WORKER_TEST_OUTPUT")
var camera:Camera3D
var pictures:Dictionary={}
var depot:bool="--depot" in OS.get_cmdline_user_args()
var site:String="port" if "--port" in OS.get_cmdline_user_args() else ("market" if "--market" in OS.get_cmdline_user_args() else ("household" if "--household" in OS.get_cmdline_user_args() else ""))
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	if not ok:failures.append(label)
func run()->void:
	var world:=Node3D.new();root.add_child(world);current_scene=world
	world.add_child(load("res://world/suryagarh/generated/landscape.scn").instantiate())
	var clock:Node=load("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock);clock.current_hour=10;clock.clock_paused=true
	var fixture:Node=load("res://tools/world/hospital_work_fixture.gd" if site.is_empty() else "res://tools/world/resident_workplace_fixture.gd").new()
	if not site.is_empty():fixture.site=site
	world.add_child(fixture)
	for frame in 3000:
		await process_frame
		if fixture.complete:break
	check(fixture.complete,"actual cantonment builder completed")
	var posts:Node=load("res://world/suryagarh/settlements/civic_resident_posts.gd").new();world.add_child(posts)
	var work:Node
	for frame in 600:
		await process_frame
		var worker_name:String={"port":"CustomsReceivingPorter","market":"MarketStockWorker","household":"HouseholdSupplyServant"}.get(site,"DepotStoresPorter" if depot else "HospitalLinenPorter")
		var porter:=posts.get_node_or_null(worker_name)
		if porter!=null:work=porter.get_node_or_null("SupplyDelivery" if not site.is_empty() else ("StoresDelivery" if depot else "LinenDelivery"))
		if work!=null and work.goods.size()==3 and work.waypoints.size()>=5:break
	check(work!=null and work.goods.size()==3,"worker and three physical consignments")
	if work==null:print("RESIDENT_GOODS_RESULT FAIL ",failures);quit(1);return
	work.set_physics_process(false)
	check(work.cart.boarding._clearance_at(work.cart.global_position),"stowed solid cargo does not block its own cart")
	await freight_sweep(work,world)
	if "--pose-budget" in OS.get_cmdline_user_args():await pose_budget(work)
	if "--pose-only" in OS.get_cmdline_user_args():
		print("RESIDENT_GOODS_RESULT ","PASS" if failures.is_empty() else "FAIL"," pose_only=true failures=",failures)
		world.queue_free();await process_frame;root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1);return
	if "--external" in OS.get_cmdline_user_args():
		work.supplier_leg=30.0 if depot else 53.0
		work.supply_bench.position.x+=work.supplier_leg
	if not output.is_empty():
		root.get_node("SaveManager").apply_options()
		var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-50,-30,0);world.add_child(sun)
		var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.65;world.add_child(environment)
		camera=Camera3D.new();world.add_child(camera);camera.current=true;camera.fov=44
		if "--normal-review" in OS.get_cmdline_user_args():
			await normal_review(work,world);return
		await photograph(work,"stock")
		var samples:Array[float]=[];var previous:=Time.get_ticks_usec()
		for frame in 180:
			await process_frame
			var now:=Time.get_ticks_usec();var seconds:=float(now-previous)/1000000;previous=now
			work.tick(minf(seconds,.1));samples.append(seconds*1000)
		var backing:=root.get_texture().get_image().get_size()
		samples.sort();print("WORKER_NATIVE_BUDGET viewport=",root.size," backing=",backing," scale=",root.scaling_3d_scale," median_ms=",samples[samples.size()/2]," p95_ms=",samples[int((samples.size()-1)*.95)])
	var obstacle:=StaticBody3D.new();world.add_child(obstacle)
	var collision:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(1.2,1.8,.25);collision.shape=box;obstacle.add_child(collision)
	var pickup:Vector3=work.institution.to_global(Vector3(work.cart_origin.x-.5,0,work.cart_origin.z+4.28))
	var approach:Vector3=pickup-work.actor.global_position;approach.y=0
	obstacle.global_position=work.actor.global_position+approach.normalized()*.5+Vector3(0,.9,0)
	obstacle.rotation.y=atan2(approach.x,approach.z)
	await physics_frame
	for frame in 40:work.tick(.05);await physics_frame
	var stopped:Vector3=work.actor.global_position
	for frame in 20:work.tick(.05);await physics_frame
	check(work.actor.global_position.distance_to(stopped)<.001 and work.delivered==0,"solid obstacle pauses work without transferring goods")
	obstacle.queue_free();await physics_frame;work.blocked=0
	var max_hand:=0.0;var saved:=false
	var freight_only:bool="--freight-only" in OS.get_cmdline_user_args()
	if freight_only:
		work.phase="rest";work.delivered=3;saved=true
		for i in 3:work.place(work.goods[i],work.institution,Vector3(.53,1.15,1+i*.55))
		work.actor.global_position=work.institution.to_global(Vector3(8,0,15.4));work.actor.body_collider.force_update_transform()
		await physics_frame
	for frame in (0 if freight_only else (6000 if site=="port" else 3600)):
		work.tick(.05);await physics_frame
		if not output.is_empty() and not pictures.has(work.phase) and work.phase in ["lift","inside","lower","return"] and (work.phase not in ["lift","lower"] or work.progress>.6):
			pictures[work.phase]=true;await photograph(work,work.phase)
		if work.hand_error>max_hand+.005:print("GOODS_CONTACT ",work.phase," ",work.progress," error=",work.hand_error)
		max_hand=maxf(max_hand,work.hand_error)
		if not saved and work.phase=="inside":
			var before:Vector3=work.actor.global_position;clock.current_hour=20;work.tick(.5)
			check(work.actor.global_position.distance_to(before)<.001 and work.goods[0].get_parent()==work.actor,"after-hours pause retains carried goods")
			clock.current_hour=10
			var state:Dictionary=JSON.parse_string(JSON.stringify(work.export_state()))
			work.restore_state(state);saved=true
			check(work.goods[0].get_parent()==work.actor,"save restores carried consignment")
			check(work.goods[0].get_node("ConsignmentBody").collision_layer==1,"carried consignment remains solid to other bodies")
		if work.phase=="rest":break
		if work.blocked>100:break
		if frame%600==0:print("GOODS_PROGRESS ",work.phase," ",work.actor.global_position," blocked=",work.blocked," grip=",max_hand)
	check(work.delivered==3 and work.phase=="rest","all three loads taken inside and worker returned")
	check(saved,"mid-carry JSON restore exercised")
	check(max_hand<.025,"palm targets within 25 mm")
	check(work.actor.body_collider.collision_layer==1,"worker body remains solid")
	for item:Node3D in work.goods:
		check(item.get_parent()==work.institution,"consignment retained inside assigned workplace")
		check(item.get_node("ConsignmentBody").collision_layer==1,"stored goods remain solid to other people")
	if not output.is_empty():await photograph(work,"stored")
	if "--restock" in OS.get_cmdline_user_args():
		var initial_cart:Vector3=work.cart.global_position
		var issue_saves:Dictionary={}
		for frame in 1800:
			work.tick(.1);await physics_frame
			if work.issue_stage in [1,2,3] and not issue_saves.has(work.issue_stage):
				var parcel:Node3D=work.parcels[work.issued]
				var parcel_at:Vector3=parcel.global_position;var facing:float=work.actor.rotation.y
				var issue_state:Dictionary=JSON.parse_string(JSON.stringify(work.export_state()))
				issue_saves[work.issue_stage]=true;work.restore_state(issue_state)
				check(parcel.global_position.distance_to(parcel_at)<.001 and absf(work.actor.rotation.y-facing)<.001,"issuing restore retains parcel and worker facing")
			if work.freight_phase=="awaiting_supply":break
		check(issue_saves.size()==3,"lift, turn and place issuing saves exercised")
		print("FREIGHT_STATE ",work.freight_phase," distance=",work.freight_distance," cart=",work.cart.global_position," worker=",work.actor.global_position," obstacle=",work.freight_obstacle)
		if work.freight_phase!="awaiting_supply":
			for shape in work.cart.boarding.clearance_shapes:
				var q:=PhysicsShapeQueryParameters3D.new();q.shape=shape.shape;q.transform=Transform3D(work.cart.global_basis,work.cart.global_position+work.cart.global_basis*shape.position);q.exclude=work.cart.boarding._vehicle_exclusions();q.collision_mask=1
				for hit in work.cart.get_world_3d().direct_space_state.intersect_shape(q,10):print("FREIGHT_HIT ",hit.collider.get_path())
		check(work.freight_phase=="awaiting_supply","empty cart reaches supplier approach")
		check(work.cart.global_position.distance_to(initial_cart)>5.5,"cart visibly departs with its draft team")
		clock.current_day+=1
		work.tick(.1);await physics_frame
		check(work.freight_phase.begins_with("loading_") and work.phase=="rest","new day starts physical supplier loading before incoming freight")
		var arrival:Vector3=work.cart.global_position
		var supply_state:Dictionary=JSON.parse_string(JSON.stringify(work.export_state()))
		work.restore_state(supply_state)
		check(work.cart.global_position.distance_to(arrival)<.001 and work.freight_phase.begins_with("loading_"),"supplier save retains cart and shipment")
		var load_saved:=false;var incoming_saved:=false;var loading_hand:=0.0
		for frame in 2400:
			work.tick(.1);await physics_frame
			if not output.is_empty() and not pictures.has(work.freight_phase) and ((work.freight_phase in ["loading_lift","loading_lower"] and work.progress>.6) or work.freight_phase=="arriving"):
				pictures[work.freight_phase]=true;await photograph(work,"freight_arriving" if work.freight_phase=="arriving" else work.freight_phase)
			if work.freight_phase in ["loading_lift","loading_carry","loading_lower"]:
				if work.hand_error>loading_hand+.005:print("SUPPLIER_HAND ",work.freight_phase," progress=",work.progress," load=",work.freight_loaded," error=",work.hand_error," feet=",work.actor.global_position)
				loading_hand=maxf(loading_hand,work.hand_error)
			if not load_saved and work.freight_phase=="loading_carry":
				var load_state:Dictionary=JSON.parse_string(JSON.stringify(work.export_state()))
				work.restore_state(load_state);load_saved=true
				check(work.goods[work.freight_loaded].get_parent()==work.actor,"supplier reload restores a carried crate")
			if not incoming_saved and work.freight_phase=="arriving":
				var incoming_state:Dictionary=JSON.parse_string(JSON.stringify(work.export_state()))
				var incoming_at:Vector3=work.cart.global_position
				work.restore_state(incoming_state);incoming_saved=true
				check(work.cart.global_position.distance_to(incoming_at)<.001,"mid-arrival save retains moving cart")
			if work.phase!="rest":break
		print("SUPPLIER_END phase=",work.freight_phase," waypoint=",work.freight_waypoint," actor=",work.actor.global_position," distance=",work.freight_distance," cart=",work.cart.global_position," obstacle=",work.freight_obstacle," issue_hand=",work.issue_hand_error)
		print("SUPPLIER_CONTACT max_hand=",loading_hand," saved_carry=",load_saved," saved_arrival=",incoming_saved)
		check(load_saved and incoming_saved,"physical loading and arrival saves both exercised")
		check(loading_hand<.025,"supplier loading palms within 25 mm")
		check(work.issue_hand_error<.025,"issuing parcel palms within 25 mm")
		check(work.phase=="collect" and work.freight_phase=="parked","incoming cart parks before worker resumes unloading")
		check(work.cart.global_position.distance_to(initial_cart)<.1,"cart returns to its assigned receiving bay")
	print("RESIDENT_GOODS_RESULT ","PASS" if failures.is_empty() else "FAIL"," workplace=",work.work_kind," delivered=",work.delivered," blocked=",work.blocked," max_hand=",max_hand," failures=",failures)
	world.queue_free();await process_frame;root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)

func photograph(work:Node,label:String)->void:
	var focus:Vector3=work.institution.to_global(Vector3(.53,1.15,1.55)) if label=="stored" else work.actor.global_position+Vector3(0,.9,0)
	if label=="freight_arriving":
		focus=work.cart.global_position+Vector3(0,1.1,2)
		camera.global_position=focus+Vector3(3,1.6,7)
	elif label in ["loading_lift","loading_lower","lift","lift_early"] or (label=="inside" and work.actor.global_position.distance_to(work.cart.global_position)<5):
		var away:Vector3=work.actor.global_position-work.cart.global_position
		away.y=0
		camera.global_position=focus+away.normalized()*3.2+work.actor.global_basis.x*1.6+Vector3.UP*.9
	else:camera.global_position=focus+work.actor.global_basis*Vector3(2.1,.7,2.4)
	camera.look_at(focus)
	await process_frame;RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(output+"/worker_"+label+".png")

func normal_review(work:Node,world:Node3D)->void:
	work.set_physics_process(true)
	var started:int=Time.get_ticks_msec();var max_hand:=0.0
	var frames:Array[float]=[];var previous:int=Time.get_ticks_usec()
	while Time.get_ticks_msec()-started<75000:
		await process_frame
		var now:int=Time.get_ticks_usec();frames.append(float(now-previous)/1000);previous=now
		max_hand=maxf(max_hand,work.hand_error)
		var focus:Vector3=work.actor.global_position+Vector3(0,.95,0)
		camera.global_position=focus+work.actor.global_basis*Vector3(2.1,.65,2.4);camera.look_at(focus)
		var label:String=work.phase
		if work.phase=="lift" and work.progress>=.175 and work.progress<=.3:label="lift_early"
		if not pictures.has(label) and (work.phase in ["inside","return"] or (work.phase in ["lift","lower"] and work.progress>=.6) or label=="lift_early"):
			pictures[label]=true;await photograph(work,label)
	check(work.delivered>0,"ordinary-speed worker completes an interior delivery")
	check(max_hand<.025,"ordinary-speed palm targets within 25 mm")
	frames.sort()
	print("RESIDENT_NORMAL_REVIEW workplace=",work.work_kind," delivered=",work.delivered," max_hand=",max_hand," seconds=",float(Time.get_ticks_msec()-started)/1000," actual3d_backing=",root.get_texture().get_image().get_size()," render_scale=",root.scaling_3d_scale," p50_ms=",frames[frames.size()/2]," p95_ms=",frames[int((frames.size()-1)*.95)]," failures=",failures)
	world.queue_free();await process_frame;root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)

func pose_budget(work:Node)->void:
	var saved:Dictionary=work.export_state()
	var before:Vector3=work.actor.global_position
	work.phase="inside";work.waypoint=2;work.delivered=0
	work.place(work.goods[0],work.actor,Vector3(0,.91,.34))
	work.retry_age=10000
	var obstacle:=StaticBody3D.new();current_scene.add_child(obstacle)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(1.2,1.8,.3);shape.shape=box;obstacle.add_child(shape)
	var towards:Vector3=work.waypoints[2]-before;towards.y=0
	obstacle.global_position=before+towards.normalized()*1.0+Vector3.UP*.9
	obstacle.rotation.y=atan2(towards.x,towards.z)
	await physics_frame
	var costs:Array[float]=[];var updates:Array[int]=[];var errors:Array[float]=[];var positions:Array[Vector3]=[]
	for mode in ["reference","batched"]:
		work.actor.global_position=before;work.actor.body_collider.force_update_transform()
		work.detour.clear();work.blocked=0;work.blocked_age=0;work.retry_age=10000;work.age=0
		var samples:Array[float]=[];var update_start:int=work.pose_updates;var error:=0.0
		for frame in 30:
			var start:int=Time.get_ticks_usec()
			if mode=="reference":
				for slice in 5:work.tick(.1)
			else:work._physics_process(.5)
			samples.append(float(Time.get_ticks_usec()-start));error=maxf(error,work.hand_error)
			await physics_frame
		samples.sort();costs.append(samples[15]);updates.append(work.pose_updates-update_start);errors.append(error);positions.append(work.actor.global_position)
	var occupancy:=PhysicsShapeQueryParameters3D.new()
	var worker_shape:CollisionShape3D=work.actor.body_collider.get_node("BodyShape")
	occupancy.shape=worker_shape.shape;occupancy.transform=worker_shape.global_transform;occupancy.collision_mask=1;occupancy.exclude=work.collision_excluded
	var crosses_obstacle:=false
	for hit in work.actor.get_world_3d().direct_space_state.intersect_shape(occupancy,32):
		if hit.collider==obstacle:crosses_obstacle=true
	var stop_difference:Vector3=positions[0]-positions[1]
	var floor_difference:float=absf(stop_difference.y);stop_difference.y=0
	check(stop_difference.length()<.001 and floor_difference<.03 and not crosses_obstacle,"remote catch-up retains physical obstacle stop")
	check(work.goods[0].get_parent()==work.actor and work.actor.body_collider.collision_layer==1,"remote catch-up retains held load and solid body")
	check(errors[1]<.025,"remote catch-up retains palm contact")
	print("RESIDENT_POSE_BUDGET median_us=",costs," pose_updates=",updates," palm_error=",errors," samples_per_mode=30")
	print("RESIDENT_POSE_STOP positions=",positions," obstacle_overlap=",crosses_obstacle)
	obstacle.queue_free();await physics_frame
	work.restore_state(saved);work.retry_age=0;work.blocked=0;work.blocked_age=0;work.age=0

func freight_sweep(work:Node,world:Node3D)->void:
	# Isolate the actual cart's query shapes from terrain/buildings for this
	# endpoint-vs-sweep regression; no floating location is used in gameplay.
	var before:Transform3D=work.cart.global_transform
	work.cart.global_position+=Vector3.UP*1000
	var barrier:=StaticBody3D.new();world.add_child(barrier)
	var shape:=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(.08,2,2);barrier.add_child(shape)
	barrier.global_position=work.cart.global_position+Vector3(6,1,0)
	await physics_frame
	var endpoint:Vector3=work.cart.global_position+Vector3.RIGHT*12
	check(work.cart.boarding._clearance_at(endpoint),"thin barrier is clear of the cart endpoint")
	check(not work.freight_clear(endpoint),"whole freight cart sweep detects a thin intervening barrier")
	work.cart.global_transform=before;barrier.queue_free();await physics_frame
	work.freight_obstacle=""
