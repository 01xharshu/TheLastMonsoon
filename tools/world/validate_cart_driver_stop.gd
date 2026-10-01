extends SceneTree
var failures: Array[String]=[]
func check(value:bool,label:String) -> void:
	if not value:failures.append(label);push_error(label)
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	create_timer(30).timeout.connect(func():quit(2))
	var world:=Node3D.new();root.add_child(world)
	var clock:=preload("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock)
	var floor:=StaticBody3D.new();world.add_child(floor)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(100,.2,100);shape.shape=box;shape.position.y=-.1;floor.add_child(shape)
	var actor:CharacterBody3D=load("res://player/player.tscn").instantiate();actor.position=Vector3(-1,1,1.7);world.add_child(actor)
	var cart:=preload("res://vehicles/horse_cart_candidate.gd").new();cart.variant=1;world.add_child(cart)
	for frame in 8:await physics_frame
	check(cart.board_at(actor,"DriverSeat","driver"),"board live cart")
	await create_timer(1.3).timeout
	Input.action_press("move_forward")
	for frame in 60:await physics_frame
	check(cart.global_position.length()>.1,"cart moves under real driver input")
	cart.combat.horses[0].take_damage(100)
	var stopped:=cart.global_transform
	for frame in 40:await physics_frame
	check(cart.global_transform.is_equal_approx(stopped),"driver input cannot move dead-horse cart")
	check(is_zero_approx(cart.boarding.speed),"dead-horse cart speed cleared")
	Input.action_release("move_forward")
	check(cart.boarding.dismount(),"exit disabled cart")
	await create_timer(1.3).timeout
	check((not actor.has_meta("mounted_vehicle") or actor.get_meta("mounted_vehicle")==null),"dismount restores actor mount state")
	actor.global_position=cart.to_global(Vector3(-1,1,1.7))
	check(not cart.board_at(actor,"DriverSeat","driver"),"cannot board dead-horse cart as driver")
	# Real rifle dispatcher and muzzle ray, using a fresh cart at a separate site.
	var target_cart:=preload("res://vehicles/horse_cart_candidate.gd").new();target_cart.position=Vector3(15,0,0);world.add_child(target_cart)
	actor.global_position=Vector3(20,1,-1.15);actor.rotation.y=PI*.5
	actor.is_swimming=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var visual:Node3D=actor.get_node("VisualRoot/CharacterVisual")
	visual.equipment.selected=1;visual.equipment.stowed=false;visual.equipment._refresh()
	var rifle:Node=actor.get_node("RifleCombat");rifle.set_process(false)
	var camera:Camera3D=rifle.camera;camera.top_level=true
	camera.global_position=Vector3(20,1.25,-1.15);camera.look_at(Vector3(15,1.25,-1.15))
	for frame in 4:await physics_frame
	rifle.aiming=true;rifle.rounds=1;rifle.reload_remaining=0;rifle.fire()
	check(rifle.shots_fired==1,"real rifle fire dispatched")
	check(is_equal_approx(target_cart.combat.horses[0].health,30),"real rifle damages cart horse")
	rifle.rounds=1;rifle.aiming=true;rifle.fire()
	check(target_cart.combat.horses[0].dead,"second real rifle shot kills horse")
	var stable:=preload("res://horses/stable_horse.gd").new();stable.position=Vector3(-15,0,0);world.add_child(stable)
	actor.global_position=Vector3(-16.5,1,0)
	camera.top_level=false
	for frame in 12:await physics_frame
	check(stable.board(actor),"mount live independent horse")
	await create_timer(.8).timeout
	stable.take_damage(100)
	await create_timer(2).timeout
	check(stable.vitality.dead,"independent horse dies")
	check(not stable.can_board(actor),"dead independent horse cannot be mounted")
	check(stable.rider==null,"lethal horse hit releases mounted rider onto clear ground")
	check(actor.collision_layer!=0,"rider collision restored after horse death")
	print("CART DRIVER/RIFLE: ",JSON.stringify({"passed":failures.is_empty(),"failures":failures}))
	world.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
