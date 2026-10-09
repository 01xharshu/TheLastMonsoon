extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func frames(count: int) -> void:
 for index in count: await physics_frame
func run() -> void:
 var world := Node3D.new()
 root.add_child(world)
 var landscape := Node3D.new()
 landscape.name = "Landscape"
 world.add_child(landscape)
 var nature := Node3D.new()
 nature.name = "NatureTiles"
 landscape.add_child(nature)
 var clock := Node.new()
 clock.name = "GameTimeSystem"
 clock.set_script(load("res://world/suryagarh/systems/game_time_system.gd"))
 world.add_child(clock)
 var bridge: Node3D = load("res://world/suryagarh/timber_bridge.gd").new()
 world.add_child(bridge)
 var routes := preload("res://vehicles/coach_routes.gd")
 var west := Vector2(bridge.global_position.x-80,bridge.CROSSING_Z)
 var east := Vector2(bridge.global_position.x+80,bridge.CROSSING_Z)
 var outbound := routes.bridge_lanes(PackedVector2Array([west,east]))
 var inbound := routes.bridge_lanes(PackedVector2Array([east,west]))
 assert(is_equal_approx(outbound[0].y-inbound[0].y,bridge.LANE_OFFSET*2.0),"Coach route lanes must separate opposite directions")
 var boat: CharacterBody3D = load("res://vehicles/river_boat.gd").new()
 world.add_child(boat)
 boat.set_physics_process(false)
 boat.global_position = Vector3(bridge.global_position.x,.03,bridge.CROSSING_Z-20)
 await frames(2)
 for index in 80:
  if boat.move_and_collide(Vector3(0,0,.5)) != null: failures.append("river boat blocked under bridge")
 boat.collision_layer = 0
 boat.queue_free()
 var clearance := PhysicsShapeQueryParameters3D.new()
 var envelope := BoxShape3D.new()
 envelope.size = Vector3(24,bridge.BOAT_CLEARANCE-.2,12)
 clearance.shape = envelope
 clearance.transform.origin = Vector3(bridge.global_position.x,(bridge.BOAT_CLEARANCE-.2)*.5+.1,bridge.CROSSING_Z)
 if not world.get_world_3d().direct_space_state.intersect_shape(clearance).is_empty(): failures.append("navigation envelope blocked")
 print("BOAT NAVIGATION ","PASS" if failures.is_empty() else "FAIL")
 var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
 world.add_child(actor)
 actor.set_process_unhandled_input(false)
 actor.set_physics_process(false)
 actor.get_node("VisualRoot/CharacterVisual").set_process(false)
 await frames(10)
 actor.get_node("UI").hide()
 var results: Array[Dictionary] = []
 # Both largest carriages occupy opposite lanes at the same longitudinal point.
 var pair: Array[Node3D] = []
 for direction in [-1.0,1.0]:
  var carriage: Node3D = load("res://vehicles/family_carriage_candidate.gd").new()
  world.add_child(carriage)
  for detail in carriage.find_children("*","Node",true,false):
   detail.set_process(false)
   detail.set_physics_process(false)
  carriage.rotation.y = -direction*PI*.5
  pair.append(carriage)
 for x in range(-int(bridge.HALF_SPAN+bridge.RAMP-8),int(bridge.HALF_SPAN+bridge.RAMP-8)+1,4):
  var y: float = bridge.deck_height
  if absf(x) > bridge.HALF_SPAN:
   y = bridge.ramp_point(signf(x),(absf(x)-bridge.HALF_SPAN)/bridge.RAMP).y
  for index in 2:
   pair[index].global_position = bridge.global_position+Vector3(x,y,(-1.0 if index == 0 else 1.0)*bridge.LANE_OFFSET)
  await frames(1)
  for carriage in pair:
   if not carriage.boarding._clearance_at(carriage.global_position):
    failures.append("opposing family carriage clearance x="+str(x))
 for carriage in pair: carriage.queue_free()
 await frames(2)
 print("TWO CARRIAGE LANES ","PASS" if failures.is_empty() else "FAIL")
 for kind in (1 if "--family-only" in OS.get_cmdline_user_args() else 3):
  for direction in [-1.0,1.0]:
   var cart: Node3D = load("res://vehicles/family_carriage_candidate.gd").new() if kind == 0 else load("res://vehicles/horse_cart_candidate.gd").new()
   if kind > 0: cart.variant = kind-1
   world.add_child(cart)
   var start_x: float = -direction*(bridge.HALF_SPAN+bridge.RAMP-1.0)
   var ramp: Vector3 = bridge.ramp_point(-direction,(bridge.RAMP-1.0)/bridge.RAMP)
   cart.global_position = bridge.global_position+Vector3(start_x,ramp.y,direction*bridge.LANE_OFFSET)
   cart.rotation.y = -direction*PI*.5
   actor.global_position = cart.global_position+Vector3(0,1,1.5)
   var seat := "CoachmanSeat" if kind == 0 else "DriverSeat"
   if not cart.board_at(actor,seat,"driver"):
    failures.append("boarding "+str(kind))
    break
   await frames(90)
   cart.boarding.set_physics_process(false)
   actor.set_physics_process(false)
   actor.get_node("VisualRoot/CharacterVisual").set_process(false)
   Input.action_press("move_forward")
   Input.action_press("sprint")
   var max_error := 0.0
   var ticks := 0
   for tick in 2600:
    cart.boarding._physics_process(.1)
    await physics_frame
    ticks = tick
    if tick % 300 == 0: print("BRIDGE PROGRESS kind=",kind," direction=",direction," tick=",tick," at=",cart.global_position," speed=",cart.boarding.speed," transition=",cart.boarding.transition)
    max_error = maxf(max_error,absf(cart.global_position.z-bridge.CROSSING_Z-direction*bridge.LANE_OFFSET))
    if direction*(cart.global_position.x-bridge.global_position.x) >= bridge.HALF_SPAN+bridge.RAMP-4.0: break
   Input.action_release("move_forward")
   Input.action_release("sprint")
   var crossed: bool = direction*(cart.global_position.x-bridge.global_position.x) >= bridge.HALF_SPAN+bridge.RAMP-4.0
   results.append({"cart":kind,"direction":direction,"crossed":crossed,"ticks":ticks,"x_offset":cart.global_position.x-bridge.global_position.x,"speed":cart.boarding.speed,"transition":cart.boarding.transition,"can_move":cart.can_move(),"lateral_error_m":max_error,"width_m":bridge.WIDTH})
   if not crossed: failures.append("crossing "+str(kind)+" direction "+str(direction))
   print("CART BRIDGE ",results[-1])
   cart.boarding.rider = null
   actor.set_meta("mounted_vehicle",null)
   actor.set_meta("cart_role","")
   cart.queue_free()
   await frames(2)

 print("CART BRIDGE ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
