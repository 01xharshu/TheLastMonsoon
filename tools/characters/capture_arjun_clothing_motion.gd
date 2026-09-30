extends SceneTree
# Run with Metal/Forward+ and --fixed-fps 30. Captures the real player moving
# on a physical floor; the temporary Arjun appearance is not approved.
func _initialize() -> void:
 root.size = Vector2i(1280,720)
 _run.call_deferred()
func _run() -> void:
 if DisplayServer.get_name() == "headless":
  push_error("ARJUN WALK CAPTURE requires a rendered display")
  quit(1)
  return
 var stage := Node3D.new()
 root.add_child(stage)
 current_scene = stage
 var clock := Node.new()
 clock.name = "GameTimeSystem"
 clock.set_script(load("res://world/suryagarh/systems/game_time_system.gd"))
 stage.add_child(clock)
 var floor := StaticBody3D.new()
 stage.add_child(floor)
 var shape := CollisionShape3D.new()
 var box := BoxShape3D.new()
 box.size = Vector3(30,0.4,30)
 shape.shape = box
 shape.position.y = -0.2
 floor.add_child(shape)
 var plane := MeshInstance3D.new()
 var mesh := PlaneMesh.new()
 mesh.size = Vector2(30,30)
 plane.mesh = mesh
 floor.add_child(plane)
 var env := WorldEnvironment.new()
 var e := Environment.new()
 e.background_mode = Environment.BG_COLOR
 e.background_color = Color(0.23,0.27,0.25)
 e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 e.ambient_light_color = Color(0.7,0.7,0.7)
 env.environment = e
 stage.add_child(env)
 var light := DirectionalLight3D.new()
 light.rotation_degrees = Vector3(-45,-25,0)
 light.light_energy = 2.0
 stage.add_child(light)
 var actor: CharacterBody3D = load("res://player/player.tscn").instantiate()
 stage.add_child(actor)
 actor.global_position = Vector3(0,1,0)
 actor.get_node("UI").hide()
 var camera := Camera3D.new()
 stage.add_child(camera)
 camera.position = Vector3(4,1.4,2)
 camera.look_at(Vector3(0,0.8,0))
 camera.make_current()
 for i in 30: await physics_frame
 camera.make_current()
 var visual = actor.get_node("VisualRoot/CharacterVisual")
 var clothes = visual.get_node("Clothing")
 var diagnostic_load := Node3D.new()
 clothes.mount_item(diagnostic_load, "back_upper")
 DirAccess.make_dir_recursive_absolute("/tmp/arjun_clothing_motion_frames")
 for i in 120:
  if i == 0: Input.action_press("move_forward")
  if i == 40: Input.action_press("sprint")
  if i == 80:
   Input.action_release("move_forward")
   Input.action_release("sprint")
  await physics_frame
  camera.global_position = actor.global_position + Vector3(1.45,.72,1.35)
  camera.look_at(actor.global_position + Vector3(0,.1,0))
  camera.make_current()
  await RenderingServer.frame_post_draw
  var frame := root.get_texture().get_image()
  frame.resize(1280,720)
  var path := "/tmp/arjun_clothing_motion_frames/frame_%04d.png" % i
  assert(frame.save_png(path) == OK)
  if i in [20,60,119]:
   assert(frame.save_png("res://docs/characters/arjun/clothing_2026-09-30/motion_%03d.png" % i) == OK)
   print("CLOTH MOTION ",i," speed=",actor.velocity.length()," fabric=",clothes.fabric_sway)
 Input.action_release("move_forward")
 Input.action_release("sprint")
 print("CLOTH MOTION: complete walk/run/settle sequence")
 quit()
