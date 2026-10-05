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
 cart.boarding.travel.show_menu()
 var camera := Camera3D.new()
 world.add_child(camera)
 camera.global_position = bridge.global_position+Vector3(6,bridge.deck_height+5,8)
 camera.look_at(cart.global_position+Vector3.UP)
 camera.make_current()
 await process_frame
 RenderingServer.force_draw(false)
 assert(root.get_texture().get_image().save_png("res://docs/world/captures/paid_coach_destination.png")==OK)
 print("PAID COACH METAL CAPTURE PASS")
 quit()
