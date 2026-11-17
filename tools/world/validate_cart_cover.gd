extends SceneTree
## Real player and production passenger/goods carts on a supported floor.
const Trace = preload("res://combat/ballistic_trace.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var clock: Node = load("res://world/suryagarh/systems/game_time_system.gd").new()
	clock.name = "GameTimeSystem"
	world.add_child(clock)
	var floor := StaticBody3D.new()
	world.add_child(floor)
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(30,.4,30)
	floor_collision.shape = floor_shape
	floor_collision.position.y = -.2
	floor.add_child(floor_collision)
	var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
	world.add_child(actor)
	actor.position = Vector3(2,1,2.5)
	for i in 25: await physics_frame
	var stance: Node = actor.get_node("StealthStance")
	var pistol: Node = actor.get_node("PistolCombat")
	var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
	actor.inventory.add_item("pistol",1)
	visual.equipment.select_weapon(3)
	for variant in 2:
		var cart = load("res://vehicles/horse_cart_candidate.gd").new()
		cart.variant = variant
		cart.show_horse = false
		world.add_child(cart)
		var z := 2.51 if variant == 0 else 2.75
		actor.global_position = Vector3(2, .91, z)
		actor.velocity = Vector3.ZERO
		actor.get_node("CameraPivot").global_rotation = Vector3(0,PI*.5,0)
		for i in 15: await physics_frame
		var point_y := 1.47 if variant == 0 else 1.44
		var blocked := Trace.sight(world.get_world_3d().direct_space_state,self,Vector3(3,point_y,z),Vector3(-3,point_y,z),[actor.get_rid()])
		check(not blocked.is_empty() and cart.is_ancestor_of(blocked.collider) and blocked.collider.has_meta("cart_solid_part"),"Cart %d visible board did not stop a sight ray" % variant)
		var shot := Trace.shoot(world.get_world_3d().direct_space_state,self,Vector3(3,point_y,z),Vector3(-3,point_y,z),38.0,[actor.get_rid()],actor)
		check(not shot.is_empty() and shot.collider == blocked.get("collider"),"Cart %d board did not stop an actual ballistic shot" % variant)
		var opening := Trace.sight(world.get_world_3d().direct_space_state,self,Vector3(3,.4,z),Vector3(-3,.4,z),[actor.get_rid()])
		check(opening.is_empty(),"Cart %d falsely blocks the empty space beneath its deck" % variant)
		check(stance.try_cover(),"Cart %d visible side was not accepted as cover" % variant)
		check(is_instance_valid(stance.cover_body) and cart.is_ancestor_of(stance.cover_body) and stance.cover_body.has_meta("cart_solid_part"),"Cart %d cover is not a real board" % variant)
		Input.action_press("aim")
		for i in 30: await physics_frame
		check(pistol.aiming and pistol.fire(),"Pistol could not aim and fire from cart %d cover" % variant)
		Input.action_release("aim")
		var previous: Vector3 = stance.cover_point
		cart.position.z += .3
		for i in 3: await physics_frame
		check(stance.stance == "cover" and stance.cover_point.distance_to(previous + Vector3(0,0,.3)) < .01,"Cart %d cover did not follow its real moving board" % variant)
		stance.stand()
		cart.queue_free()
		for i in 4: await physics_frame
	print("REAL CART COVER ",JSON.stringify({"passed":failures.is_empty(),"failures":failures,"scope":"production passenger and goods cart boards, gaps, pistol fire and moving cover"}))
	await root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)
