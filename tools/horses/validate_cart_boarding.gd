extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
 var world := Node3D.new()
 root.add_child(world)
 var time := Node.new()
 time.name = "GameTimeSystem"
 time.set_script(load("res://world/suryagarh/systems/game_time_system.gd"))
 world.add_child(time)
 var floor := StaticBody3D.new()
 var collision := CollisionShape3D.new()
 var box := BoxShape3D.new()
 box.size = Vector3(30,.2,30)
 collision.shape = box
 floor.add_child(collision)
 world.add_child(floor)
 var cart: Node3D = load("res://vehicles/family_carriage_candidate.gd").new()
 world.add_child(cart)
 var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
 actor.position = Vector3(2,1,2.2)
 world.add_child(actor)
 await create_timer(.3).timeout
 assert(cart.board_at(actor,"RearPassengerRight","passenger"))
 await create_timer(.2).timeout
 assert(cart.rider == actor)
 assert(actor.get_meta("cart_role","") == "passenger")
 assert(cart.boarding.dismount())
 assert(cart.rider == null)
 actor.global_position = Vector3(0,1,.1)
 assert(cart.board_at(actor,"CoachmanSeat","driver"))
 await create_timer(.2).timeout
 assert(actor.get_meta("cart_role","") == "driver")
 assert(cart.boarding.dismount())
 cart.queue_free()
 await process_frame
 for kind in 2:
  var trial: Node3D = load("res://vehicles/horse_cart_candidate.gd").new()
  trial.variant = kind
  world.add_child(trial)
  actor.global_position = Vector3(-1,1,1.7)
  assert(trial.board_at(actor,"DriverSeat","driver"))
  await create_timer(.1).timeout
  assert(trial.rider == actor)
  assert(trial.boarding.dismount())
  trial.queue_free()
  await process_frame
 print("CART PLAYER BOARD/DISMOUNT/DRIVER: PASS | family, ekka, goods")
 quit()
