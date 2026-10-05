extends SceneTree
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
 var world := SaveFixture.new()
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
 cart.add_to_group("live_travel_carts")
 var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
 actor.name = "Player"
 actor.position = Vector3(2,1,2.2)
 world.add_child(actor)
 await create_timer(.3).timeout
 assert(cart.board_at(actor,"RearPassengerRight","passenger"))
 await create_timer(cart.boarding.TRANSITION_SECONDS+.2).timeout
 assert(cart.rider == actor)
 assert(actor.get_meta("cart_role","") == "passenger")
 await create_timer(.1).timeout
 var travel: Node = cart.boarding.travel
 var routes := preload("res://vehicles/coach_routes.gd")
 var graph: AStar2D = routes.build()
 for start in routes.STOPS.values():
  for stop in routes.STOPS:
   assert(not routes.route(graph,start,stop).is_empty(),"Disconnected coach stop: "+str(stop))
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
 actor.inventory.add_item("rupees",4)
 cart.global_position = Vector3(-310,8,-432)
 assert(travel.request_trip("Town Hall"))
 var fare_after_booking: int = actor.inventory.get_item_count("rupees")
 assert(travel.skip_ui != null)
 var arrival_ground: float = preload("res://world/suryagarh/landscape_layout.gd").new().height(-320,-432)
 floor.global_position.y = arrival_ground-.1
 await physics_frame
 await physics_frame
 var obstacle := StaticBody3D.new()
 var obstacle_shape := CollisionShape3D.new()
 var obstacle_box := BoxShape3D.new()
 obstacle_box.size = Vector3(8,3,8)
 obstacle_shape.shape = obstacle_box
 obstacle.add_child(obstacle_shape)
 world.add_child(obstacle)
 obstacle.global_position = Vector3(-320,arrival_ground+1.5,-432)
 await physics_frame
 await physics_frame
 var before_skip: Vector3 = cart.global_position
 assert(not travel.skip_journey(), "Blocked destination must reject skipping")
 assert(cart.global_position.distance_to(before_skip) < .01 and travel.payer == actor)
 assert(actor.inventory.get_item_count("rupees") == fare_after_booking)
 obstacle.queue_free()
 await physics_frame
 await physics_frame
 assert(travel.skip_journey(), "Clear arrival must allow skipping")
 assert(travel.payer == null and travel.skip_ui == null)
 assert(actor.inventory.get_item_count("rupees") == fare_after_booking, "Skip charged twice")
 assert(cart.global_position.distance_to(Vector3(-320,arrival_ground,-432)) < 2.0)
 assert(not travel.skip_journey(), "Finished journey cannot skip twice")
 actor.inventory.remove_item("rupees",2)
 cart.global_position = Vector3(-250,7.2,230)
 assert(travel.request_trip("Police Station"))
 assert(actor.inventory.get_item_count("rupees") == 1)
 var crosses := false
 for point in travel.path:
  if absf(point.y-165)<1 and point.x>0: crosses = true
 assert(crosses)
 cart.boarding._sync_rider()
 var saved := preload("res://vehicles/cart_save_state.gd").collect(world)
 assert(saved.size() == 1 and saved[0].paid_destination == "Police Station")
 # Resume an already charged journey without another deduction.
 travel.payer = null
 travel.path.clear()
 travel.close_skip()
 cart.boarding.rider = null
 actor.collision_layer = cart.boarding.saved_layer
 actor.collision_mask = cart.boarding.saved_mask
 actor.set_meta("mounted_vehicle",null)
 preload("res://vehicles/cart_save_state.gd").restore(world,saved)
 await create_timer(cart.boarding.TRANSITION_SECONDS+.2).timeout
 assert(travel.payer == actor,"Saved paid journey did not resume")
 assert(actor.inventory.get_item_count("rupees") == 1)
 travel.cancel()
 assert(actor.inventory.get_item_count("rupees") == 3)
 assert(travel.payer == null)
 assert(travel.request_trip("Police Station"))
 cart.boarding.set_physics_process(false)
 for tick in 490: travel.controls(1.0/60.0)
 assert(travel.payer == null and actor.inventory.get_item_count("rupees") == 3,"Blocked trip must refund")
 # Real disk round trip in a dedicated test save directory.
 var manager: Node = root.get_node("SaveManager")
 var previous_root: String = manager.save_root
 manager.save_root = "user://cart_roundtrip_validation"
 assert(travel.request_trip("Police Station"))
 var saved_at: Vector3 = cart.global_position
 assert(manager.save_game(world,1),"Cart disk save failed")
 var disk: Dictionary = manager.read_slot(1)
 assert(disk.cart_states[0].paid_destination == "Police Station")
 assert(disk.items.rupees == 1)
 travel.payer = null
 travel.path.clear()
 travel.close_skip()
 cart.boarding.rider = null
 actor.collision_layer = cart.boarding.saved_layer
 actor.collision_mask = cart.boarding.saved_mask
 actor.set_meta("mounted_vehicle",null)
 cart.global_position += Vector3(3,0,0)
 actor.inventory.items["rupees"] = 99
 manager.pending_slot = 1
 cart.boarding.set_physics_process(true)
 manager.apply_pending(world)
 await create_timer(cart.boarding.TRANSITION_SECONDS+.2).timeout
 assert(cart.rider == actor and cart.global_position.distance_to(saved_at) < .01,"Disk cart/seat restore failed")
 assert(travel.payer == actor and actor.inventory.get_item_count("rupees") == 1,"Disk resume/fare failed: rupees=%d transition=%s" % [actor.inventory.get_item_count("rupees"),cart.boarding.transition])
 travel.cancel()
 assert(actor.inventory.get_item_count("rupees") == 3)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(manager.slot_path(1)))
 DirAccess.remove_absolute(ProjectSettings.globalize_path(manager.save_root))
 manager.save_root = previous_root
 print("PAID COACH DISK SAVE/LOAD: PASS | cart, seat, paid destination, no second fare")
 travel.show_menu()
 assert(travel.menu != null)
 travel.close_menu()
 print("PAID COACH: PASS | funds, single charge, arrival, bridge route, cancellation refund, optional skip without extra charge")
 quit()

class SaveFixture extends Node3D:
 var layout := preload("res://world/suryagarh/landscape_layout.gd").new()
