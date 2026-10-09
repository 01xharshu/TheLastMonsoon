extends SceneTree

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
 var world := Node3D.new()
 root.add_child(world)
 var time := Node.new()
 time.name = "GameTimeSystem"
 time.set_script(load("res://world/suryagarh/systems/game_time_system.gd"))
 world.add_child(time)
 var floor := StaticBody3D.new()
 var shape := CollisionShape3D.new()
 var box := BoxShape3D.new()
 box.size = Vector3(2000,.2,2000)
 shape.shape = box
 floor.position.y = -.1
 floor.add_child(shape)
 world.add_child(floor)
 var evidence: Array = []
 var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
 world.add_child(actor)
 actor.get_node("UI").hide()
 for kind in 3:
  var cart: Node3D = load("res://vehicles/family_carriage_candidate.gd" if kind == 2 else "res://vehicles/horse_cart_candidate.gd").new()
  if kind < 2: cart.variant = kind
  world.add_child(cart)
  actor.global_position = Vector3(2,1,2)
  await create_timer(.1).timeout
  assert(cart.board_at(actor,"CoachmanSeat" if kind == 2 else "DriverSeat","driver"))
  await create_timer(1.4).timeout
  Input.action_press("move_forward")
  for i in 150: await physics_frame
  var start: Vector3 = cart.global_position
  for i in 60: await physics_frame
  var cruise: float = cart.global_position.distance_to(start)
  assert(cruise > actor.sprint_speed * 1.35, "Cruise must clearly beat running")
  Input.action_press("sprint")
  for i in 90: await physics_frame
  start = cart.global_position
  for i in 60: await physics_frame
  var fast: float = cart.global_position.distance_to(start)
  assert(fast > actor.sprint_speed * 2.0, "Fast cart must exceed twice running speed")
  var previous_rate := 0.0
  var maximum_step := 0.0
  Input.action_press("move_left")
  for frame in 120:
   var heading: float = cart.rotation.y
   await physics_frame
   var step := absf(angle_difference(heading, cart.rotation.y))
   maximum_step = maxf(maximum_step, step)
   assert(step < .0101, "Steering exceeded continuous turn limit")
   assert(absf(cart.boarding.turning_rate - previous_rate) < .021, "Steering acceleration snapped")
   previous_rate = cart.boarding.turning_rate
  assert(cart.boarding.turning_rate > .40, "Sustained left input did not turn")
  Input.action_release("move_left")
  Input.action_press("move_right")
  for frame in 120:
   await physics_frame
   assert(absf(cart.boarding.turning_rate - previous_rate) < .021, "Reversal snapped")
   previous_rate = cart.boarding.turning_rate
  assert(cart.boarding.turning_rate < -.40, "Sustained right input did not reverse turn")
  Input.action_release("move_right")
  for frame in 60: await physics_frame
  assert(absf(cart.boarding.turning_rate) < .001, "Released steering did not settle")
  print("CART TURN PASS kind=",kind," maximum fast heading step=",maximum_step)
  Input.action_release("sprint")
  Input.action_release("move_forward")
  for frame in 180: await physics_frame
  assert(cart.boarding.speed == 0.0 and cart.boarding.turning_rate == 0.0, "Stopped cart retained turning")
  cart.rotation.y = 0.0
  var blocker := StaticBody3D.new()
  var blocker_shape := CollisionShape3D.new()
  var blocker_box := BoxShape3D.new()
  blocker_box.size = Vector3(8,3,1)
  blocker_shape.shape = blocker_box
  blocker.add_child(blocker_shape)
  world.add_child(blocker)
  blocker.global_position = cart.global_position + Vector3(0,1.5,-8)
  start = cart.global_position
  Input.action_press("move_forward")
  Input.action_press("sprint")
  for i in 90: await physics_frame
  assert(cart.global_position.distance_to(start) < 5.0 and cart.boarding.speed == 0.0, "Fast cart must stop before obstacle")
  Input.action_release("move_forward")
  Input.action_release("sprint")
  assert(cart.boarding.dismount())
  await create_timer(1.4).timeout
  evidence.append({"variant":kind,"cruise_m_s":cruise,"fast_m_s":fast,"walking_m_s":actor.walk_speed,"running_m_s":actor.sprint_speed,"obstacle_stopped":true})
  print("CART SPEED PASS kind=",kind," cruise=",cruise," fast=",fast," walk=",actor.walk_speed," run=",actor.sprint_speed," obstacle stopped")
  blocker.queue_free()
  cart.queue_free()
  await process_frame
 print("HORSE VEHICLE SPEED: PASS")
 quit()
