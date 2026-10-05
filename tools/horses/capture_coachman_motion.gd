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
 actor.set_meta("mounted_vehicle",null)
 world.add_child(actor)
 actor.set_process_unhandled_input(false)
 await frames(10)
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-45,-30,0)
 world.add_child(sun)
 var cart: Node3D = load("res://vehicles/family_carriage_candidate.gd").new()
 world.add_child(cart)
 cart.global_position = bridge.global_position+Vector3(0,bridge.deck_height,0)
 cart.rotation.y = -PI*.5
 actor.global_position = cart.global_position+Vector3(0,1,1.5)
 assert(cart.board_at(actor,"RearPassengerRight","passenger"))
 await frames(100)
 actor.get_node("CameraPivot/SpringArm3D/Camera3D").set_process(false)
 actor.visual_root.show()
 actor.get_node("UI").hide()
 cart.boarding.travel.close_menu()
 var camera := Camera3D.new()
 world.add_child(camera)
 camera.global_position = cart.to_global(Vector3(2.3,2.8,-.5))
 camera.look_at(cart.to_global(Vector3(0,2.2,.90)))
 camera.make_current()
 var driver: Node3D = cart.visual_root.get_node("CoachmanMakeHuman")
 assert(driver._skeleton.get_bone_count() > 40)
 cart.boarding.set_physics_process(false)
 var results: Array[Dictionary] = []
 for state in [{"name":"idle","acceleration":0.0,"turn":0.0},{"name":"accelerating","acceleration":4.0,"turn":0.0},{"name":"turning","acceleration":0.0,"turn":1.0},{"name":"braking","acceleration":-4.0,"turn":0.0}]:
  cart.boarding.rider_acceleration = state.acceleration
  cart.boarding.rider_turn = state.turn
  for step in 90: await process_frame
  RenderingServer.force_draw(false)
  var path := "res://docs/world/captures/coachman_motion_"+str(state.name)+".png"
  assert(root.get_texture().get_image().save_png(path)==OK)
  var worst_hand := 0.0
  var worst_foot := 0.0
  for side in ["l","r"]:
   worst_hand = maxf(worst_hand,driver.palm_world(side).distance_to(cart.rein_grip_world(side)))
   var foot: int = driver._skeleton.find_bone("foot_"+side)
   var ankle: Vector3 = driver._skeleton.to_global(driver._skeleton.get_bone_global_pose(foot).origin)
   worst_foot = maxf(worst_foot,ankle.distance_to(driver.foot_target_world(side)))
  results.append({"state":state.name,"hand_error_m":worst_hand,"ankle_error_m":worst_foot,"lean":driver.driver_lean,"turn":driver.driver_turn})
  assert(worst_hand < .02 and worst_foot < .02)
  if state.name == "accelerating": assert(driver.driver_lean > .21)
  if state.name == "braking": assert(driver.driver_lean < .15)
  if state.name == "turning": assert(driver.driver_turn > .045)
 FileAccess.open("res://docs/world/coachman_motion_validation.json",FileAccess.WRITE).store_string(JSON.stringify({"scope":"controlled driving pose signals; stationary cart; native Metal","results":results},"\t"))
 print("COACHMAN DRIVING CONTACT METAL PASS ",results)
 quit()
