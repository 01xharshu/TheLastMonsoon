extends SceneTree
## Saved city vehicles may be created after SaveManager.apply_pending.
const States = preload("res://vehicles/cart_save_state.gd")
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _run() -> void:
	var saves := root.get_node("SaveManager")
	saves.pending_slot = -1
	if "--integrated" in OS.get_cmdline_user_args():
		await integrated(saves)
	else:
		await delayed_spawn()
	print("CART CONTINUE ",JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","failures":failures}))
	await saves.quit_game(0 if failures.is_empty() else 1)

func delayed_spawn() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var clock := preload("res://world/suryagarh/systems/game_time_system.gd").new()
	clock.name = "GameTimeSystem"
	world.add_child(clock)
	var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
	actor.name = "Player"
	world.add_child(actor)
	actor.set_physics_process(false)
	var population := preload("res://world/suryagarh/city_route_population.gd").new()
	population.process_mode=Node.PROCESS_MODE_DISABLED
	world.add_child(population)
	var required := "CityRoutePopulation/CityCart_civil_lines_avenue"
	States.restore(world,[{"path":required,"position":[-280,8,-440],"seat":"RearPassengerRight"}])
	for frame in 2: await process_frame
	population.set_process(false)
	check(population.prepared and population.pending.size()==224,"Pre-prepare priority lost population records")
	check(population.pending[0].kind=="cart" and population.pending[0].route=="civil_lines_avenue","Occupied saved cart was not prioritised before prepare")
	population.set_saved_cart_priority("")
	var normal_order: Array=population.pending.duplicate(true)
	var required_index := -1
	for i in normal_order.size():
		if normal_order[i].kind=="cart" and normal_order[i].route=="civil_lines_avenue":required_index=i
	States.restore(world,[{"path":required,"position":[-280,8,-440],"seat":"RearPassengerRight"}])
	var others: Array=population.pending.duplicate(true)
	others.remove_at(0)
	var expected_others: Array=normal_order.duplicate(true)
	expected_others.remove_at(required_index)
	check(others==expected_others,"Priority changed unrelated spawn order/counts")
	States.restore(world,[{"path":"CityRoutePopulation/CityCart_port_approach","position":[0,0,0],"seat":"RearPassengerRight"}])
	check(population.pending[0].route=="port_approach" and population.pending.size()==224,"Replacement retained stale cart priority")
	States.restore(world,[{"path":required,"position":[-280,8,-440]}])
	check(population.pending==normal_order,"Unoccupied save changed queue order or failed to cancel priority")
	check(not population.set_saved_cart_priority("CityRoutePopulation/UnknownCart") and population.pending==normal_order,"Unknown saved path changed spawn queue")
	print("CART CONTINUE PRIORITY ",JSON.stringify({"records":population.pending.size(),"required_cart_previous_index":required_index,"required_cart_priority_index":0,"others_unchanged":others==expected_others}))
	check(population.set_saved_cart_priority("CityRoutePopulation/CityCart_civil_lines_avenue_11") and int(population.pending[0].index)==11, "Doubled cart path priority missing")
	population.set_saved_cart_priority("")
	population.process_mode=Node.PROCESS_MODE_INHERIT
	population.pending.clear()
	var path := "CityRoutePopulation/CityCart_civil_lines_avenue"
	var expected := Vector3(-280,8,-440)
	# Current mounted carts require physical ground through the boarding transition.
	var floor := StaticBody3D.new()
	var support := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(40, 1, 40)
	support.shape = floor_shape
	floor.add_child(support)
	world.add_child(floor)
	floor.global_position = expected - Vector3.UP * .5
	await physics_frame
	actor.global_position = expected + Vector3(1,1,0)
	actor.inventory.add_item("rupees",6)
	actor.set_physics_process(true)
	var previous_input := actor.is_processing_unhandled_input()
	actor.velocity = Vector3(7,0,0)
	States.restore(world,[{"path":path,"position":[expected.x,expected.y,expected.z],"heading":.37,"seat":"RearPassengerRight","role":"passenger","paid_destination":"Police Station"}])
	var held_position := actor.global_position
	check(not actor.is_physics_processing() and not actor.is_processing_unhandled_input() and actor.velocity==Vector3.ZERO,"Pending occupied cart did not hold existing player controls")
	Input.action_press("move_forward")
	var pending_node: Node=world.get_node("PendingCityCartRestore")
	var before_checks: int=pending_node.checked_records
	for frame in 300: await process_frame
	Input.action_release("move_forward")
	check(actor.global_position.distance_to(held_position)<.001,"Player left boarding range while saved cart was pending")
	check(not pending_node.is_processing() and pending_node.checked_records==before_checks,"Pending restore polled unchanged population across300frames")
	print("CART CONTINUE HANDOFF ",JSON.stringify({"idle_frames":300,"before_polling_checks_min":300,"after_idle_checks":pending_node.checked_records-before_checks,"pending_records":pending_node.states.size()}))
	var resaved := States.collect(world)
	check(resaved.size()==1 and resaved[0].path==path and resaved[0].position==[expected.x,expected.y,expected.z],"Quick re-save discarded pending city-cart state")
	population.spawn_record({"kind":"cart","route":"civil_lines_avenue","index":3,"count":2})
	var cart: Node3D = world.get_node(path)
	check(cart.global_position.distance_to(expected)<.001 and cart.boarding.rider==actor,"Spawn handoff did not restore state before firstcarttick")
	check(actor.is_physics_processing() and actor.is_processing_unhandled_input()==previous_input and actor.get_meta("mounted_vehicle")==cart.boarding,"Boarding did not release controls to existing mounted ownership")
	check(cart.boarding.is_physics_processing(),"Control handoff disabled mounted physics")
	cart.get_node("CityRoadJourney").set_physics_process(false)
	for frame in 3: await process_frame
	check(cart.global_position.distance_to(expected)<.001,"Saved city cart position was discarded before asynchronous spawn")
	check(is_equal_approx(cart.rotation.y,.37),"Saved city cart heading was discarded before asynchronous spawn")
	check(States.collect(world).size()==1,"Resolved pending record duplicated live cart in re-save")
	var boarding_save: Array=States.collect(world)
	check(boarding_save[0].get("paid_destination","")=="Police Station","Quick re-save during boarding lost paid destination")
	States.restore(world,boarding_save)
	check(States.collect(world)[0].get("paid_destination","")=="Police Station","Replacement while boarding lost paid destination")
	paused = true
	await create_timer(1.7).timeout
	check(actor.inventory.get_item_count("rupees")==6 and cart.boarding.travel.payer==null,"Pausing restored boarding refunded an already-paid journey")
	paused = false
	await create_timer(1.7).timeout
	check(cart.boarding.rider==actor and cart.boarding.travel.payer==actor and cart.boarding.travel.destination=="Police Station","Delayed paid restore did not survive pending-node retirement")
	check(actor.inventory.get_item_count("rupees")==6,"Delayed paid restore charged or refunded the saved fare")
	States.restore(world,States.collect(world))
	check(actor.inventory.get_item_count("rupees")==6 and cart.boarding.travel.destination=="Police Station", "Already-running paid restore duplicated fare/refund")
	population.ready_population = true
	for frame in 2: await process_frame
	check(not world.has_node("PendingCityCartRestore"),"Completed restore retained a polling node")
	population.ready_population = false
	States.restore(world,[{"path":"CityRoutePopulation/UnknownCart","position":[0,0,0]}])
	check(world.has_node("PendingCityCartRestore"),"Missing city record did not queue")
	# A second restore replaces the old pending work, without double application.
	States.restore(world,[{"path":"CityRoutePopulation/OtherMissingCart","position":[0,0,0]}])
	check(world.get_node("PendingCityCartRestore").states.size()==1,"Repeated restore duplicated pending records")
	population.ready_population = true
	for frame in 3: await process_frame
	check(not world.has_node("PendingCityCartRestore"),"Unknown cart record polled after population completion")
	# Known occupied records must release controls even if the population finishes
	# without that cart, and preserve callers that already disabled physics.
	population.ready_population = false
	States.restore(world,[{"path":"CityRoutePopulation/CityCart_port_approach","seat":"RearPassengerRight","position":[0,0,0]}])
	check(not actor.is_physics_processing(),"Second occupied pending record did not hold controls")
	States.restore(world,[])
	check(actor.is_physics_processing() and actor.is_processing_unhandled_input()==previous_input,"Replacement failed to release held controls")
	actor.set_physics_process(false)
	States.restore(world,[{"path":"CityRoutePopulation/CityCart_port_approach","seat":"RearPassengerRight","position":[0,0,0]}])
	population.ready_population = true
	for frame in 2: await process_frame
	check(not actor.is_physics_processing() and actor.is_processing_unhandled_input()==previous_input,"Expiry overwrote previous control flags")
	population.ready_population = false
	States.restore(world,[{"path":"CityRoutePopulation/NeverSpawned","position":[0,0,0]}])
	var pending_ref: WeakRef = weakref(world.get_node("PendingCityCartRestore"))
	world.queue_free()
	for frame in 3: await process_frame
	check(pending_ref.get_ref()==null,"Pending restoration survived scene deletion")

func integrated(saves: Node) -> void:
	saves.save_root = OS.get_environment("TLM_CART_CONTINUE_SAVE_ROOT")
	if not saves.save_root.is_absolute_path() or not saves.save_root.get_base_dir().get_file().begins_with("tlm-cart-continue-"):
		check(false,"Runner-owned temporary save root required");return
	if saves.save_root.is_empty(): check(false,"Temporary save directory required");return
	saves.options.graphics_quality = 1
	saves.options.fullscreen = false
	saves.apply_options()
	root.unresizable = true
	root.size = Vector2i(1280,720)
	var world: Node3D = load(saves.WORLD).instantiate()
	root.add_child(world);current_scene = world
	await populated(world)
	print("CART CONTINUE initial population ready")
	var actor: CharacterBody3D = world.get_node("Player")
	actor.set_physics_process(false)
	var cart: Node3D = world.get_node("CityRoutePopulation/CityCart_civil_lines_avenue")
	cart.get_node("CityRoadJourney").set_physics_process(false)
	actor.global_position = cart.seat_sockets["RearPassengerRight"].global_position + Vector3.RIGHT
	actor.inventory.add_item("rupees",8)
	var boarded: bool = cart.board_at(actor,"RearPassengerRight","passenger")
	check(boarded,"Could not board saved city carriage")
	if not boarded: return
	await create_timer(cart.boarding.TRANSITION_SECONDS+.2).timeout
	var booked: bool = cart.boarding.travel.request_trip("Police Station")
	check(booked,"Could not book saved paid journey")
	if not booked: return
	var money: int = actor.inventory.get_item_count("rupees")
	var written: bool = saves.save_game(world,2)
	check(written,"Could not write temporary occupied save: "+saves.last_error)
	if not written: return
	var saved: Dictionary = saves.read_slot(2)
	var saved_cart: Dictionary = {}
	for record: Dictionary in saved.cart_states:
		if record.path=="CityRoutePopulation/CityCart_civil_lines_avenue": saved_cart=record
	check(saved_cart.get("paid_destination","")=="Police Station","Occupied save omitted its paid destination")
	print("CART CONTINUE saved cart ",JSON.stringify(saved_cart))
	var previous_id := world.get_instance_id()
	print("CART CONTINUE occupied paid save ready")
	var started: bool = saves.start_loaded_game(2)
	check(started,"Fresh Continue rejected saved slot")
	if not started: return
	var change_started := Time.get_ticks_msec()
	while (current_scene == null or current_scene.get_instance_id()==previous_id) and Time.get_ticks_msec()-change_started<30000: await process_frame
	if current_scene == null or current_scene.get_instance_id()==previous_id:
		check(false,"Fresh world did not replace previous scene");return
	world = current_scene
	var began := Time.get_ticks_msec()
	while not world.has_node("CityRoutePopulation/CityCart_civil_lines_avenue") and Time.get_ticks_msec()-began<180000: await process_frame
	if not world.has_node("CityRoutePopulation/CityCart_civil_lines_avenue"):
		check(false,"Saved carriage did not spawn in fresh world");return
	actor = world.get_node("Player")
	cart = world.get_node("CityRoutePopulation/CityCart_civil_lines_avenue")
	# Cold population work can consume wall time without completing boarding ticks.
	# Never freeze a transition solely because five wall-clock seconds elapsed.
	for tick in 300:
		if cart.boarding.travel.payer != null: break
		await physics_frame
	print("CART CONTINUE resume probe ",JSON.stringify({"rider":cart.boarding.rider==actor,"transition":cart.boarding.transition,"progress":cart.boarding.transition_progress,"payer":cart.boarding.travel.payer==actor,"destination":cart.boarding.travel.destination,"actual_money":actor.inventory.get_item_count("rupees")}))
	if cart.boarding.transition=="": cart.boarding.set_physics_process(false)
	cart.get_node("CityRoadJourney").set_physics_process(false)
	check(cart.boarding.rider == actor,"Fresh Continue lost occupied city-cart seat")
	check(cart.boarding.seat_name == "RearPassengerRight" and cart.boarding.role == "passenger","Fresh Continue changed seat or role")
	check(cart.boarding.travel.payer == actor and cart.boarding.travel.destination == "Police Station","Fresh Continue lost already-paid city-cart destination")
	check(actor.inventory.get_item_count("rupees")==money,"Fresh Continue charged or refunded the saved journey")
	check(saved.cart_states.size()>0,"Save omitted cart state records")
	await populated(world)
	check(cart.boarding.travel.payer==actor and actor.inventory.get_item_count("rupees")==money,"Restored paid trip changed while remaining population loaded")
	print("CART CONTINUE fresh world ",JSON.stringify({"fresh_world":world.get_instance_id()!=previous_id,"money":money,"seat":cart.boarding.seat_name,"destination":cart.boarding.travel.destination,"population_ready":world.get_node("CityRoutePopulation").ready_population}))

func populated(world: Node3D) -> void:
	var population: Node = world.get_node("CityRoutePopulation")
	var start := Time.get_ticks_msec()
	while not population.ready_population and Time.get_ticks_msec()-start<180000: await process_frame
	check(population.ready_population,"City population did not finish within180seconds")
