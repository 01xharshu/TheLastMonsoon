extends "res://tools/world/audit_crime_edge_cases.gd"
## Real boarding/restore plus shared perception and acquisition edge cases.
const Permission=preload("res://systems/vehicle_permissions.gd")
func run() -> void:
	create_timer(90.0).timeout.connect(func():root.get_node("SaveManager").quit_game(2))
	var world := Node3D.new();root.add_child(world);current_scene=world
	var player := TestPlayer.new();player.name="Player";world.add_child(player);player.position=Vector3(0,0,-2)
	var stance := Stance.new();stance.name="StealthStance";player.add_child(stance)
	var observer := Probe.new();world.add_child(observer);observer.add_to_group("combat_actors")
	var crime: Node3D=load("res://tools/world/crime_perception_fixture.gd").new();world.add_child(crime);crime.player=player
	var vehicle := Node3D.new();world.add_child(vehicle);vehicle.position=player.position
	await sync()
	crime.report_vehicle_theft(player,vehicle,"horse_theft")
	check(not crime.wanted,"two-metre rear-facing witness cannot identify theft")
	var staff:=Node.new();world.add_child(staff)
	var station: Node=load("res://world/suryagarh/settlements/police_arrest.gd").new();staff.add_child(station);station.set_physics_process(false)
	check(not station.can_see(observer,player),"station and street use same close rear-facing rule")
	observer.rotation.y=PI;await sync()
	check(station.can_see(observer,player) and crime.visible_to(observer),"close front-facing sight remains available")
	observer.set_meta("sleeping",true)
	check(not crime.visible_to(observer),"sleeping witness cannot visually identify suspect")
	world.queue_free();current_scene=null
	for frame in 3:await process_frame
	var first := await cart_world(false)
	var cart: Node3D=first.get_node("Cart")
	var actor: CharacterBody3D=first.get_node("Player")
	actor.global_position=cart.seat_sockets.DriverSeat.global_position
	check(cart.board_at(actor,"DriverSeat","driver"),"real initial unwatched driver boards")
	var saved: Array=load("res://vehicles/cart_save_state.gd").collect(first)
	check(saved[0].get("crime_taken",false),"acquisition state is serialized")
	first.queue_free()
	for frame in 3:await process_frame
	var second := await cart_world(true)
	load("res://vehicles/cart_save_state.gd").restore(second,saved)
	var restored: Node3D=second.get_node("Cart")
	var restored_crime: Node3D=second.get_node("CombatEncounters")
	check(restored.boarding.role=="driver" and restored.boarding.rider==second.get_node("Player"),"restore reconstructs real driver seat")
	check(restored_crime.wanted_level==0 and restored_crime.evidence.is_empty(),"restore produces no new theft or evidence")
	check(restored.get_meta("crime_taken",false) and not restored.has_meta("restore_in_progress"),"restore retains acquisition and releases suppression")
	var restored_actor: Node=second.get_node("Player")
	Permission.take(restored,restored_actor,"cart_theft")
	check(not restored_crime.wanted,"acquired cart does not report repeated taking")
	Permission.reclaim(restored);Permission.take(restored,restored_actor,"cart_theft")
	check(restored_crime.wanted_level==1,"owner reclaim allows a fresh witnessed theft")
	Permission.reclaim(restored);restored.set_meta("driver_permission","Player")
	restored_crime.crime_score=0;restored_crime.wanted_level=0;restored_crime.wanted=false
	Permission.take(restored,restored_actor,"cart_theft")
	check(not restored_crime.wanted and not restored.get_meta("crime_taken",false),"lawful borrowing does not consume acquisition flag")
	var permission_state:=Permission.export_state(restored)
	restored.set_meta("driver_permission","");Permission.restore_state(restored,permission_state)
	check(Permission.lawful(restored,restored_actor),"borrow permission survives round trip")
	second.queue_free()
	for frame in 3:await process_frame
	var legacy := await cart_world(true)
	var old_state: Dictionary=saved[0].duplicate(true)
	for key in ["crime_taken","player_owned","owner","driver_permission"]:old_state.erase(key)
	load("res://vehicles/cart_save_state.gd").restore(legacy,[old_state])
	check(not legacy.get_node("CombatEncounters").wanted and legacy.get_node("Cart").get_meta("crime_taken",false),"legacy occupied driver migrates silently as acquired")
	legacy.queue_free()
	for frame in 3:await process_frame
	await horse_checks()
	print("ARCHITECTURE BOUNDARIES ",JSON.stringify({"checks":count,"status":"PASS" if failures.is_empty() else "FAIL","failures":failures}))
	root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)

func horse_world(watched: bool) -> Node3D:
	var world:=await cart_world(false)
	var horse:Node3D=load("res://horses/stable_horse.gd").new();horse.name="SaveHorse";world.add_child(horse)
	horse.set_physics_process(false);horse.set_process(false)
	for frame in 8:await process_frame
	var actor:CharacterBody3D=world.get_node("Player")
	actor.global_position=horse.global_position+Vector3(1,.9,0)
	if watched:
		var observer:=Probe.new();world.add_child(observer);observer.add_to_group("combat_actors")
		observer.global_position=actor.global_position-Vector3(0,0,8)
	await sync()
	return world

func horse_checks() -> void:
	var first:=await horse_world(false)
	var horse:Node3D=first.get_node("SaveHorse")
	check(horse.board(first.get_node("Player")),"real unwatched horse mounts for save")
	var saved:Array=preload("res://horses/horse_save_state.gd").collect(first)
	check(saved.size()==1 and saved[0].crime_taken and saved[0].mounted,"horse acquisition and mounted state serialize")
	first.queue_free()
	for frame in 3:await process_frame
	var second:=await horse_world(true)
	preload("res://horses/horse_save_state.gd").restore(second,saved)
	check(second.get_node("SaveHorse").rider==second.get_node("Player"),"Continue restores Player horse riding")
	check(not second.get_node("CombatEncounters").wanted,"horse restore near witness does not generate theft")
	check(not second.get_node("SaveHorse").voice_player.playing and not second.get_node("SaveHorse").tack_player.playing,"horse restore does not replay taking sounds")
	second.queue_free()
	for frame in 3:await process_frame
