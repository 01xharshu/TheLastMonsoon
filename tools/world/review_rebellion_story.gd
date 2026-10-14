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
 prior.refresh()
 check(str(world.get_node("DevInquiry").destination.get_meta("parking_label",""))==story.objective(),"predecessor refresh preserves current continuation destination")
 player.global_position=story.sites.tree.global_position+Vector3(0,.9,-1.5);story._process(.1)
 check(story.stage=="confront","main world tree ambush")
 story.sites.officer.get_node("Vitality").receive_hit(100,player,"sword")
 check(story.stage=="escape" and world.get_node("CombatEncounters").wanted_level>0,"main world killing begins pursuit")
 # Exercise the continuation in canonical order in the populated world.
 story.sites.horse.global_position=story.ground(story.sites.fort.to_global(Vector3(0,0,95)))
 player.global_position=story.sites.horse.global_position+Vector3(1,.9,0)
 check(story.sites.horse.board(player),"main world superior horse boards")
 for i in 100:await physics_frame
 story._process(.1)
 check(story.active and story.cinematic=="rescue","main world horse approach starts Mangal rescue")
 for i in 161:story.update_cinematic(.1);await physics_frame
 check(story.active and story.cinematic=="arrival","main world rescue precedes fort arrival")
 for i in 75:story.update_cinematic(.1);await physics_frame
 check(story.stage=="follow","main world arrival returns follow gameplay")
 var last_follow_position: Vector3=story.sites.mangal.global_position
 var stalled_frames:=0
 for i in 1000:
  if story.stage!="follow":break
  player.global_position=story.sites.mangal.global_position+Vector3(2,.9,0)
  story._process(.1)
  await physics_frame
  if story.sites.mangal.global_position.distance_to(last_follow_position)<.001:stalled_frames+=1
  else:stalled_frames=0
  last_follow_position=story.sites.mangal.global_position
  if stalled_frames>30:
   print("MANGAL FOLLOW BLOCKED index=",story.follow_index," local=",story.sites.cellar.to_local(last_follow_position))
   var goals=story.HIDEOUT_FOLLOW_ROUTE
   var goal: Vector3=story.sites.cellar.to_global(goals[story.follow_index])
   var query=PhysicsRayQueryParameters3D.create(last_follow_position+Vector3.UP*.9,last_follow_position+(goal-last_follow_position).normalized()*.14+Vector3.UP*.9,1)
   query.exclude=[story.sites.mangal.body_collider.get_rid(),story.sites.mangal.get_node("Vitality").hit_body.get_rid()]
   var blocker=story.sites.mangal.get_world_3d().direct_space_state.intersect_ray(query)
   if not blocker.is_empty():print("MANGAL FOLLOW COLLIDER ",blocker.collider.get_path()," at=",blocker.position)
   break
 check(story.stage=="briefing","Mangal physically reaches hideout before briefing")
 if story.stage!="briefing":
  root.get_node("SaveManager").quit_game(1);return
 check(story.request("briefing",player),"main world hideout briefing action")
 story.update_cinematic(19.1)
 check(story.stage=="inspect" and story.request("weapons",player),"briefing precedes captured weapons inspection")
 var gear: Node=player.get_node("VisualRoot/CharacterVisual").equipment
 gear.select_weapon(1);gear.stowed=false;gear._refresh()
 player.global_position=story.sites.cellar.to_global(Vector3(0,1.1,3));player.velocity=Vector3.ZERO
 for i in 20:await physics_frame
 var gun: Node=player.get_node("RifleCombat")
 gun.start_reload();story._process(.1)
 for i in 120:await physics_frame
 story._process(.1)
 check(story.stage=="shoot","main world real reload unlocks target practice")
 for shot in 2:
  player.get_node("CameraPivot/SpringArm3D/Camera3D").look_at(story.sites.target.global_position)
  gun.aiming=true;gun.fire();story._process(.1)
  if shot==0:
   check(story.stage=="shoot" and not story.can_request("raid"),"main world first hit keeps raid locked")
   gun.start_reload()
   for i in 120:await physics_frame
 check(story.stage=="raid_ready" and story.target_hits==2,"main world two real hits unlock raid")
 world.get_node("CombatEncounters").complete_custody(player)
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
 story.set_stage("collect")
 for i in 4:
  check(story.request("bundle%d"%i,player),"main world rifle bundle %d"%i)
 check(story.stage=="rope" and story.request("rope",player),"main world all bundles unlock rope")
 for i in 181:story.update_cinematic(.1);await physics_frame
 check(story.stage=="return" and story.sites.goods.rider==player,"main world rope returns cart driving")
 story.sites.goods.global_position=story.sites.return_bay.global_position
 story.sites.goods.rotation.y=story.sites.return_bay.rotation.y;story.sites.goods.boarding.speed=0
 story._process(.1)
 check(story.active and story.cinematic=="delivery","main world whole cart bay starts delivery")
 story.update_cinematic(7.1)
 check(story.stage=="complete" and story.captured_rifles==12,"main world ordered sequence delivers twelve rifles")
 print("REBELLION WORLD: "+("PASS" if failures.is_empty() else "FAIL "+str(failures)))
 root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)
func capture(label: String,directory: String) -> void:
 for i in 8:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(directory.path_join(label+".png"))
