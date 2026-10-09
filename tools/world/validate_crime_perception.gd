extends SceneTree
## Physics probes have no human meshes; they isolate sight/reporting behavior.
class Inventory extends RefCounted:
	signal message_requested(value: String)
class TestPlayer extends CharacterBody3D:
	var inventory := Inventory.new()
	var health := 100.0
class Stance extends Node:
	var height := 1.4
	func sight_target() -> Vector3: return get_parent().global_position+Vector3.UP*height
	func visible_range(_observer: Vector3, distance: float) -> float: return distance
class Probe extends Node3D:
	var body_collider := AnimatableBody3D.new()
	var movement_enabled := true
	var travel_speed := 0.0
	var _home := Vector3.ZERO
	func _ready() -> void:
		body_collider.collision_layer=8
		add_child(body_collider)
class Coordinator extends Node:
	var phase := "idle"
var failures: Array[String] = []
var count := 0
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	count+=1
	print(("PASS " if value else "FAIL ")+label)
	if not value:failures.append(label)
func sync() -> void:
	await physics_frame
	await physics_frame
func run() -> void:
	create_timer(60.0).timeout.connect(func():push_error("Perception test timed out");root.get_node("SaveManager").quit_game(2))
	var world := Node3D.new();root.add_child(world);current_scene=world
	var player := TestPlayer.new();player.name="Player";world.add_child(player);player.position=Vector3(0,0,8)
	var stance := Stance.new();stance.name="StealthStance";player.add_child(stance)
	var crime: Node3D=load("res://tools/world/crime_perception_fixture.gd").new();world.add_child(crime)
	crime.player=player;crime.encounter_state="test"
	crime.aggressor=Probe.new();world.add_child(crime.aggressor)
	var station := Node3D.new();world.add_child(station);crime.station=station
	var staff := Node.new();staff.name="ThanaStaff";station.add_child(staff)
	var coordinator := Coordinator.new();coordinator.name="ArrestCoordinator";staff.add_child(coordinator)
	var vehicle := Node3D.new();world.add_child(vehicle);vehicle.position=player.position
	await sync()
	crime.report_vehicle_theft(player,vehicle,"horse_theft")
	check(crime.wanted_level==0 and crime.evidence.is_empty(),"unattended horse produces no stars/evidence")
	var observer := Probe.new();observer.name="OwnerProbe";world.add_child(observer);observer.add_to_group("combat_actors")
	await sync()
	crime.report_vehicle_theft(player,vehicle,"cart_theft")
	check(crime.wanted_level==1 and crime.evidence.size()==1,"owner with sight reports cart theft")
	observer.rotation.y=PI
	crime.crime_score=0;crime.wanted=false;crime.wanted_level=0;crime.evidence.clear()
	crime.report_vehicle_theft(player,vehicle,"horse_theft")
	check(not crime.wanted,"nearby owner facing away cannot report theft")
	observer.rotation.y=0
	var wall := StaticBody3D.new();wall.collision_layer=1;world.add_child(wall)
	var shape := CollisionShape3D.new();var box := BoxShape3D.new();box.size=Vector3(20,6,1);shape.shape=box;wall.add_child(shape);wall.position=Vector3(0,2,4)
	await sync()
	check(not crime.visible_to(observer),"house wall blocks actual perception ray")
	crime.report_vehicle_theft(player,vehicle,"cart_theft")
	check(not crime.wanted,"occluded owner produces no stars")
	wall.position.x=100;await sync()
	observer.set_meta("knocked_out",true)
	crime.report_vehicle_theft(player,vehicle,"cart_theft")
	check(not crime.wanted,"unconscious witness cannot report")
	observer.set_meta("knocked_out",false);observer.set_meta("combat_faction","police")
	vehicle.set_meta("player_owned",true);crime.report_vehicle_theft(player,vehicle,"horse_theft")
	check(not crime.wanted,"player-owned vehicle remains lawful")
	vehicle.set_meta("player_owned",false);crime.report_vehicle_theft(player,vehicle,"horse_theft")
	crime.recruit_visible_police()
	check(crime.patrols.size()==1 and not observer.movement_enabled,"visible officer interrupts duty to pursue")
	crime._tick(.3)
	check(crime.patrols[0].seen and crime.patrols[0].state=="pursue","police sight acquires wanted Arjun")
	var remembered: Vector3=crime.patrols[0].last_seen
	player.position=Vector3(3,0,8);wall.position.x=0;await sync()
	crime.commanded_goals.clear();crime._tick(.3)
	check(not crime.patrols[0].seen,"entering shelter breaks police sight")
	check(crime.commanded_goals.size()>0 and crime.commanded_goals[-1]==remembered,"hidden pursuit searches last seen position instead of tracking Arjun")
	crime.advance_wanted(24.0,false)
	check(not crime.wanted and observer.movement_enabled and crime.patrols.is_empty(),"unseen escape clears star and restores interrupted duty")
	wall.position.x=100;await sync()
	var owners: Array[String]=["owner"]
	crime.record_incident("cart_theft",player.position,owners,5)
	crime.unseen_age=22;crime.advance_wanted(10.0,true)
	check(crime.wanted_level==1 and crime.unseen_age==0,"police sight prevents wanted decay")
	observer.position=player.position+Vector3(0,0,-1)
	observer.set_meta("last_attacker",player);observer.set_meta("last_hit_kind","murder")
	if crime.has_method("has_pending_police_case"):crime.report_assault(observer,player)
	else:crime.report_assault(observer,"murder")
	check(crime.wanted_level==3,"killing an engaged officer adds two stars")
	var saved: Dictionary=crime.export_crime_state();crime.crime_score=0;crime.restore_crime_state(saved)
	check(crime.wanted_level==3 and crime.evidence.size()==saved.evidence.size(),"crime evidence and stars survive save-state round trip")
	observer.position=Vector3.ZERO;wall.position=Vector3(0,.9,4);box.size=Vector3(20,1.8,1)
	player.position=Vector3(0,0,8);stance.height=.38;await sync()
	check(not crime.visible_to(observer),"lying low behind cover blocks police sight")
	player.set_meta("detention_action","escort")
	crime.advance_wanted(200,false)
	check(crime.wanted_level==3,"custody cannot clear stars by counting as hidden")
	player.set_meta("detention_action","")
	crime.advance_wanted(200,false)
	check(crime.wanted_level==2,"hidden wanted level decreases one star at a time")
	var station_probe: Node=load("res://world/suryagarh/settlements/police_arrest.gd").new()
	staff.add_child(station_probe);station_probe.set_physics_process(false)
	station_probe.suspect=player;station_probe.officer=observer
	wall.position.x=100;await sync()
	check(station_probe.officer_has_sight(),"station officer sees exposed suspect")
	wall.position.x=0;await sync()
	check(not station_probe.officer_has_sight(),"station officer respects low shelter cover")
	station_probe.phase="approach";station_probe.last_chase_goal=player.position
	var station_memory: Vector3=station_probe.last_chase_goal
	player.position.x=3;await sync()
	station_probe._physics_process(.3)
	check(station_probe.last_chase_goal==station_memory,"station chase does not update destination through cover")
	await boarding_checks()
	print("CRIME PERCEPTION ",JSON.stringify({"checks":count,"status":"PASS" if failures.is_empty() else "FAIL","failures":failures}))
	root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)

func boarding_checks() -> void:
	var previous := current_scene
	current_scene=null
	previous.queue_free()
	for frame in 3:await process_frame
	# Actual player rig and live vehicle methods prove reports are runtime hooks.
	for case in ["unwatched_horse","watched_horse","unwatched_cart","watched_cart","passenger"]:
		var world := Node3D.new();root.add_child(world)
		var clock: Node=load("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock)
		var actor: CharacterBody3D=load("res://player/player.tscn").instantiate();world.add_child(actor);actor.set_physics_process(false)
		var crime: Node3D=load("res://tools/world/crime_perception_fixture.gd").new();world.add_child(crime);crime.player=actor
		crime.add_to_group("police_crime_observers")
		var observer: Probe
		if case.begins_with("watched"):
			observer=Probe.new();world.add_child(observer);observer.add_to_group("combat_actors")
		var vehicle: Node3D=load("res://horses/stable_horse.gd" if case.ends_with("horse") else "res://vehicles/horse_cart_candidate.gd").new()
		world.add_child(vehicle);vehicle.set_physics_process(false)
		for frame in 8:await process_frame
		if case.ends_with("horse"):
			actor.position=vehicle.position+Vector3(1,.9,0)
		else:
			actor.global_position=vehicle.seat_sockets["DriverSeat"].global_position
		if observer:
			observer.global_position=actor.global_position+Vector3(0,0,-8)
		await sync()
		var boarded: bool=vehicle.board(actor) if case.ends_with("horse") else vehicle.board_at(actor,"DriverSeat" if case!="passenger" else vehicle.seat_sockets.keys().filter(func(key):return key!="DriverSeat")[0],"driver" if case!="passenger" else "passenger")
		check(boarded,"live vehicle boards: "+case)
		check(crime.wanted_level==(1 if case.begins_with("watched") else 0),"boarding report matches witnesses: "+case)
		world.queue_free()
		for frame in 3:await process_frame

	# Real MPFB officer vitality reports a fatal player hit before setting dead.
	var world := Node3D.new();root.add_child(world)
	var clock: Node=load("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock)
	var actor: CharacterBody3D=load("res://player/player.tscn").instantiate();world.add_child(actor);actor.set_physics_process(false)
	var crime: Node3D=load("res://tools/world/crime_perception_fixture.gd").new();world.add_child(crime);crime.player=actor;crime.add_to_group("police_crime_observers")
	var officer: Node3D=load("res://characters/npcs/thana/thana_officer.gd").new()
	officer.set_meta("combat_faction","police")
	officer.add_child(load("res://characters/npcs/thana/burkundaz_motion.glb").instantiate());world.add_child(officer)
	for frame in 8:await process_frame
	actor.position=officer.position+Vector3(0,.9,1)
	var officer_health: Node=officer.get_node("Vitality")
	check(officer_health.receive_hit(100.0,actor,"weapon"),"real MPFB officer accepts lethal weapon hit")
	check(officer_health.dead and crime.wanted_level==2,"fatal vitality hook immediately raises two police-killing stars")
	world.queue_free()
	for frame in 3:await process_frame
