extends SceneTree
## Actual-world continuation smoke test, isolated saves; optional native screenshots.
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 if not ok:failures.append(label);push_error(label)
func run() -> void:
 var temporary:=OS.get_environment("TLM_STORY_TEST_DIR")
 if temporary.is_empty() or not temporary.begins_with(OS.get_environment("TMPDIR")):quit(2);return
 root.get_node("SaveManager").save_root=temporary
 if OS.get_environment("TLM_REBELLION_NATIVE")=="1":root.scaling_3d_scale=minf(1.0,720.0/root.get_visible_rect().size.y)
 var world: Node3D=load("res://world/suryagarh/suryagarh_world.tscn").instantiate();root.add_child(world);current_scene=world
 for i in 1800:
  await physics_frame
  if world.has_node("RebellionStory") and world.get_node("RebellionStory").configured:break
 if not world.has_node("RebellionStory"):quit(1);return
 var story: Node=world.get_node("RebellionStory");var prior: Node=world.get_node("DevStory");var player: CharacterBody3D=world.get_node("Player")
 check(story.configured,"main world continuation configured")
 if not story.configured:quit(1);return
 story.set_process(false);prior.state="complete";prior.lesson=8;story._process(.1);story.update_cinematic(4.1)
 check(story.stage=="ambush" and story.sites.officer==world.get_node("DevInquiry").officials[0],"existing superior is reused after equipment tutorial")
 player.global_position=story.sites.tree.global_position+Vector3(0,.9,-1.5);story._process(.1)
 check(story.stage=="confront","main world tree ambush")
 story.sites.officer.get_node("Vitality").receive_hit(100,player,"sword")
 check(story.stage=="escape" and world.get_node("CombatEncounters").wanted_level>0,"main world killing begins pursuit")
 world.get_node("CombatEncounters").complete_custody(player)
 story.set_stage("raid_ready")
 check(story.request("raid",player),"raid briefing action")
 story.update_cinematic(6.1)
 check(story.stage=="infiltrate" and story.sites.companions.size()==2,"raid at real cantonment with two companions")
 check(story.sites.raid.global_position.distance_to(world.find_child("BritishCantonment",true,false).global_position)<110,"magazine belongs to cantonment")
 # Pose the camera over actual terrain to inspect placement; this isn't final play approval.
 if OS.get_environment("TLM_REBELLION_NATIVE")=="1":
  story.camera.make_current();story.camera.global_position=story.sites.raid.to_global(Vector3(24,14,30));story.camera.look_at(story.sites.raid.global_position+Vector3.UP*3)
  await capture("world_magazine",temporary)
  story.camera.global_position=story.sites.cellar.to_global(Vector3(25,16,35));story.camera.look_at(story.sites.cellar.global_position+Vector3.UP*2)
  await capture("world_hideout",temporary)
  var samples: Array[float]=[];var last_tick:=Time.get_ticks_usec()
  for frame in 180:
   await process_frame;var now:=Time.get_ticks_usec();samples.append(float(now-last_tick)/1000.0);last_tick=now
  samples.sort();print("REBELLION NATIVE FRAME | median_ms=",samples[90]," p95_ms=",samples[171]," viewport=",root.get_visible_rect().size," 3d_scale=",root.scaling_3d_scale)
 var data: Dictionary=story.export_state();story.restore_state(data)
 check(story.stage=="infiltrate","main world restoration")
 print("REBELLION WORLD: "+("PASS" if failures.is_empty() else "FAIL "+str(failures)))
 world.queue_free();await process_frame;root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)
func capture(label: String,directory: String) -> void:
 for i in 8:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(directory.path_join(label+".png"))
