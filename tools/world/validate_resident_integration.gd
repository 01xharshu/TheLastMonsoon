extends SceneTree
var failures:Array[String]=[]
var world:Node3D
var player:CharacterBody3D
var jobs:Node3D
var player_start:=Vector3.ZERO
var only_job:=""
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	if not ok:failures.append(label)
func visit(endpoint:String)->void:
	player.global_position=jobs.targets[endpoint].global_position+Vector3(0,0,1)
	await physics_frame
func run()->void:
	var arguments:=OS.get_cmdline_user_args()
	if "--only-job" in arguments:
		var index:int=arguments.find("--only-job")+1
		if index<arguments.size():only_job=arguments[index]
	if "--continue" in OS.get_cmdline_user_args():
		var folder:=OS.get_environment("TLM_TEST_SAVE_ROOT")
		if folder.is_empty():push_error("Temporary save root required for Continue test");quit(2);return
		root.get_node("SaveManager").save_root=folder
	root.get_node("SaveManager").start_new_game()
	await scene_changed
	for frame in 4:await process_frame
	world=current_scene
	if world.has_node("OpeningSequence"):
		var opening:Node=world.get_node("OpeningSequence")
		var skip:=InputEventKey.new();skip.keycode=KEY_ESCAPE;skip.pressed=true
		opening._input(skip);await process_frame;opening._input(skip)
		# Skip enters the next morning; the real wake/walk handoff must finish
		# before paid work can open. Population readiness is not that handoff.
		for frame in 1800:
			if opening.state=="done":break
			await physics_frame
		check(opening.state=="done","opening releases player before resident work")
		if opening.state!="done":finish();return
	paused=false
	# The parking-bay ending has no manually accelerated receiver. Keep the
	# populated world on its ordinary clock; only the focused worker ticks below
	# accelerate elapsed job time while retaining actual physics/collision.
	Engine.time_scale=1.0
	player=world.get_node("Player");player.set_physics_process(false);player.set_process_unhandled_input(false)
	player_start=player.global_position
	world.get_node("GameTimeSystem").clock_paused=true;world.get_node("GameTimeSystem").current_hour=10
	jobs=world.get_node("ErrandSystem")
	var population:Node=world.get_node("CityRoutePopulation")
	var expected_people:=0
	for count in population.ROUTE_COUNTS.values():expected_people+=int(count)*population.POPULATION_MULTIPLIER
	var expected_police:int=population.POLICE_ROUTES.size()*population.POPULATION_MULTIPLIER
	var expected_carts:int=population.CART_ROUTES.size()*population.POPULATION_MULTIPLIER
	population.eager_population=true
	for frame in 1200:
		await process_frame
		if population.ready_population and world.get_node("VillageDailyActivities").residents.size()==14:break
	check(population.pedestrians.size()==expected_people,"all configured integrated pedestrians")
	check(population.patrols.size()==expected_police,"all configured police patrols")
	check(population.carts.size()==expected_carts,"all configured traffic carts")
	check(get_nodes_in_group("institution_post_residents").size()==9,"nine added institution and receiving posts")
	check(get_nodes_in_group("draft_animals").size()==8,"eight yard animals")
	var independent:Node=world.get_node_or_null("CivicResidentPosts/HospitalLinenPorter/LinenDelivery")
	check(independent!=null and independent.goods.size()==3,"independent hospital worker integrated into New Journey")
	var depot_worker:Node=world.get_node_or_null("CivicResidentPosts/DepotStoresPorter/StoresDelivery")
	check(depot_worker!=null and depot_worker.goods.size()==3,"independent depot worker integrated into New Journey")
	var Roles=preload("res://world/suryagarh/settlements/resident_roles.gd")
	check(not Roles.permits("landowner","hoe") and not Roles.permits("landowner_spouse","well"),"wealthy household forbidden chores")
	for resident in world.get_node("VillageDailyActivities").residents:
		var activity:Node=resident.get_node("DailyActivity")
		check(Roles.permits(activity.social_role,activity.job),"role allows assigned job")
	var freight:Node3D
	for cart in population.carts:
		if cart.get("variant")==1 and not cart.visual_root.has_node("VillagePassengerSeat"):freight=cart;break
	check(freight!=null,"freight cart available")
	if freight==null:finish();return
	player.inventory.items.erase("rupees")
	await visit("board");jobs.use_endpoint("board",player)
	var accepted:bool=jobs.accept("port_delivery")
	check(accepted,"accept consignment")
	if not accepted:
		print("RESIDENT_JOB_SETUP source=",jobs.source," active=",jobs.active," near=",jobs._near("board")," health=",player.health," inventory_open=",player.inventory_ui.is_open()," rest=",player.get_meta("rest_action","")," paused=",paused)
		finish();return
	await visit("port_cargo");jobs.use_endpoint("port_cargo",player)
	check(jobs.stages.get("port_delivery","")=="accepted","remote cart cannot collect cargo")
	freight.global_position=jobs.delivery.parking_position("port_cargo");freight.rotation.y=0;freight.boarding.speed=0
	for frame in 2:await physics_frame
	jobs.use_endpoint("port_cargo",player);check(jobs.stages.port_delivery=="carrying","stopped cart loads sealed goods")
	var saved:Dictionary=jobs.export_state();jobs.restore_state(JSON.parse_string(JSON.stringify(saved)))
	check(jobs.stages.port_delivery=="carrying" and jobs.delivery.vehicle==freight,"cargo save binds actual cart")
	if "--continue" in OS.get_cmdline_user_args():
		var saver:Node=root.get_node("SaveManager")
		var saved_identity: String=str(population.pedestrians[0].name)
		population.pedestrians[0].get_node("Vitality").health=32.5
		if independent!=null:
			independent.set_physics_process(false)
			for frame in 500:
				if independent.phase=="inside":break
				independent.tick(.1);await physics_frame
			check(independent.phase=="inside" and independent.goods[independent.delivered].get_parent()==independent.actor,"real save taken while porter carries physical goods")
		var worker_state:Dictionary=independent.export_state() if independent!=null else {}
		if depot_worker!=null:
			depot_worker.set_physics_process(false)
			for frame in 500:
				if depot_worker.phase=="inside":break
				depot_worker.tick(.1);await physics_frame
			check(depot_worker.phase=="inside" and depot_worker.goods[depot_worker.delivered].get_parent()==depot_worker.actor,"real save taken while depot porter carries physical goods")
		var depot_state:Dictionary=depot_worker.export_state() if depot_worker!=null else {}
		if independent!=null:independent.set_physics_process(false)
		check(saver.save_game(world,1),"real save records loaded consignment")
		check(saver.read_slot(1).get("city_route_population",{}).size()==expected_people,"real save retains all civilian identities")
		if not saver.start_loaded_game(1):check(false,"Continue loads temporary slot");finish();return
		await scene_changed
		for frame in 4:await process_frame
		world=current_scene;player=world.get_node("Player");player.set_physics_process(false)
		player.set_process_unhandled_input(false);jobs=world.get_node("ErrandSystem")
		world.get_node("GameTimeSystem").clock_paused=true;world.get_node("GameTimeSystem").current_hour=10
		population=world.get_node("CityRoutePopulation")
		population.eager_population=true
		for frame in 1200:
			await process_frame
			if population.ready_population and jobs.delivery!=null and jobs.delivery.vehicle!=null:break
		check(population.pedestrians.size()==expected_people and world.get_node("VillageDailyActivities").residents.size()==14,"population returns through Continue")
		var restored_worker:Node=world.get_node_or_null("CivicResidentPosts/HospitalLinenPorter/LinenDelivery")
		check(restored_worker!=null and restored_worker.goods.size()==3,"Continue restores one hospital worker and finite consignment")
		if restored_worker!=null:
			check(restored_worker.delivered>=int(worker_state.get("delivered",0)),"Continue retains completed independent deliveries")
			if worker_state.get("phase","")=="inside" and restored_worker.delivered==int(worker_state.get("delivered",0)):
				check(restored_worker.goods[restored_worker.delivered].get_parent()==restored_worker.actor,"Continue restores actual carried hospital goods")
		var restored_depot:Node=world.get_node_or_null("CivicResidentPosts/DepotStoresPorter/StoresDelivery")
		check(restored_depot!=null and restored_depot.goods.size()==3,"Continue restores one depot worker and finite consignment")
		if restored_depot!=null:
			check(restored_depot.delivered>=int(depot_state.get("delivered",0)),"Continue retains depot deliveries")
			if depot_state.get("phase","")=="inside" and restored_depot.delivered==int(depot_state.get("delivered",0)):
				check(restored_depot.goods[restored_depot.delivered].get_parent()==restored_depot.actor,"Continue restores actual carried depot goods")
		var restored_person:Node=population.get_node_or_null(NodePath(saved_identity))
		check(restored_person!=null and is_equal_approx(restored_person.get_node("Vitality").health,32.5),"Continue restores matching civilian identity and health")
		freight=jobs.delivery.vehicle
		check(freight!=null and jobs.stages.get("port_delivery","")=="carrying","Continue resolves deferred cargo cart")
		if freight==null:finish();return
		check(freight.visual_root.get_node_or_null("EntrustedConsignment")!=null,"Continue restores physical goods")
	check(player.inventory.get_item_count("rupees")==0,"no payment before arriving in the delivery bay")
	freight.global_position=jobs.delivery.parking_position("office");freight.rotation.y=0;freight.boarding.speed=0
	player.global_position=freight.global_position+Vector3(3,0,-3)
	# The shared errand owner completes cart jobs automatically once the whole
	# stopped vehicle is inside its marked bay. Independent worker unloading
	# remains a separate visible job cycle, tested below.
	for frame in 60:
		await physics_frame
		if jobs.active.is_empty():break
	check(jobs.active.is_empty() and player.inventory.get_item_count("rupees")==18,"marked cart bay completes delivery and pays once")
	print("DELIVERY_BEFORE_DUPLICATE active=",jobs.active," phase=",jobs.delivery.phase," wage=",player.inventory.get_item_count("rupees"))
	if jobs.active.is_empty():jobs._finish("port_delivery",true)
	check(player.inventory.get_item_count("rupees")==18,"no duplicate wage")
	print("DELIVERY_END_STATE ",jobs.delivery.phase," ",jobs.toast.text)
	# The delivery test leaves Arjun beside the port doorway. Clear that real
	# obstacle before testing independent routines; blocking remains tested separately.
	player.global_position=player_start;player.force_update_transform();await physics_frame
	var hospital_work:Node=world.get_node_or_null("CivicResidentPosts/HospitalLinenPorter/LinenDelivery")
	if hospital_work!=null:
		hospital_work.set_physics_process(false)
		for frame in 600:
			if hospital_work.delivered>0:break
			hospital_work.tick(.1);await physics_frame
	check(hospital_work!=null and hospital_work.delivered>0,"hospital porter delivers past the real receiving orderly")
	var depot_work:Node=world.get_node_or_null("CivicResidentPosts/DepotStoresPorter/StoresDelivery")
	if depot_work!=null:
		depot_work.set_physics_process(false)
		for frame in 600:
			if depot_work.delivered>0:break
			depot_work.tick(.1);await physics_frame
	check(depot_work!=null and depot_work.delivered>0,"depot porter stores supplies inside the real building")
	for label in (["HospitalLinenPorter","DepotStoresPorter","CustomsReceivingPorter","MarketStockWorker","HouseholdSupplyServant"] if "--full-jobs" in OS.get_cmdline_user_args() else ["CustomsReceivingPorter","MarketStockWorker","HouseholdSupplyServant"]):
		if not only_job.is_empty() and label!=only_job:continue
		var controller:String={"HospitalLinenPorter":"LinenDelivery","DepotStoresPorter":"StoresDelivery"}.get(label,"SupplyDelivery")
		var work:Node=world.get_node_or_null("CivicResidentPosts/"+label+"/"+controller)
		check(work!=null and work.goods.size()==3,label+" integrated into main Continue")
		if work==null:continue
		work.set_physics_process(false)
		for frame in 1000:
			if work.delivered>0:break
			work.tick(.1);await physics_frame
		print("RECEIVING_WORK ",label," delivered=",work.delivered," phase=",work.phase," blocked=",work.blocked," at=",work.actor.global_position)
		check(work.delivered>0,label+" carries goods into assigned workplace")
		if "--full-jobs" in OS.get_cmdline_user_args():
			var previous_at:Vector3=work.actor.global_position;var stationary:=0.0
			for frame in 4500:
				if work.delivered==3 and work.phase=="rest":break
				work.tick(.1);await physics_frame
				stationary=stationary+.1 if Vector2(work.actor.global_position.x,work.actor.global_position.z).distance_to(Vector2(previous_at.x,previous_at.z))<.001 else 0.0
				previous_at=work.actor.global_position
				if stationary>60:
					print("RECEIVING_STALLED ",label," phase=",work.phase," waypoint=",work.waypoint," hour=",work.clock.current_hour," meta_dead=",work.actor.get_meta("dead",false)," knocked_out=",work.actor.get_meta("knocked_out",false)," navigation_pending=",work.navigation_pending," detour=",work.detour)
					var shape:CollisionShape3D=work.actor.body_collider.get_node("BodyShape")
					var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape.shape;query.transform=shape.global_transform;query.collision_mask=1;query.exclude=work.collision_excluded
					for hit in work.actor.get_world_3d().direct_space_state.intersect_shape(query,8):print("RECEIVING_OVERLAP ",hit.collider.get_path())
					break
			check(work.delivered==3 and work.phase=="rest",label+" completes all three interior deliveries")
			if work.delivered<3 or work.phase!="rest":continue
			for frame in 2500:
				if work.freight_phase=="awaiting_supply":break
				work.tick(.1);await physics_frame
			check(work.freight_phase=="awaiting_supply",label+" empty cart clears receiving bay")
			work.day=work.clock.current_day-1
			for frame in 6500:
				work.tick(.1);await physics_frame
				if work.freight_phase=="parked" and work.delivered>0:break
			print("RECEIVING_WORK_FULL ",label," delivered=",work.delivered," phase=",work.phase," freight=",work.freight_phase," blocked=",work.blocked," actor=",work.actor.global_position," cart=",work.cart.global_position," obstacle=",work.freight_obstacle)
			check(work.freight_phase=="parked" and work.delivered>0,label+" physically restocks and delivers the next consignment")
	finish()
func finish()->void:
	print("RESIDENT_WORLD_RESULT ",JSON.stringify({"passed":failures.is_empty(),"failures":failures}))
	root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)
