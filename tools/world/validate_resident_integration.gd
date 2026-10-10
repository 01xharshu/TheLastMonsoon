extends SceneTree
var failures:Array[String]=[]
var world:Node3D
var player:CharacterBody3D
var jobs:Node3D
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	if not ok:failures.append(label)
func visit(endpoint:String)->void:
	player.global_position=jobs.targets[endpoint].global_position+Vector3(0,0,1)
	await physics_frame
func run()->void:
	if "--continue" in OS.get_cmdline_user_args():
		var folder:=OS.get_environment("TLM_TEST_SAVE_ROOT")
		if folder.is_empty():push_error("Temporary save root required for Continue test");quit(2);return
		root.get_node("SaveManager").save_root=folder
	root.get_node("SaveManager").start_new_game()
	await scene_changed
	for frame in 4:await process_frame
	world=current_scene
	if world.has_node("OpeningSequence"):
		var skip:=InputEventKey.new();skip.keycode=KEY_ESCAPE;skip.pressed=true
		world.get_node("OpeningSequence")._input(skip);await process_frame;world.get_node("OpeningSequence")._input(skip)
	paused=false
	player=world.get_node("Player");player.set_physics_process(false);player.set_process_unhandled_input(false)
	world.get_node("GameTimeSystem").clock_paused=true;world.get_node("GameTimeSystem").current_hour=10
	jobs=world.get_node("ErrandSystem")
	var population:Node=world.get_node("CityRoutePopulation")
	population.eager_population=true
	for frame in 1200:
		await process_frame
		if population.ready_population and world.get_node("VillageDailyActivities").residents.size()==14:break
	check(population.pedestrians.size()==72,"72 integrated pedestrians")
	check(population.patrols.size()==10,"10 integrated police patrols")
	check(population.carts.size()==8,"8 integrated traffic carts")
	check(get_nodes_in_group("institution_post_residents").size()==5,"five added institution posts")
	check(get_nodes_in_group("draft_animals").size()==8,"eight yard animals")
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
	await visit("board");jobs.use_endpoint("board",player);check(jobs.accept("port_delivery"),"accept consignment")
	await visit("port_cargo");jobs.use_endpoint("port_cargo",player)
	check(jobs.stages.port_delivery=="accepted","remote cart cannot collect cargo")
	freight.global_position=jobs.delivery.parking_position("port_cargo");freight.rotation.y=0;freight.boarding.speed=0
	for frame in 2:await physics_frame
	jobs.use_endpoint("port_cargo",player);check(jobs.stages.port_delivery=="carrying","stopped cart loads sealed goods")
	var saved:Dictionary=jobs.export_state();jobs.restore_state(JSON.parse_string(JSON.stringify(saved)))
	check(jobs.stages.port_delivery=="carrying" and jobs.delivery.vehicle==freight,"cargo save binds actual cart")
	if "--continue" in OS.get_cmdline_user_args():
		var saver:Node=root.get_node("SaveManager")
		var saved_identity: String=str(population.pedestrians[0].name)
		population.pedestrians[0].get_node("Vitality").health=32.5
		check(saver.save_game(world,1),"real save records loaded consignment")
		check(saver.read_slot(1).get("city_route_population",{}).size()==72,"real save retains all civilian identities")
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
		check(population.pedestrians.size()==72 and world.get_node("VillageDailyActivities").residents.size()==14,"population returns through Continue")
		var restored_person:Node=population.get_node_or_null(NodePath(saved_identity))
		check(restored_person!=null and is_equal_approx(restored_person.get_node("Vitality").health,32.5),"Continue restores matching civilian identity and health")
		freight=jobs.delivery.vehicle
		check(freight!=null and jobs.stages.get("port_delivery","")=="carrying","Continue resolves deferred cargo cart")
		if freight==null:finish();return
		check(freight.visual_root.get_node_or_null("EntrustedConsignment")!=null,"Continue restores physical goods")
	freight.global_position=jobs.delivery.parking_position("office");freight.rotation.y=0;freight.boarding.speed=0
	player.global_position=freight.global_position+Vector3(3,0,-3)
	for frame in 2:await physics_frame
	check(jobs.delivery.begin("port_delivery"),"unloading begins in bay")
	check(player.inventory.get_item_count("rupees")==0,"no payment before handover")
	for frame in 3600:
		await physics_frame
		if frame%600==0:print("DELIVERY_PROGRESS ",jobs.delivery.phase," age=",jobs.delivery.age," route=",jobs.delivery.route.size()," receiver=",jobs.targets.office.person.global_position)
		if jobs.active.is_empty() or jobs.delivery.phase.is_empty():break
	check(jobs.active.is_empty() and player.inventory.get_item_count("rupees")==18,"physical unloading thanks and payment")
	print("DELIVERY_BEFORE_DUPLICATE active=",jobs.active," phase=",jobs.delivery.phase," wage=",player.inventory.get_item_count("rupees")," receiver=",jobs.targets.office.person.global_position)
	if jobs.active.is_empty():jobs._finish("port_delivery",true)
	check(player.inventory.get_item_count("rupees")==18,"no duplicate wage")
	print("DELIVERY_END_STATE ",jobs.delivery.phase," ",jobs.toast.text)
	finish()
func finish()->void:
	print("RESIDENT_WORLD_RESULT ",JSON.stringify({"passed":failures.is_empty(),"failures":failures}))
	root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)
