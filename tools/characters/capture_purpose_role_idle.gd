extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
 var scene:=load("res://characters/npcs/indian/purpose_npc_review.tscn").instantiate() as Node3D
 var viewport:=SubViewport.new();viewport.size=Vector2i(1280,720);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(viewport);viewport.add_child(scene)
 var actors:Array[Node3D]=[]
 for role in ["dock_porter","boatman","record_clerk"]:
  var old:Node3D=scene.get_node(role);var origin:=old.position;old.free()
  var actor:=preload("res://characters/npcs/indian/purpose_work_actor.gd").new();actor.purpose_role=role;actor.movement_enabled=false;actor.position=origin
  var document:=GLTFDocument.new();var state:=GLTFState.new()
  document.append_from_file(ProjectSettings.globalize_path("res://characters/npcs/motion/%s/%s_rigged_candidate.glb"%[role,role]),state)
  actor.add_child(document.generate_scene(state));scene.add_child(actor);actor.set_process(false);actors.append(actor)
 DirAccess.make_dir_recursive_absolute("/tmp/tlm_purpose_role_idle")
 for frame in 240:
  for actor in actors:actor.call("_set_animation",&"idle",1.0/30.0)
  await process_frame
  RenderingServer.force_draw(false)
  viewport.get_texture().get_image().save_png("/tmp/tlm_purpose_role_idle/%04d.png"%frame)
 print("PURPOSE_ROLE_IDLE_CAPTURE 240 frames/30Hz, actual work actors")
 quit()
