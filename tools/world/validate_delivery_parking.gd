extends SceneTree
## Real cart geometry, cargo/save ledger and no-animation parking completion.
var failures:Array[String]=[]
var world:Node3D
var jobs:Node3D
var player:CharacterBody3D
func check(ok:bool,label:String)->void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func visit(endpoint:String)->void:
	player.global_position=jobs.targets[endpoint].global_position+Vector3(0,0,1.1)
	await physics_frame
func run()->void:
	world=load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world);current_scene=world
	for frame in 30:await physics_frame
	jobs=world.get_node("ErrandSystem");player=world.get_node("Player")
	player.set_physics_process(false);jobs.delivery.set_physics_process(false)
	player.inventory.items.erase("rupees")
	var receiver:Node3D=jobs.targets.market.person
	var walk=preload("res://world/suryagarh/settlements/resident_walk_route.gd")
	var support:float=walk.support(receiver,receiver.global_position)
	var ray:=PhysicsRayQueryParameters3D.create(receiver.global_position+Vector3.UP*30,receiver.global_position-Vector3.UP*30,1,walk.floor_excluded)
	var floor_hit:=world.get_world_3d().direct_space_state.intersect_ray(ray)
	print("DELIVERY_GROUND ",{"at":str(receiver.global_position),"short":support,"layout":world.layout.height(receiver.global_position.x,receiver.global_position.z),"wide":str(floor_hit.position) if not floor_hit.is_empty() else "none","collider":str(floor_hit.collider.get_path()) if not floor_hit.is_empty() else "none"})
	var cart=load("res://vehicles/horse_cart_candidate.gd").new()
	cart.name="DeliveryParkingProbe";cart.variant=1
	world.add_child(cart);cart.add_to_group("live_travel_carts");cart.set_physics_process(false)
	for frame in 8:await physics_frame
	await visit("board");jobs.use_endpoint("board",player)
	check(jobs.accept("port_delivery"),"accept real port job")
	cart.global_position=jobs.delivery.parking_position("port_cargo");cart.boarding.speed=0
	await visit("port_cargo");jobs.use_endpoint("port_cargo",player)
	check(jobs.stages.get("port_delivery","")=="carrying" and jobs.delivery.vehicle==cart,"pickup binds entrusted cargo to actual cart")
	var saved:Dictionary=jobs.export_state();jobs.restore_state(saved)
	for frame in 3:await physics_frame
	check(jobs.delivery.vehicle==cart and is_instance_valid(jobs.delivery.goods),"carried cargo restores without wage")
	var bay:Vector3=jobs.delivery.parking_position("office")
	check(Vector2(jobs.destination().position.x-bay.x,jobs.destination().position.z-bay.z).length()<.01,"shared waypoint points to the parking rectangle")
	jobs._mark_next()
	cart.global_position=bay+Vector3(2.3,0,0)
	check(not jobs.delivery.finish_parked_cart() and player.inventory.get_item_count("rupees")==0,"root inside but cart protruding outside rectangle cannot finish")
	cart.global_position=bay;cart.rotation.y=PI/2
	check(not jobs.delivery.cart_parked(cart,"office"),"sideways cart footprint must fit whole rectangle")
	cart.rotation.y=0;cart.boarding.speed=1.0
	check(not jobs.delivery.finish_parked_cart(),"moving cart inside bay cannot finish")
	if DisplayServer.get_name()!="headless":
		jobs.delivery._physics_process(.016)
		var camera:=Camera3D.new();world.add_child(camera)
		camera.global_position=bay+Vector3(8,8,9);camera.look_at(bay+Vector3(0,.5,1));camera.current=true
		for frame in 4:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TLM_STORY_TEST_DIR").path_join("delivery_rectangle.png"))
	cart.boarding.speed=0;cart.boarding.transition="boarding"
	check(not jobs.delivery.finish_parked_cart(),"seat transition cannot finish delivery")
	cart.boarding.transition="";cart.global_position.y+=2
	check(not jobs.delivery.finish_parked_cart(),"cart above parking surface cannot finish")
	cart.global_position=bay
	jobs.delivery._physics_process(.016)
	check(jobs.active.is_empty() and player.inventory.get_item_count("rupees")==18,"stopped loaded cart completes automatically and pays exactly eighteen")
	check(not player.get_node("UI/WorldMap").waypoint.is_finite(),"completed delivery clears its own parking waypoint")
	check(jobs.delivery.phase.is_empty() and jobs.delivery.receiver==null,"no receiver or money-passing animation")
	check(not jobs.delivery.finish_parked_cart() and player.inventory.get_item_count("rupees")==18,"parking completion cannot pay twice")
	var completed:Dictionary=jobs.export_state();jobs.restore_state(completed)
	jobs.delivery._physics_process(.016)
	check(not jobs.job_available("port_delivery") and player.inventory.get_item_count("rupees")==18,"completed save retains payment guard")
	# The other cart-cargo job shares the same bay completion, not handover.
	jobs.roadside.locations.road_warehouse_crate=Vector3(-245,7.2,210)
	jobs.roadside._spawn("road_warehouse_crate")
	await visit("road_warehouse_crate_caller");jobs.source="road_warehouse_crate_caller"
	check(jobs.accept("road_warehouse_crate"),"accept roadside warehouse cargo")
	jobs.roadside.cargo_cart=cart;cart.set_meta("errand_cargo",true)
	jobs.stages.road_warehouse_crate="carrying";jobs.roadside._make_cargo("road_warehouse_crate")
	cart.global_position=jobs.delivery.parking_position("port_cargo")
	jobs.delivery._physics_process(.016)
	check(jobs.active.is_empty() and player.inventory.get_item_count("rupees")==34,"roadside loaded cart uses same rectangle and exact wage")
	print("DELIVERY PARKING: ","PASS" if failures.is_empty() else "FAIL")
	root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)
