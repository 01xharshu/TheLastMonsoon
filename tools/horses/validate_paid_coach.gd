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
 await create_timer(cart.boarding.TRANSITION_SECONDS+.2).timeout
 assert(cart.rider == actor)
 assert(actor.get_meta("cart_role","") == "passenger")
 await create_timer(.1).timeout
 var travel: Node = cart.boarding.travel
 cart.global_position = Vector3(-250,7.2,230)
 assert(not travel.request_trip("Town Hall"))
 assert(actor.inventory.get_item_count("rupees") == 0)
 actor.inventory.add_item("rupees",5)
 cart.global_position = Vector3(-310,8,-432)
 floor.global_position = Vector3(-310,7.9,-432)
 assert(travel.request_trip("Town Hall"))
 assert(actor.inventory.get_item_count("rupees") == 3)
 assert(not travel.request_trip("Police Station"))
 assert(actor.inventory.get_item_count("rupees") == 3)
 for tick in 700:
  await physics_frame
  if travel.payer == null: break
 assert(travel.payer == null)
 assert(actor.inventory.get_item_count("rupees") == 3)
 cart.global_position = Vector3(-250,7.2,230)
 assert(travel.request_trip("Police Station"))
 assert(actor.inventory.get_item_count("rupees") == 1)
 var crosses := false
 for point in travel.path:
  if absf(point.y-165)<1 and point.x>0: crosses = true
 assert(crosses)
 travel.cancel()
 assert(actor.inventory.get_item_count("rupees") == 3)
 assert(travel.payer == null)
 print("PAID COACH: PASS | funds, single charge, arrival, bridge route, cancellation refund")
 quit()
