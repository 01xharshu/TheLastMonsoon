extends SceneTree
func _initialize():
 run.call_deferred()
func run():
 var populated := OS.get_cmdline_user_args().has("--world")
 var stage: Node3D
 var station: Node3D
 var actor: CharacterBody3D
 if populated:
  stage = load(root.get_node("SaveManager").WORLD).instantiate()
  root.add_child(stage)
  current_scene = stage
  for frame in 600:
   if stage.get_node_or_null("AbandonedCarts") != null: break
   await process_frame
  await process_frame
  station = stage.get_node_or_null("BhairavpurTimberSwingStation")
  actor = stage.get_node_or_null("Player")
  if station == null or actor == null:
   push_error("SWING FAIL populated world is missing its timber station or player")
   root.get_node("SaveManager").quit_game(1)
   return
  if get_nodes_in_group("traversal_swing_bars").filter(
       func(bar: Node) -> bool: return bar.get_parent() == station).size() != 2:
   push_error("SWING FAIL populated station does not own two bars")
   root.get_node("SaveManager").quit_game(1)
   return
 else:
  stage=Node3D.new()
  root.add_child(stage)
  current_scene=stage
  var clock=load("res://world/suryagarh/systems/game_time_system.gd").new()
  clock.name="GameTimeSystem"
  stage.add_child(clock)
  var floor=StaticBody3D.new()
  var collider=CollisionShape3D.new()
  var box=BoxShape3D.new()
  box.size=Vector3(30,.2,30)
  collider.shape=box
  floor.position.y=-.1
  floor.add_child(collider)
  stage.add_child(floor)
  station=load("res://world/suryagarh/timber_swing_station.gd").new()
  stage.add_child(station)
  actor=load("res://player/player.tscn").instantiate()
  stage.add_child(actor)
 var output := OS.get_environment("TLM_STORY_TEST_DIR")
 var camera: Camera3D
 if DisplayServer.get_name() != "headless" and DirAccess.dir_exists_absolute(output):
  camera = Camera3D.new()
  stage.add_child(camera)
  camera.position = station.to_global(Vector3(4, 2.4, -2.5))
  camera.look_at_from_position(camera.position, station.to_global(Vector3(0,1.65,0)))
  camera.make_current()
  if not populated:
   var sun := DirectionalLight3D.new()
   sun.rotation_degrees = Vector3(-50, -35, 0)
   stage.add_child(sun)
 actor.global_position = station.to_global(Vector3(0,.94,-.75))
 actor.velocity = Vector3.ZERO
 print("SWING STATION mode=", "world" if populated else "fixture", " at=", station.global_position)
 for i in 50:await physics_frame
 if camera != null:
  camera.look_at_from_position(station.to_global(Vector3(7, 3.3, -5)), station.to_global(Vector3(0, 1.3, 3.2)))
  await capture(camera, output, "approach")
  camera.look_at_from_position(station.to_global(Vector3(3.3, 2.6, -1.2)), station.to_global(Vector3(0, 1.9, 0)))
 actor.visual_root.global_rotation.y=0
 var climb=actor.get_node("ClimbComponent")
 if populated:
  var jump_height: float = actor.jump_velocity * actor.jump_velocity / (2.0 * actor.gravity)
  var ceiling := KinematicCollision3D.new()
  var blocked := actor.test_move(actor.global_transform, Vector3.UP * jump_height, ceiling)
  print("SWING APPROACH floor=",actor.is_on_floor()," physics=",actor.is_physics_processing(),
    " stationary_jump=",preload("res://player/contextual_jump.gd").new().available(actor, actor.visual_root.global_basis.z, actor.max_walk_step_height, jump_height),
    " blocked=",blocked," obstacle=",ceiling.get_collider() if blocked else null," wet=",actor.is_swimming)
 var top_y: float = actor.global_position.y
 await press_jump()
 for i in 40:
  await physics_frame
  top_y = maxf(top_y, actor.global_position.y)
  if is_instance_valid(climb.swing.bar):break
 if not is_instance_valid(climb.swing.bar):
  print("SWING FAIL no grab ",actor.position," ",actor.velocity," jump_apex=",top_y)
  root.get_node("SaveManager").quit_game(1)
  return
 var start:Vector3=actor.position
 var palm_gap := 0.0
 for i in 18:
  await process_frame
  if i >= 8:
   var visual = actor.get_node("VisualRoot/CharacterVisual")
   var span: Vector3 = visual.visual_bar_right(climb.swing.bar)
   for side in ["l", "r"]:
    var hand: Transform3D = visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("hand_" + side))
    var palm: Vector3 = visual.skeleton.to_global(hand * visual.equipment.palm_offsets[side])
    var target: Vector3 = climb.swing.bar.global_position + span * (.25 if side == "r" else -.25)
    palm_gap = maxf(palm_gap, palm.distance_to(target))
 if camera != null:
  await capture(camera, output, "bar-swing")
 var moved:bool=actor.position.distance_to(start)>.25
 await press_jump()
 var released:bool=not is_instance_valid(climb.swing.bar) and not actor.get_meta("climbing",false) and climb.catch_seconds>0
 var first = climb.swing.last_bar
 for i in 40:
  await physics_frame
  if is_instance_valid(climb.swing.bar):break
 var chained:bool=is_instance_valid(climb.swing.bar) and climb.swing.bar != first
 for i in 25:await physics_frame
 await press_jump()
 for i in 60:
  await physics_frame
  if climb.active and not is_instance_valid(climb.swing.bar):break
 var ledge:bool=climb.active and not is_instance_valid(climb.swing.bar) and climb.window.active
 for i in 150:
  await physics_frame
  if not climb.active and actor.is_on_floor():break
 var landed: bool = actor.is_on_floor() and station.to_local(actor.global_position).y > 3.0
 if landed and camera != null:
  camera.look_at_from_position(station.to_global(Vector3(5, 3.6, 2.5)), station.to_global(Vector3(0, 2.0, 5.8)))
  await capture(camera, output, "platform")
 print("SWING RESULT moved=",moved," released=",released," second_bar=",chained," ledge=",ledge," landed=",landed," palm_gap=",palm_gap)
 root.get_node("SaveManager").quit_game(0 if moved and released and chained and ledge and landed and palm_gap < .12 else 1)


func press_jump() -> void:
 await process_frame
 var event := InputEventAction.new()
 event.action = "jump"
 event.pressed = true
 event.strength = 1.0
 Input.parse_input_event(event)
 Input.flush_buffered_events()
 for tick in 3: await physics_frame
 var release := InputEventAction.new()
 release.action = "jump"
 Input.parse_input_event(release)
 Input.flush_buffered_events()

func capture(camera: Camera3D, output: String, label: String) -> void:
 camera.make_current()
 await RenderingServer.frame_post_draw
 var result := root.get_texture().get_image().save_png(output.path_join(label + ".png"))
 if result != OK:
  push_error("Unable to capture swing frame " + label)
