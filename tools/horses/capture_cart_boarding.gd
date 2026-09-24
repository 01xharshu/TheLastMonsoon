extends SceneTree
func _initialize() -> void: _run.call_deferred()
func capture(label: String) -> void:
 await create_timer(.3).timeout
 await RenderingServer.frame_post_draw
 var image := root.get_texture().get_image()
 assert(image.save_png("res://docs/world/captures/cart_arjun_"+label+".png") == OK)
func _run() -> void:
 root.size = Vector2i(1280,720)
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
 var mesh := MeshInstance3D.new()
 var ground := BoxMesh.new()
 ground.size = Vector3(30,.2,30)
 mesh.mesh = ground
 floor.add_child(mesh)
 world.add_child(floor)
 var sun := DirectionalLight3D.new()
 sun.rotation = Vector3(-.9,.4,0)
 sun.light_energy = 1.8
 world.add_child(sun)
 var cart: Node3D = load("res://vehicles/family_carriage_candidate.gd").new()
 world.add_child(cart)
 var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
 actor.position = Vector3(2,1,2.2)
 world.add_child(actor)
 var camera := Camera3D.new()
 camera.position = Vector3(5,3.1,-.8)
 world.add_child(camera)
 camera.look_at(Vector3(0,1.9,1.1))
 camera.current = true
 await create_timer(.3).timeout
 assert(cart.board_at(actor,"CoachmanSeat","driver"))
 await capture("driver")
 assert(cart.boarding.dismount())
 actor.global_position = Vector3(2,1,2.2)
 assert(cart.board_at(actor,"RearPassengerRight","passenger"))
 cart.visual_root.get_node("Roof").visible = false
 cart.visual_root.get_node("InteriorCeilingLiner").visible = false
 camera.position = Vector3(.1,5.2,2.9)
 camera.look_at(Vector3(0,1.9,2.8))
 await capture("passenger_cutaway")
 print("CART ARJUN METAL CAPTURE: PASS")
 quit()
