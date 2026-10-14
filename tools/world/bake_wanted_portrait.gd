extends SceneTree
## Author the notice likeness from Arjun's retained complete MPFB export.
## Run natively with TLM_CONSIGNMENT_REVIEW_PATH pointing to an OS temp dir.
func _initialize() -> void:call_deferred("bake")
func bake() -> void:
 var output:=OS.get_environment("TLM_CONSIGNMENT_REVIEW_PATH")
 if DisplayServer.get_name()=="headless" or output.is_empty() or not output.begins_with(OS.get_environment("TMPDIR")):quit(1);return
 var viewport:=SubViewport.new();viewport.size=Vector2i(256,320);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var scene:=Node3D.new();viewport.add_child(scene)
 var environment:=WorldEnvironment.new();var sky:=Environment.new();sky.background_mode=Environment.BG_COLOR;sky.background_color=Color(.82,.72,.52);sky.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;sky.ambient_light_color=Color.WHITE;sky.ambient_light_energy=.7;environment.environment=sky;scene.add_child(environment)
 var character=load("res://characters/arjun/arjun.glb").instantiate();scene.add_child(character)
 var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-25,-30,0);light.light_energy=1.5;scene.add_child(light)
 var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=.58;camera.position=Vector3(0,1.64,1.5);scene.add_child(camera);camera.look_at(Vector3(0,1.64,0));camera.make_current()
 for i in 8:await process_frame
 await RenderingServer.frame_post_draw
 var picture:=viewport.get_texture().get_image()
 for y in picture.get_height():
  for x in picture.get_width():
   var source:=picture.get_pixel(x,y);var value:=snappedf(source.r*.299+source.g*.587+source.b*.114,.125)
   picture.set_pixel(x,y,Color(.13,.10,.07).lerp(Color(.82,.72,.52),value))
 picture.save_png(output.path_join("wanted_portrait.png"));print("CONSIGNMENT authored MPFB portrait");viewport.queue_free();await process_frame;quit()
