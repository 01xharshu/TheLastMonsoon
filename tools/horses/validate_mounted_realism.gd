extends SceneTree
func _initialize() -> void: _run.call_deferred()
var review_horse: Node3D
var review_camera: Camera3D
func capture(label: String) -> void:
 await create_timer(.3).timeout
 if is_instance_valid(review_horse):
  review_camera.global_position = review_horse.global_position + Vector3(3.2,2.45,0.2)
  review_camera.look_at(review_horse.global_position + Vector3.UP*1.7)
  var visual: Node3D = review_horse.rider.get_node("VisualRoot/CharacterVisual")
  var skeleton: Skeleton3D = visual.skeleton
  var palm_error := 0.0
  var foot_error := 0.0
  for side in ["l", "r"]:
   var hand := skeleton.get_bone_global_pose(skeleton.find_bone("hand_"+side))
   var palm: Vector3 = skeleton.to_global(hand*visual.equipment.palm_offsets[side])
   palm_error = maxf(palm_error,palm.distance_to(review_horse.riding_rein_world(side)))
   var foot := skeleton.to_global(skeleton.get_bone_global_pose(skeleton.find_bone("foot_"+side)).origin + Vector3(0,-.085,.06))
   foot_error = maxf(foot_error,foot.distance_to(review_horse.stirrup_world(side)))
  print(label, " palm error=", snappedf(palm_error,.001), "m sole error=", snappedf(foot_error,.001), "m")
  assert(palm_error < .08, "rider palms stay on reins")
  assert(foot_error < .04, "rider soles stay on stirrups")
 await process_frame
 RenderingServer.force_draw(false)
 if DisplayServer.get_name() == "headless": return
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
 box.size = Vector3(120,.2,120)
 collision.shape = box
 floor.add_child(collision)
 var mesh := MeshInstance3D.new()
 var ground := BoxMesh.new()
 ground.size = Vector3(120,.2,120)
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
 review_camera = camera
 actor.get_node("UI").hide()
 await create_timer(.3).timeout
 assert(cart.board_at(actor,"CoachmanSeat","driver"))
 await capture("driver")
 Input.action_press("move_forward")
 Input.action_press("sprint")
 await create_timer(2.8).timeout
 assert(cart.boarding.speed > 4.0)
 Input.action_release("move_forward")
 Input.action_release("sprint")
 assert(cart.boarding.dismount())
 cart.queue_free()
 await process_frame
 var horse: CharacterBody3D = load("res://horses/stable_horse.gd").new()
 world.add_child(horse)
 review_horse = horse
 await create_timer(.5).timeout
 actor.global_position = horse.global_position + Vector3(1.2,1,0)
 assert(horse.board(actor))
 await create_timer(1.0).timeout
 camera.position = horse.global_position + Vector3(4,2.8,3)
 camera.look_at(horse.global_position + Vector3.UP*1.5)
 await capture("horse_seated_refinement")
 Input.action_press("move_forward")
 Input.action_press("sprint")
 await create_timer(1.7).timeout
 assert(horse.pace > 9.0)
 camera.position = horse.global_position + Vector3(4,2.8,3)
 camera.look_at(horse.global_position + Vector3.UP*1.5)
 await capture("horse_gallop_refinement")
 Input.action_press("jump")
 await physics_frame
 Input.action_release("jump")
 await create_timer(.2).timeout
 assert(not horse.is_on_floor())
 camera.position = horse.global_position + Vector3(4,2.8,3)
 camera.look_at(horse.global_position + Vector3.UP*1.5)
 await capture("horse_jump_refinement")
 Input.action_release("move_forward")
 Input.action_release("sprint")
 await create_timer(1.2).timeout
 assert(horse.landing_events > 0)
 assert(horse.rider_landing < .1)
 print("MOUNTED REALISM: PASS | cart sprint, horse gallop, jump, landing recovery")
 quit()
