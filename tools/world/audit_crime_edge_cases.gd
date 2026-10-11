extends "res://tools/world/validate_crime_perception.gd"
## Reproduce gaps beyond the baseline suite without changing game logic.
func run() -> void:
	create_timer(45.0).timeout.connect(func():root.get_node("SaveManager").quit_game(2))
	var world := Node3D.new();root.add_child(world);current_scene=world
	var player := TestPlayer.new();player.name="Player";world.add_child(player);player.position=Vector3(0,0,-2)
	var stance := Stance.new();stance.name="StealthStance";player.add_child(stance)
	var observer := Probe.new();world.add_child(observer);observer.add_to_group("combat_actors")
	var crime: Node3D=load("res://tools/world/crime_perception_fixture.gd").new();world.add_child(crime);crime.player=player
	var vehicle := Node3D.new();world.add_child(vehicle);vehicle.position=player.position
	await sync()
	crime.report_vehicle_theft(player,vehicle,"horse_theft")
	print("AUDIT close back-facing witness raises star: ",crime.wanted_level)
	world.queue_free();current_scene=null
	for frame in 3:await process_frame
	var first := await cart_world(false)
	var cart: Node3D=first.get_node("Cart")
	var actor: CharacterBody3D=first.get_node("Player")
	actor.global_position=cart.seat_sockets.DriverSeat.global_position
	print("AUDIT initial unwatched cart boards: ",cart.board_at(actor,"DriverSeat","driver"))
	var saved: Array=load("res://vehicles/cart_save_state.gd").collect(first)
	print("AUDIT saved cart carries crime_taken: ",saved[0].has("crime_taken"))
	first.queue_free()
	for frame in 3:await process_frame
	var second := await cart_world(true)
	load("res://vehicles/cart_save_state.gd").restore(second,saved)
	print("AUDIT restoring saved driver near witness raises star: ",second.get_node("CombatEncounters").wanted_level)
	root.get_node("SaveManager").quit_game()
func cart_world(watched: bool) -> Node3D:
	var world := Node3D.new();root.add_child(world)
	var clock: Node=load("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock)
	var actor: CharacterBody3D=load("res://player/player.tscn").instantiate();world.add_child(actor);actor.set_physics_process(false)
	var crime: Node3D=load("res://tools/world/crime_perception_fixture.gd").new();crime.name="CombatEncounters";world.add_child(crime);crime.player=actor;crime.add_to_group("police_crime_observers")
	var cart: Node3D=load("res://vehicles/horse_cart_candidate.gd").new();cart.name="Cart";world.add_child(cart);cart.add_to_group("live_travel_carts");cart.set_physics_process(false)
	for frame in 8:await process_frame
	actor.global_position=cart.seat_sockets.DriverSeat.global_position
	if watched:
		var observer := Probe.new();world.add_child(observer);observer.add_to_group("combat_actors")
		observer.global_position=cart.seat_sockets.DriverSeat.global_position+Vector3(0,0,-8)
	await sync()
	return world
