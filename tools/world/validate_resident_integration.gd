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
	world=load("res://world/suryagarh/suryagarh_world.tscn").instantiate();root.add_child(world);current_scene=world
	for frame in 3:await physics_frame
	if world.has_node("OpeningSequence"):
		var skip:=InputEventKey.new();skip.keycode=KEY_ESCAPE;skip.pressed=true
		world.get_node("OpeningSequence")._input(skip);await physics_frame;world.get_node("OpeningSequence")._input(skip)
	player=world.get_node("Player");player.set_physics_process(false);player.set_process_unhandled_input(false)
	world.get_node("GameTimeSystem").clock_paused=true;world.get_node("GameTimeSystem").current_hour=10
	jobs=world.get_node("ErrandSystem")
	var population:Node=world.get_node("CityRoutePopulation")
	for frame in 1200:
		await physics_frame
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
	freight.global_position=jobs.delivery.parking_position("office");freight.rotation.y=0;freight.boarding.speed=0
	player.global_position=freight.global_position+Vector3(-3,0,2)
	for frame in 2:await physics_frame
	check(jobs.delivery.begin("port_delivery"),"unloading begins in bay")
	check(player.inventory.get_item_count("rupees")==0,"no payment before handover")
	for frame in 1800:
		await physics_frame
		if jobs.active.is_empty() or jobs.delivery.phase.is_empty():break
	check(jobs.active.is_empty() and player.inventory.get_item_count("rupees")==18,"physical unloading thanks and payment")
	jobs._finish("port_delivery",true)
	check(player.inventory.get_item_count("rupees")==18,"no duplicate wage")
	print("DELIVERY_END_STATE ",jobs.delivery.phase," ",jobs.toast.text)
	finish()
func finish()->void:
	print("RESIDENT_WORLD_RESULT ",JSON.stringify({"passed":failures.is_empty(),"failures":failures}))
	world.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
