extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var scene:=Node3D.new();root.add_child(scene);current_scene=scene
 var camera:=Camera3D.new();scene.add_child(camera);camera.position=Vector3(6,3,8);camera.look_at(Vector3(0,2,0));camera.current=true
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.16,.20,.24);scene.add_child(env)
 var source:=Node3D.new();scene.add_child(source)
 var smoke:=preload("res://world/suryagarh/settlements/village_combustion.gd").make_smoke(source)
 assert(not smoke.local_coords and smoke.amount==26 and smoke.color_ramp.sample(1).a==0)
 smoke.emitting=true;smoke.preprocess=4
 var cloud:=preload("res://combat/escape_smoke.gd").new();scene.add_child(cloud);cloud.position=Vector3(3,0,0)
 assert(preload("res://combat/escape_smoke.gd").obscures(self,Vector3(3,1,-4),Vector3(3,1,4)))
 var wind:=root.get_node("WindSystem")
 for i in 120:
  await process_frame
  var drift:Vector3=wind.sample(smoke.global_position)*.16
  smoke.gravity=Vector3(drift.x,.1,drift.z)
 assert(wind.sample(Vector3.ZERO).is_finite())
 var output:=OS.get_environment("TLM_AIR_REVIEW")
 if not output.is_empty():
  await RenderingServer.frame_post_draw
  get_root().get_texture().get_image().save_png(output)
 print("AIR EFFECTS: PASS | shared wind, world-space smoke, fade and escape occlusion")
 quit()
