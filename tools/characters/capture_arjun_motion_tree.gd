extends SceneTree
# Isolated Metal/Forward+ pose captures of the temporary gameplay rig.
func _initialize() -> void:
 _run.call_deferred()
func _run() -> void:
 var stage := Node3D.new()
 root.add_child(stage)
 current_scene = stage
 var environment := WorldEnvironment.new()
 var env := Environment.new()
 env.background_mode = Environment.BG_COLOR
 env.background_color = Color(0.22,0.25,0.24)
 env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color = Color(0.8,0.8,0.78)
 env.ambient_light_energy = 0.75
 environment.environment = env
 stage.add_child(environment)
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-40,-30,0)
 sun.light_energy = 1.8
 stage.add_child(sun)
 var ground := MeshInstance3D.new()
 var plane := PlaneMesh.new()
 plane.size = Vector2(8,8)
 ground.mesh = plane
 ground.position.y = -0.38
 stage.add_child(ground)
 var model = load("res://characters/arjun/arjun.glb").instantiate()
 stage.add_child(model)
 var tree: AnimationTree = load("res://player/arjun_motion_tree.gd").new()
 model.add_child(tree)
 if not tree.configure(model):
  quit(1)
  return
 var camera := Camera3D.new()
 stage.add_child(camera)
 camera.position = Vector3(0,1.0,2.7)
 camera.look_at(Vector3(0,0.0,0))
 camera.make_current()
 for sample in [["idle",0.0,false],["walk_a",1.0,false],["walk_b",1.0,false],["walk_side",1.0,false],["swim",1.0,true]]:
  camera.position = Vector3(2.7,1.0,0.0) if sample[0] == "walk_side" else Vector3(0,1.0,2.7)
  camera.look_at(Vector3(0,0,0))
  for i in (15 if sample[0] != "walk_b" else 18):
   tree.update_motion(1.0/30.0,sample[1],sample[1],sample[2])
  model.position.y = -tree.foot_contact_offset
  for i in 3: await process_frame
  await RenderingServer.frame_post_draw
  var path = "res://docs/characters/arjun/animation_tree_"+sample[0]+".png"
  print("CAPTURE ",path," ",root.get_texture().get_image().save_png(path))
 quit()
