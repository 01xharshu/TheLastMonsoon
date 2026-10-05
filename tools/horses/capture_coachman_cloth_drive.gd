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
 actor.inventory.add_item("rupees",2)
 assert(cart.boarding.travel.request_trip("Police Station"))
 cart.boarding.travel.close_skip()
 var initial: Vector3 = cart.global_position
 for tick in 300:
  await physics_frame
  camera.global_position = cart.to_global(Vector3(2.3,2.8,-.5))
  camera.look_at(cart.to_global(Vector3(0,2.2,.90)))
 await process_frame
 RenderingServer.force_draw(false)
 assert(root.get_texture().get_image().save_png("res://docs/world/captures/coachman_cloth_moving_bridge.png")==OK)
 assert(cart.global_position.distance_to(initial) > 25.0)
 assert(driver.seated_cloth.pieces.size() == 2)
 for side in ["l","r"]:
  assert(driver.palm_world(side).distance_to(cart.rein_grip_world(side)) < .02)
  var ankle: Vector3 = driver._skeleton.to_global(driver._skeleton.get_bone_global_pose(driver._skeleton.find_bone("foot_"+side)).origin)
  assert(ankle.distance_to(driver.foot_target_world(side)) < .02)
 print("COACHMAN CLOTH MOVING BRIDGE METAL PASS | distance=",cart.global_position.distance_to(initial)," cloth_updates=",driver.seated_cloth.updates)
 quit()
