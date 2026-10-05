extends SceneTree
var review_actor: CharacterBody3D
var review_camera: Camera3D
var review_cart: Node3D
var failures: Array[String] = []
func _initialize() -> void: _run.call_deferred()
func capture(label: String) -> void:
 await create_timer(.3).timeout
 await process_frame
 review_camera.make_current()
 review_actor.get_node("UI").hide()
 RenderingServer.force_draw(false)
 var flexible: Node3D = review_cart.get_node("FlexibleReins")
 if flexible.reins.size() != 2: failures.append(label+" two flexible reins")
 for entry in flexible.reins:
  var points: Array = entry.points
  var pins: Array[Vector3] = entry.rendered_pins
  var chord: Vector3 = pins[0].lerp(pins[1],.5)
  var sag: float = chord.y-(points[flexible.SEGMENTS/2] as Vector3).y
  var error: float = maxf((points[0] as Vector3).distance_to(pins[0]),(points[-1] as Vector3).distance_to(pins[1]))
  print(label," ",entry.side," rein sag=",sag,"m endpoint=",error,"m")
  if sag < .02: failures.append(label+" rein sag")
  if error > .015: failures.append(label+" rein endpoint")
 var visual: Node3D = review_actor.get_node("VisualRoot/CharacterVisual")
 var rig: Skeleton3D = visual.skeleton
 for side in ["l","r"]:
  var palm := rig.to_global(rig.get_bone_global_pose(rig.find_bone("hand_"+side))*visual.equipment.palm_offsets[side])
  var error := palm.distance_to(review_cart.rein_grip_world(side))
  var shoulder := rig.get_bone_global_pose(rig.find_bone("upperarm_"+side)).origin
  var elbow := rig.get_bone_global_pose(rig.find_bone("lowerarm_"+side)).origin
  var wrist := rig.get_bone_global_pose(rig.find_bone("hand_"+side)).origin
  var angle := rad_to_deg(acos(clampf((shoulder-elbow).normalized().dot((wrist-elbow).normalized()),-1.0,1.0)))
  print(label," ",side," palm=",error,"m elbow=",angle,"deg")
  if error >= .03: failures.append(label+" "+side+" palm reach")
  if angle >= 170.0 or angle <= 20.0: failures.append(label+" "+side+" elbow bend")
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
 review_cart = cart
 var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
 actor.position = Vector3(2,1,2.2)
 world.add_child(actor)
 review_actor = actor
 var camera := Camera3D.new()
 review_camera = camera
 camera.position = Vector3(5,3.1,-.8)
 world.add_child(camera)
 camera.look_at(Vector3(0,1.9,1.1))
 camera.current = true
 actor.get_node("CameraPivot/SpringArm3D/Camera3D").set_process(false)
 actor.visual_root.show()
 await create_timer(.3).timeout
 assert(cart.board_at(actor,"CoachmanSeat","driver"))
 await create_timer(cart.boarding.TRANSITION_SECONDS+.2).timeout
 camera.position = Vector3(2.6,2.8,-.8)
 camera.look_at(Vector3(0,1.97,.65))
 await capture("rein_grip_idle")
 Input.action_press("move_forward")
 Input.action_press("move_left")
 await create_timer(.8).timeout
 camera.global_position = cart.to_global(Vector3(2.6,2.8,-.8))
 camera.look_at(cart.to_global(Vector3(0,1.97,.65)))
 await capture("rein_grip_turn")
 Input.action_release("move_forward")
 Input.action_release("move_left")
 assert(cart.boarding.dismount())
 await create_timer(cart.boarding.TRANSITION_SECONDS+.2).timeout
 cart.queue_free()
 await process_frame
 for kind in 2:
  var trial: Node3D = load("res://vehicles/horse_cart_candidate.gd").new()
  trial.variant = kind
  world.add_child(trial)
  review_cart = trial
  actor.global_position = Vector3(-1,1,1.7)
  assert(trial.board_at(actor,"DriverSeat","driver"))
  await create_timer(trial.boarding.TRANSITION_SECONDS+.2).timeout
  var grip: Vector3 = (trial.rein_grip_world("l")+trial.rein_grip_world("r"))*.5
  camera.global_position = grip+Vector3(1.8,.65,-1.0)
  camera.look_at(grip)
  await capture("rein_grip_variant_"+str(kind))
  assert(trial.boarding.dismount())
  await create_timer(trial.boarding.TRANSITION_SECONDS+.2).timeout
  trial.queue_free()
  await process_frame
 print("CART REIN GRIP ","PASS" if failures.is_empty() else "FAIL", " ", failures)
 quit(0 if failures.is_empty() else 1)
