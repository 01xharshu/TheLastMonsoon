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
 var clothing = load("res://player/arjun_clothing.gd").new()
 model.add_child(clothing)
 clothing.set_process(false)
 clothing.setup(model, model.find_children("*", "Skeleton3D", true, false)[0])
 var tree: AnimationTree = load("res://player/arjun_motion_tree.gd").new()
 model.add_child(tree)
 if not tree.configure(model):
  quit(1)
  return
 var camera := Camera3D.new()
 stage.add_child(camera)
 camera.position = Vector3(0,1.05,1.55)
 camera.look_at(Vector3(0,.75,0))
 camera.make_current()
 var label := "dry"
 if not OS.get_cmdline_user_args().is_empty(): label = OS.get_cmdline_user_args()[0]
 clothing.shoulder.visible = label in ["strap", "run"]
 clothing.shoulder_stitches.visible = clothing.shoulder.visible
 for material in clothing.materials: material.set_shader_parameter("wetness", 1.0 if label == "wet" else 0.0)
 for frame in 30: tree.update_motion(1.0/30.0, 1.75 if label == "run" else 0.0, 0.0, false)
 model.position.y = -tree.foot_contact_offset
 camera.position = Vector3(1.6,1.05,0) if label == "run" else Vector3(0,1.05,1.55)
 camera.look_at(Vector3(0,.75,0))
 for frame in 3: await process_frame
 await RenderingServer.frame_post_draw
 var path := "res://docs/characters/arjun/clothing_2026-09-30/" + label + ".png"
 print("CLOTHING CAPTURE ", label, " ", root.get_texture().get_image().save_png(path))
 quit()
