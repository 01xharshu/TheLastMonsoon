extends Node

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var routes := preload("res://vehicles/coach_routes.gd")
	var graph := routes.build()
	assert(routes.route(graph, Vector2(-265, -18), "Town Hall").size() > 30, "Distant connected road missing")
	assert(routes.route(graph, Vector2(0, -600), "Town Hall").is_empty(), "Off-road departure accepted")
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate() if "--live" in OS.get_cmdline_user_args() else _isolated()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var actor: CharacterBody3D = world.get_node("Player")
	var cart: Node3D = world.get_node("LiveCarts/GovernmentHouseFamilyCarriage")
	actor.global_position = cart.to_global(Vector3(-2.0, .96, 2.79))
	assert(cart.board_at(actor, "RearPassengerLeft", "passenger"))
	for i in 90: await get_tree().physics_frame
	actor.inventory.add_item("rupees",5)
	var stop := "Police Station" if "--bridge" in OS.get_cmdline_user_args() else "Town Hall"
	assert(cart.boarding.travel.request_trip(stop))
	var target: Vector2 = cart.boarding.travel.path[-1]
	var initial: Vector3 = cart.global_position
	for i in 15000:
		await get_tree().physics_frame
		if i % 1800 == 0: print("PAID LIVE PROGRESS: ",cart.global_position," waypoint=",cart.boarding.travel.waypoint)
		if cart.boarding.travel.payer == null: break
	var error := Vector2(cart.global_position.x,cart.global_position.z).distance_to(target)
	var passed: bool = cart.boarding.travel.payer == null and error < 3.0 and actor.inventory.get_item_count("rupees") == 3
	print("PAID LIVE ROAD: ","PASS" if passed else "FAIL"," | arrival error=",error," displacement=",initial.distance_to(cart.global_position)," rupees=",actor.inventory.get_item_count("rupees"))
	get_tree().quit(0 if passed else 1)

func _isolated() -> Node3D:
	var world := Node3D.new()
	var layout := preload("res://world/suryagarh/landscape_layout.gd").new()
	var terrain := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var heightmap := HeightMapShape3D.new()
	heightmap.map_width = 151
	heightmap.map_depth = 251
	var heights := PackedFloat32Array()
	for z in range(251):
		for x in range(151): heights.append(layout.height(-450 + x * 2, -400 + z * 2))
	heightmap.map_data = heights
	collision.shape = heightmap
	collision.scale = Vector3(2, 1, 2)
	terrain.add_child(collision)
	terrain.position = Vector3(-300, 0, -150)
	world.add_child(terrain)
	var time := Node.new()
	time.name = "GameTimeSystem"
	time.set_script(load("res://world/suryagarh/systems/game_time_system.gd"))
	world.add_child(time)
	var carts := Node3D.new()
	carts.name = "LiveCarts"
	world.add_child(carts)
	var cart: Node3D = load("res://vehicles/family_carriage_candidate.gd").new()
	cart.name = "GovernmentHouseFamilyCarriage"
	cart.position = Vector3(-265, layout.height(-265, -18), -18)
	cart.rotation.y = -PI * .5
	cart.add_to_group("live_travel_carts")
	carts.add_child(cart)
	var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
	actor.name = "Player"
	world.add_child(actor)
	return world
