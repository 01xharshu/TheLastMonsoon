extends SceneTree
const Trace = preload("res://combat/ballistic_trace.gd")
var failures: Array[String] = []
func check(condition: bool, label: String) -> void:
	if not condition: failures.append(label); push_error(label)
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	root.size=Vector2i(1280,720);root.content_scale_size=root.size
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	create_timer(150).timeout.connect(func(): push_error("CART COMBAT WORLD WATCHDOG");quit(2))
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world);current_scene=world
	var player: CharacterBody3D=world.get_node("Player")
	player.set_physics_process(false);player.hide();player.get_node("UI").hide()
	world.get_node("LandscapeUI").hide()
	for frame in 8:await physics_frame
	var coaches:=get_nodes_in_group("household_coach")
	for coach in coaches:coach.get_node("HouseholdTravel").set_physics_process(false)
	var coach: Node3D=world.get_node("WealthyHouseholds/BritishHouseholdCoach")
	var travel: Node=coach.get_node("HouseholdTravel")
	# Place real authored residents through the live seat solver.
	for journey in travel.journeys:
		journey.change("seated")
		journey.actor.get_node("BodyCollider/BodyShape").disabled=true
		travel._seat(journey.actor,journey.seat_name,.016)
	travel._seat(travel.driver,"CoachmanSeat",.016)
	for frame in 4:await physics_frame
	var passenger: Node3D=travel.residents[0]
	var vitality: Node=passenger.get_node("Vitality")
	var camera:=Camera3D.new();world.add_child(camera);camera.fov=46;camera.make_current()
	camera.global_position=coach.to_global(Vector3(-5,3.2,5.5))
	camera.look_at(coach.to_global(Vector3(0,1.5,1)))
	await _save("cart_combat_alive")
	var target: Vector3=vitality.hit_body.get_child(1).global_position
	var origin: Vector3=coach.to_global(Vector3(-4,2.39,2.75))
	var end: Vector3=target+(target-origin).normalized()*.1
	var old_health: float=vitality.health
	var space:=world.get_world_3d().direct_space_state
	var hit:=Trace.shoot(space,self,origin,end,60.0,[])
	print("PASSENGER HIT ",str(hit.get("collider"))," target=",target," health=",vitality.health," panes=",coach.combat.panes.map(func(p):return p.broken))
	check(not hit.is_empty() and hit.collider.has_method("take_damage") and hit.collider.damage_receiver==vitality,"outside shot hits real British passenger")
	check(coach.combat.panes.any(func(p):return p.broken),"real coach pane breaks")
	check(vitality.health<old_health,"real passenger loses health")
	Trace.shoot(space,self,origin,end,60.0,[])
	check(vitality.dead,"real passenger dies")
	var corpse_at: Vector3=passenger.global_position
	travel._seat(passenger,"RearPassengerLeft",.1)
	check(passenger.global_position.distance_to(corpse_at)<.0001,"seat solver does not revive or reposition corpse")
	await create_timer(1).timeout
	await _save("cart_combat_passenger_dead")
	var driver_vitality: Node=travel.driver.get_node("Vitality")
	var driver_target: Vector3=driver_vitality.hit_body.get_child(0).global_position
	var driver_origin: Vector3=driver_target-coach.global_basis.z*4
	Trace.shoot(space,self,driver_origin,driver_target+(driver_target-driver_origin).normalized()*.1,100.0,[])
	check(driver_vitality.dead,"exposed coachman dies from outside shot")
	var stopped: Transform3D=coach.global_transform
	travel.phase="departing"
	for frame in 60:travel.step(.016)
	check(coach.global_transform.is_equal_approx(stopped),"driver death stops autonomous coach")
	var horse: Node=coach.combat.horses[0]
	var horse_centre: Vector3=horse.hit_body.get_child(0).global_position
	var horse_origin: Vector3=horse_centre-coach.global_basis.z*5
	Trace.shoot(space,self,horse_origin,horse_centre,60,[])
	Trace.shoot(space,self,horse_origin,horse_centre,60,[])
	check(horse.dead,"draft horse dies from ray hits")
	check(not coach.can_move(),"dead draft horse blocks coach movement")
	await create_timer(1.5).timeout
	await _save("cart_combat_horse_dead")
	var house := world.find_child("BhairavpurHouse0",true,false) as Node3D
	if house != null and DisplayServer.get_name() != "headless":
		player.global_position = house.to_global(Vector3(0,5.4,0))
		player.get_node("CameraPivot").look_at(house.global_position+Vector3(60,0,25))
		var scope: Node = player.get_node("FieldTelescope")
		scope.set_process(false)
		scope.set_active(true)
		scope.zoom_by(-100)
		await _save("telescope_village_2x")
		scope.zoom_by(100)
		await _save("telescope_village_12x")
		scope.set_active(false)
	var report:={"passed":failures.is_empty(),"failures":failures,"scope":"real British coach/passenger/driver/horse ray damage and autonomous stop; procedural death poses and full play remain review"}
	FileAccess.open("res://docs/world/cart_combat_world_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("CART COMBAT WORLD: ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
func _save(label:String) -> void:
	if DisplayServer.get_name()=="headless":return
	for frame in 3:await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://docs/world/captures/"+label+".png")
