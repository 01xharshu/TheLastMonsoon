extends SceneTree
func _initialize() -> void:
 call_deferred("capture")
func capture() -> void:
 root.size=Vector2i(1280,720)
 var stage:=Node3D.new();root.add_child(stage)
 var environment:=WorldEnvironment.new();environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.16,.17,.19)
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.4
 stage.add_child(environment)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-30,0);light.light_energy=1.2;light.shadow_enabled=true;stage.add_child(light)
 var ground:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(15,15);ground.mesh=plane;stage.add_child(ground)
 var camera:=Camera3D.new();camera.position=Vector3(0,.95,3.6);camera.fov=34;stage.add_child(camera);camera.look_at(Vector3(0,.85,0));camera.current=true
 var paths:Dictionary={"arjun":"characters/arjun/arjun.glb","farmer":"characters/npcs/motion/village_farmer/village_farmer_rigged_candidate.glb","river_woman":"characters/npcs/motion/river_woman/river_woman_rigged_candidate.glb","british":"characters/npcs/british/sergeant_man.glb","household":"characters/npcs/households/landowner.glb","police":"characters/npcs/thana/daroga_motion.glb","street":"characters/npcs/street_residents/merchant.glb","dev":"characters/npcs/dev/dev_idle_candidate.glb"}
 for label in paths:
  var actor:=load("res://"+paths[label]).instantiate() as Node3D;stage.add_child(actor)
  for frame in 3:await process_frame
  RenderingServer.force_draw(false)
  var path:String="res://docs/characters/npcs/whole_body_"+label+".png"
  var result:=root.get_texture().get_image().save_png(path)
  print("WHOLE_BODY_CAPTURE ",label," ",result)
  stage.remove_child(actor);actor.queue_free()
 quit()
