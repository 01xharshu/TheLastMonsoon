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
 await process_frame
 var driver: Node3D = cart.visual_root.get_node("CoachmanMakeHuman")
 assert(driver._skeleton.get_bone_count() > 40)
 for side in ["l","r"]:
  var error: float = driver.palm_world(side).distance_to(cart.rein_grip_world(side))
  print("MAKEHUMAN COACHMAN PALM ",side," ",error)
  assert(error < .04)
 for side in ["l","r"]:
  var foot: int = driver._skeleton.find_bone("foot_"+side)
  var ankle: Vector3 = driver._skeleton.to_global(driver._skeleton.get_bone_global_pose(foot).origin)
  var error: float = ankle.distance_to(driver.foot_target_world(side))
  print("MAKEHUMAN COACHMAN ANKLE ",side," ",error)
  assert(error < .02)
 cart.boarding.set_physics_process(false)
 var results: Array[Dictionary] = []
 for state in [{"name":"idle","acceleration":0.0,"turn":0.0},{"name":"accelerating","acceleration":4.0,"turn":0.0},{"name":"turning","acceleration":0.0,"turn":1.0},{"name":"braking","acceleration":-4.0,"turn":0.0}]:
  if "--idle" in OS.get_cmdline_user_args() and state.name != "idle": continue
  cart.boarding.rider_acceleration = state.acceleration
  cart.boarding.rider_turn = state.turn
  for tick in 90: await process_frame
  var report: Dictionary = _audit(driver,cart)
  report["state"] = state.name
  results.append(report)
 var failures: Array[String] = []
 for result in results:
  if result.minimum_signed_skin_m < .008 or result.seat_vertices != 0 or result.rein_surface_m < .015:
   failures.append(str(result.state))
 FileAccess.open("res://docs/world/coachman_clearance_validation.json",FileAccess.WRITE).store_string(JSON.stringify({"status":"PASS" if failures.is_empty() else "FAIL","scope":"posed body triangles; garment vertices; cushion box; sampled rein segments; four isolated driving poses","results":results,"failures":failures},"\t"))
 print("COACHMAN GARMENT/SKIN/SEAT/REIN ","PASS" if failures.is_empty() else "FAIL",failures)
 quit(0 if failures.is_empty() else 1)
func _audit(driver: Node3D,cart: Node3D) -> Dictionary:
 return preload("res://vehicles/coachman_clearance.gd").new().audit_garment(driver,cart)
