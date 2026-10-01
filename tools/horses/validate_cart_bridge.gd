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
 var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
 world.add_child(actor)
 actor.set_process_unhandled_input(false)
 await frames(10)
 var results: Array[Dictionary] = []
 for kind in 3:
  for direction in [-1.0,1.0]:
   var cart: Node3D = load("res://vehicles/family_carriage_candidate.gd").new() if kind == 0 else load("res://vehicles/horse_cart_candidate.gd").new()
   if kind > 0: cart.variant = kind-1
   world.add_child(cart)
   var start_x: float = -direction*(bridge.HALF_SPAN+bridge.RAMP-1.0)
   var ramp: Vector3 = bridge.ramp_point(-direction,(bridge.RAMP-1.0)/bridge.RAMP)
   cart.global_position = bridge.global_position+Vector3(start_x,ramp.y,0.0)
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
    max_error = maxf(max_error,absf(cart.global_position.z-bridge.CROSSING_Z))
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
 FileAccess.open("res://docs/world/cart_bridge_validation.json",FileAccess.WRITE).store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","failures":failures,"results":results,"scope":"actual bridge/carts in isolated physics fixture; terrain approaches and owner route review open"},"\t"))
 print("CART BRIDGE ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
