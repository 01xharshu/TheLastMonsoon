extends SceneTree
## Production-world pixels; disposable output only, no gameplay/save mutation retained.
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var folder:=OS.get_environment("TLM_TEST_OUTPUT_DIR")
 assert(not folder.is_empty() and folder.begins_with(OS.get_environment("TMPDIR")))
 var saves:Node=root.get_node("SaveManager");saves.save_root=folder;saves.pending_slot=0
 var world:Node3D=load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
 root.add_child(world);current_scene=world
 for frame in 30:await process_frame
 while preload("res://systems/world_startup.gd").current!=null:await process_frame
 assert(world.has_node("Landscape/PortRavineBridge"))
 var opening:Node=world.get_node("OpeningSequence");opening.set_process(false)
 var player:CharacterBody3D=world.get_node("Player")
 player.set_physics_process(false);player.get_node("UI").hide()
 var camera:=Camera3D.new();camera.far=1800;world.add_child(camera)
 var views:Dictionary={"port_approach":[Vector3(-330,13,648),Vector3(-580,9,604)],"long_pass":[Vector3(-706,29,454),Vector3(-683,27,412)],"bridge":[Vector3(-374,32,403),Vector3(-403,18,385)],"underpass":[Vector3(-428,6,385),Vector3(-387,6,385)],"overview":[Vector3(-760,205,719),Vector3(-535,28,510)]}
 var space:=world.get_world_3d().direct_space_state
 for label:String in views:
  camera.position=views[label][0]
  var ground:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(camera.position.x,180,camera.position.z),Vector3(camera.position.x,-20,camera.position.z)))
  if not ground.is_empty():camera.position.y=maxf(camera.position.y,ground.position.y+1.8)
  camera.look_at(views[label][1]);camera.make_current()
  player.global_position=camera.position-Vector3.UP*1.2
  for frame in 12:await process_frame
  if DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw
   assert(root.get_texture().get_image().save_png(folder.path_join(label+".png"))==OK)
 print("PORT VILLAGE PRODUCTION WORLD PASS")
 world.queue_free();current_scene=null
 for frame in 3:await process_frame
 saves.quit_game(0)
