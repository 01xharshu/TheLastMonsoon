extends SceneTree
# Run with Metal/Forward+ and --fixed-fps 30. Captures the real player moving
# on a physical floor; the temporary Arjun appearance is not approved.
func _initialize() -> void:
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
 var skeleton: Skeleton3D = visual.skeleton
 var l := skeleton.find_bone("foot_l")
 var r := skeleton.find_bone("foot_r")
 var idle_y := minf((skeleton.global_transform * skeleton.get_bone_global_pose(l)).origin.y,(skeleton.global_transform * skeleton.get_bone_global_pose(r)).origin.y)
 print("IDLE foot_y=",idle_y," actor=",actor.global_position," floor=",actor.is_on_floor())
 Input.action_press("move_forward")
 var min_delta := INF
 var max_delta := -INF
 for i in 90:
  await physics_frame
  camera.global_position = actor.global_position + Vector3(4,1.4,2)
  camera.look_at(actor.global_position + Vector3(0,0.8,0))
  camera.make_current()
  if i in [15,45,75]:
   var path := "res://docs/characters/arjun/animation_tree_live_%02d.png" % i
   var error := root.get_texture().get_image().save_png(path)
   print("ARJUN WALK CAPTURE ",i," ",error," ",path)
   if error != OK:
    Input.action_release("move_forward")
    quit(1)
    return
  var y := minf((skeleton.global_transform * skeleton.get_bone_global_pose(l)).origin.y,(skeleton.global_transform * skeleton.get_bone_global_pose(r)).origin.y)
  min_delta = minf(min_delta,y-idle_y)
  max_delta = maxf(max_delta,y-idle_y)
 Input.action_release("move_forward")
 print("ARJUN WALK CAPTURE: PASS | distance=",actor.global_position.distance_to(Vector3(0,1,0))," foot_delta=",min_delta,"..",max_delta," speed=",Vector2(actor.velocity.x,actor.velocity.z).length())
 quit()
