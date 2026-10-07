extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
 root.size=Vector2i(1280,720)
 var stage:=Node3D.new();root.add_child(stage)
 var env:=WorldEnvironment.new();env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.16,.17,.19)
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.5;stage.add_child(env)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-25,0);stage.add_child(light)
 var camera:=Camera3D.new();camera.position=Vector3(0,1.0,3.4);camera.fov=35;stage.add_child(camera);camera.look_at(Vector3(0,.85,0));camera.current=true
 var slug:="village_farmer" if OS.get_cmdline_user_args().is_empty() else OS.get_cmdline_user_args()[0]
 var actor:=Node3D.new();actor.set_script(load("res://characters/npcs/indian/indian_npc_candidate.gd"));actor.set("candidate_slug",slug);stage.add_child(actor);actor.set_process(false)
 var folder:=OS.get_environment("TLM_CLOTHING_TEST_OUTPUT")
 if folder.is_empty(): push_error("Set TLM_CLOTHING_TEST_OUTPUT to a temporary directory");quit(1);return
 DirAccess.make_dir_recursive_absolute(folder)
 actor.set_process(true)
 for clip in ["idle","walk","idle"]:
  actor.set("walking",clip=="walk")
  for sample in 5:
   await create_timer(.3,true,false,true).timeout
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(folder+"/%s_%s_%02d.png"%[slug,clip,sample])
 print("VILLAGE_CLOTHING_CAPTURE ",slug)
 quit()
