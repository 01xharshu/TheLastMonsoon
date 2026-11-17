extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var stage:=Node3D.new();root.add_child(stage);current_scene=stage
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.23,.26,.29);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.8;stage.add_child(env)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-20,0);stage.add_child(light)
 var camera:=Camera3D.new();stage.add_child(camera);camera.current=true;camera.fov=40
 var folder:=OS.get_environment("TLM_CANDIDATE_OUTPUT");var count:=0
 for slug in ["female_01","female_02","female_03","female_04","female_05","female_06","male_01","male_02","male_03","male_04"]:
  var actor:=preload("res://characters/npcs/indian/indian_street_actor.gd").new()
  actor.movement_enabled=false;actor.movement_profile=&"female" if slug.begins_with("female") else &"male"
  actor.ground_height=func(_x:float,_z:float)->float:return 0.0
  if slug.begins_with("female"):
   actor.set_meta("sari_hem_height_m",.08);actor.set_meta("sari_arm_clearance_rad",.12);actor.set_meta("sari_hem_radius_m",.205);actor.set_meta("sari_fold_depth_m",.008)
  var packed:PackedScene=load("res://characters/npcs/indian_body_candidates/"+slug+".glb")
  if packed==null:push_error("Missing candidate "+slug);quit(1);return
  actor.add_child(packed.instantiate());stage.add_child(actor);actor.set_process(false);actor.set_physics_process(false)
  await process_frame;actor._set_animation(&"idle",0.0);actor.drape.update()
  camera.position=Vector3(0,1.05,3.2);camera.look_at(Vector3(0,.9,0));await process_frame;RenderingServer.force_draw(false)
  root.get_texture().get_image().save_png(folder+"/"+slug+".png")
  camera.position=Vector3(.18,1.46,1.4);camera.look_at(Vector3(0,1.36,0));camera.fov=34;await process_frame;RenderingServer.force_draw(false)
  root.get_texture().get_image().save_png(folder+"/"+slug+"_face.png");camera.fov=40
  actor.hide();await process_frame;count+=1
 await process_frame;RenderingServer.force_draw(false)
 print("INDIAN_CANDIDATE_LINEUP ",count);quit()
