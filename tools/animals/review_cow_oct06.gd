extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var viewport:=SubViewport.new();viewport.size=Vector2i(960,540);viewport.own_world_3d=false;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.disable_3d=true;root.add_child(viewport)
 var display:=TextureRect.new();display.texture=viewport.get_texture();display.size=Vector2(960,540);display.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(display)
 var world:=Node3D.new();root.add_child(world);current_scene=world
 var cow:Node3D=load("res://assets/animals/cow/household_cow.glb").instantiate();world.add_child(cow);preload("res://animals/cow_visual.gd").apply(cow)
 var anim:=cow.find_child("AnimationPlayer",true,false) as AnimationPlayer
 if anim:anim.stop()
 var sun:=DirectionalLight3D.new();world.add_child(sun);sun.rotation_degrees=Vector3(-45,-35,0);sun.shadow_enabled=true
 var fill:=DirectionalLight3D.new();fill.light_energy=.45;fill.rotation_degrees=Vector3(-25,125,0);world.add_child(fill)
 var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.36,.42,.43);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(.8,.83,.82);env.environment.ambient_light_energy=.65;world.add_child(env)
 var ground:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(15,.1,15);ground.mesh=box;ground.position.y=-.05;world.add_child(ground)
 var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.30,.25,.17);ground.material_override=mat
 var camera:=Camera3D.new();viewport.add_child(camera);camera.make_current();camera.fov=45
 for view in [["side",Vector3(4,1.7,.1)],["quarter",Vector3(3,2,-3)],["front",Vector3(.1,1.3,-4)],["head",Vector3(1.05,1.4,-2.7)]]:
  camera.position=view[1];camera.look_at(Vector3(0,1.18,-1.36) if view[0]=="head" else Vector3(0,.85,-.2))
  for frame in 12:
   await process_frame
   RenderingServer.force_draw(false)
  await RenderingServer.frame_post_draw
  viewport.get_texture().get_image().save_png("res://docs/world/captures/cow_oct07_"+view[0]+".png")
 print("COW OCT07 NATIVE ",RenderingServer.get_current_rendering_method()," ",viewport.size);quit()
