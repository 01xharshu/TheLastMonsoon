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
 var rifle_review:=OS.get_environment("TLM_RIFLE_LESSON_REVIEW")=="1" and OS.get_environment("TLM_TUTORIAL_OUTPUT")!=""
 var fort_review:=OS.get_environment("TLM_FORT_REVIEW")=="1" and OS.get_environment("TLM_TUTORIAL_OUTPUT")!=""
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
 var rescue_start: Vector3=story.sites.coach.global_position
 for i in 400:
  if story.cinematic!="rescue":break
  story.update_cinematic(.1);await physics_frame
  if i%30==0:print("RESCUE TRACE step=",i," age=",story.age," cinematic=",story.cinematic)
  if i==30:
   check(story.sites.coach.global_position.distance_to(rescue_start)>1.0,"rescue coach travels along supported road")
   check(player.global_position.distance_to(story.sites.horse.seat_world())<1.0,"rescue rider follows the moving horse")
   if OS.get_environment("TLM_RESCUE_TRAVEL_ONLY")=="1":
    print("RESCUE TRAVEL: ","PASS" if failures.is_empty() else "FAIL")
    await preload("res://tools/test_audio_cleanup.gd").finish(self,0 if failures.is_empty() else 1)
    return
  if i==105:
   var leader:Node3D=story.sites.mangal
   check(leader.travel_scarf!=null and leader.travel_scarf.visible,"Mangal covers his face while travelling on the cart")
   if fort_review:
    story.camera.global_position=leader.to_global(Vector3(.45,1.57,1.05))
    story.camera.look_at(leader.to_global(Vector3(0,1.46,.05)))
    await capture("fort_travel_scarf",temporary)
 print("RESCUE TRACE handoff cinematic=",story.cinematic," age=",story.age)
 check(story.active and story.cinematic=="arrival","main world rescue precedes fort arrival")
 for i in 200:
  if story.cinematic!="arrival":break
  story.update_cinematic(.1);await physics_frame
 print("RESCUE TRACE arrival completed stage=",story.stage)
 check(story.stage=="follow","main world arrival returns follow gameplay")
 var last_follow_position: Vector3=story.sites.mangal.global_position
 var stalled_frames:=0
 for i in 1250:
  if story.stage!="follow":break
  if i%150==0:print("RESCUE TRACE follow step=",i," waypoint=",story.follow_index)
  player.global_position=story.sites.mangal.global_position+Vector3(2,.9,0)
  story._process(.1)
  await physics_frame
  if story.sites.mangal.global_position.distance_to(last_follow_position)<.001:stalled_frames+=1
  else:stalled_frames=0
  last_follow_position=story.sites.mangal.global_position
  if stalled_frames>30:
   print("HIDEOUT MANGAL FOLLOW BLOCKED index=",story.follow_index," local=",story.sites.cellar.to_local(last_follow_position))
   var goal: Vector3=story.follow_destination(story.follow_index)
   var query=PhysicsRayQueryParameters3D.create(last_follow_position+Vector3.UP*.9,last_follow_position+(goal-last_follow_position).normalized()*.14+Vector3.UP*.9,1)
   query.exclude=[story.sites.mangal.body_collider.get_rid(),story.sites.mangal.get_node("Vitality").hit_body.get_rid()]
   var blocker=story.sites.mangal.get_world_3d().direct_space_state.intersect_ray(query)
   if not blocker.is_empty():print("HIDEOUT MANGAL FOLLOW COLLIDER ",blocker.collider.get_path()," at=",blocker.position)
   break
 print("HIDEOUT MANGAL GATE FOLLOW index=",story.follow_index," stage=",story.stage," at=",story.sites.fort.to_local(story.sites.mangal.global_position))
 check(story.stage=="briefing","Mangal physically reaches hideout before briefing")
 if story.stage!="briefing":
  root.get_node("SaveManager").quit_game(1);return
 check(story.request("briefing",player),"main world hideout briefing action")
 for frame in 4:await process_frame
 var daily:Node=story.sites.cellar.get_node("HideoutDailyLife")
 check(daily.seat_owned and story.sites.mangal.riding_socket==daily.mangal_seat and not story.sites.mangal.travel_scarf.visible,"Mangal briefs seated with face uncovered")
 if fort_review:
  var leader:Node3D=story.sites.mangal
  story.camera.global_position=leader.to_global(Vector3(.55,1.63,1.35))
  story.camera.look_at(leader.to_global(Vector3(0,1.29,.08)))
  await capture("fort_mangal_briefing",temporary)
 story.update_cinematic(19.1)
 if rifle_review:
  var rack:Node3D=story.sites.cellar.get_node("CapturedRifleRack")
  story.camera.make_current()
  story.camera.global_position=rack.to_global(Vector3(.45,1.47,2.35))
  story.camera.look_at(rack.to_global(Vector3(0,.9,0)))
  await capture("rifle_rack",temporary)
  story.gameplay_camera.make_current()
 check(story.stage=="inspect" and story.request("weapons",player),"briefing precedes captured weapons inspection")
 var gear:Node=player.get_node("VisualRoot/CharacterVisual").equipment
 gear.select_weapon(1)
 story._process(.1)
 check(story.cinematic=="range_entry","equipping starts the range fade in the main world")
 story.update_cinematic(.55)
 story.update_cinematic(.7)
 for frame in 15:await physics_frame
 var gun:Node=player.get_node("RifleCombat")
 check(story.stage=="shoot" and player.get_meta("rifle_lesson",false),"main world firing line locks movement")
 Input.action_press("aim")
 gun._process(.01)
 if rifle_review:
  story._process(.01)
  await capture("rifle_practice",temporary)
 player.get_node("CameraPivot/SpringArm3D/Camera3D").look_at(story.sites.target.global_position)
 gun.fire()
 Input.action_release("aim")
 story._process(.1)
 check(story.stage=="raid_ready" and story.target_hits==1 and not player.get_meta("rifle_lesson",false),"main world target hit releases practice and unlocks raid")

 if rifle_review:
  print("RIFLE LESSON REVIEW READY")
  var review_deadline:=Time.get_ticks_msec()+55000
  while Time.get_ticks_msec()<review_deadline and not FileAccess.file_exists(temporary.path_join("rifle_review_done")):await process_frame
  await preload("res://tools/test_audio_cleanup.gd").finish(self,0 if failures.is_empty() else 1)
  return
 if fort_review:
  story.camera.make_current()
  story.camera.global_position=story.sites.fort.to_global(Vector3(0,12,23))
  story.camera.look_at(story.sites.target.global_position)
  await capture("fort_open_courtyard",temporary)
  print("HIDEOUT ENVIRONMENT REVIEW READY")
  var deadline:=Time.get_ticks_msec()+60000
  while Time.get_ticks_msec()<deadline and not FileAccess.file_exists(temporary.path_join("fort_review_done")):await process_frame
  await preload("res://tools/test_audio_cleanup.gd").finish(self,0 if failures.is_empty() else 1)
  return
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
