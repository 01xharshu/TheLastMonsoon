extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
 var folder:=OS.get_environment("TLM_RIVER_TEST_OUTPUT")
 if folder.is_empty():push_error("Temporary output required");quit(1);return
 var world:=Node3D.new();root.add_child(world);current_scene=world
 world.add_child(load("res://world/suryagarh/generated/landscape.scn").instantiate())
 var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-48,-28,0);world.add_child(sun)
 var environment:=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.38,.46,.54);environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.6;world.add_child(environment)
 var viewport:=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport);viewport.world_3d=world.get_world_3d();root.disable_3d=true
 var camera:=Camera3D.new();viewport.add_child(camera);camera.current=true;camera.fov=55
 var layout=preload("res://world/suryagarh/landscape_layout.gd").new()
 for z in [-48.0,312.0]:
  var edge:float=layout.river_x(z)-layout.river_width(z)
  camera.position=Vector3(edge-24,6.0,z-17);camera.look_at(Vector3(edge-1,.2,z+5))
  for frame in 12:await process_frame
  RenderingServer.force_draw(false);viewport.get_texture().get_image().save_png(folder.path_join("lowbank_%d.png"%int(z)))
  print("LOW_BANK_CAPTURE ",z)
 world.queue_free();viewport.queue_free();await process_frame;quit()
