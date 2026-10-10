extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 if not ok and not failures.has(label):failures.append(label);push_error(label)
class Fixture:
 extends Node3D
 var layout=preload("res://world/suryagarh/landscape_layout.gd").new()
func silence_review_input(node: Node) -> void:
 node.set_process_input(false);node.set_process_unhandled_input(false);node.set_process_unhandled_key_input(false)
 for child in node.get_children():silence_review_input(child)
func run() -> void:
 var temporary:=OS.get_environment("TLM_STORY_TEST_DIR")
 if temporary.is_empty() or not temporary.begins_with(OS.get_environment("TMPDIR")):quit(2);return
 root.get_node("SaveManager").save_root=temporary
 var world:=Fixture.new();root.add_child(world);current_scene=world
 var clock=load("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock)
 var player: CharacterBody3D=load("res://player/player.tscn").instantiate();player.name="Player";player.position=Vector3(40,2,40);world.add_child(player)
 if OS.get_environment("TLM_STORY_ACTING_REVIEW")=="1":silence_review_input(player)
 var ground:=StaticBody3D.new();world.add_child(ground);var col:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(1000,.2,1100);col.shape=box;col.position=Vector3(0,-.1,0);ground.add_child(col)
 var station=load("res://world/suryagarh/settlements/civic_building.gd").new();station.name="DistrictPolice";station.police=true;world.add_child(station)
 world.add_child(load("res://world/suryagarh/settlements/chacha_house.gd").new())
 world.add_child(load("res://story/dev_inquiry.gd").new())
 world.add_child(load("res://world/suryagarh/settlements/story_community.gd").new())
 var story_script: GDScript=load("res://story/dev_story.gd")
 if story_script==null or not story_script.can_instantiate():world.queue_free();await process_frame;quit(1);return
 world.add_child(story_script.new())
 for frame in 30:await physics_frame
 var story: Node=world.get_node("DevStory");var inquiry: Node=world.get_node("DevInquiry")
 check(story.configured and story.pose.node!=null,"cinematic and AnimationTree layer configured")
 if not story.configured or story.pose.node==null:world.queue_free();await process_frame;quit(1);return
 inquiry.begin();player.global_position=station.to_global(Vector3(0,.9,20));player.velocity=Vector3.ZERO
 for frame in 5:await physics_frame
 story._process(0)
 print("STORY GATE ",inquiry.stage," / ",station.to_local(player.global_position)," configured ",story.configured," busy ",player.get_meta("document_busy",false)," police ",root.get_node("SaveManager").police_case_active(player))
 check(story.active and story.kind=="inquiry","main gate starts cinematic")
 if not story.active:world.queue_free();await process_frame;quit(1);return
 check(not player.is_physics_processing() and player.get_meta("story_cinematic",false),"cinematic contains gameplay")
 check(not root.get_node("SaveManager").save_game(world,1),"cinematic saving blocked")
 # Verify the day ratio through the production clock, including the pause gate.
 var before: float=clock.total_game_minutes
 clock._process(600.0)
 check(absf(clock.total_game_minutes-before-1440)<.0001,"ten real minutes advances exactly one game day")
 clock.clock_paused=true;before=clock.total_game_minutes;clock._process(600.0)
 check(clock.total_game_minutes==before,"paused clock does not advance")
 clock.clock_paused=false
 if OS.get_environment("TLM_STORY_ACTING_REVIEW")=="1":
  await review_acting(story,inquiry,player,temporary)
  story.finish()
  print("STORY ACTING: "+("PASS" if failures.is_empty() else "FAIL "+str(failures)))
  world.queue_free();await process_frame;call_deferred("finish",0 if failures.is_empty() else 1);return
 story.set_process(false)
 var cues: Array[String]=[]
 while story.active:
  cues.append(story.cue);story._process(float(story.beats[story.beat_index].seconds)+.1)
  await process_frame
 check("stumble" not in cues and "rise" not in cues,"no second exterior fall")
 check("bed_arrival" in cues and "bed_sit" in cues and "tea_offer" in cues,"bed recovery precedes tea")
 check("collar" in cues and "beating" in cues and "collapse" in cues and "drink" in cues,"collar beating unconscious recovery story")
 check(story.state=="farm" and player.health==100 and player.is_physics_processing(),"recovery heals and returns control")
 check(inquiry.stage=="released","cinematic replaces old automatic custody")
 story.set_process(true)
 player.global_position=story.community.farm.to_global(Vector3(0,.9,3));player.velocity=Vector3.ZERO
 for frame in 20:await physics_frame
 check(story.active and story.kind=="lesson","farm starts instruction")
 story.finish()
 check(story.community.members.size()==3,"three consenting farm partners")
 var gear: Node=player.get_node("VisualRoot/CharacterVisual").equipment
 gear.select_weapon(0);gear.stowed=false;gear._refresh();story.check_practice(2.1)
 check(story.lesson==1 and story.active,"draw idle lesson enters demonstration before practice")
 story.finish()
 var partner: Node=story.community.members[0];var vitality: Node=partner.get_node("Vitality")
 # Exercise the existing weapon animations and physical hit paths, not a tutorial-only reward.
 player.global_position=partner.global_position+Vector3(0,.9,-1.05)
 player.get_node("CameraPivot").global_rotation.y=PI
 player.get_node("VisualRoot").global_rotation.y=0
 for frame in 15:await physics_frame
 player.get_node("TalwarSlash").strike()
 for frame in 120:await physics_frame
 print("SWORD PRACTICE ",story.lesson," hit ",partner.get_meta("training_hit",""))
 check(story.lesson==2,"animated blade contact advances sword lesson")
 if story.active:story.finish()
 Input.action_press("jump")
 for frame in 3:await physics_frame
 Input.action_release("jump")
 player.get_node("TalwarSlash").strike()
 for frame in 30:await physics_frame
 check(story.lesson==3,"airborne sword attack advances jump lesson")
 if story.active:story.finish()
 player.get_node("ChachaKit").equip("spear");player.velocity=Vector3.ZERO
 for frame in 90:await physics_frame
 story.check_practice(2.1);check(story.lesson==4,"spear idle advances lesson")
 if story.active:story.finish()
 partner=story.community.members[1]
 player.global_position=partner.global_position+Vector3(0,.9,-1.05);player.get_node("CameraPivot").global_rotation.y=PI
 for frame in 15:await physics_frame
 print("SPEAR START ",player.get_node("ChachaKit").strike()," active ",player.get_node("ChachaKit").active," stowed ",gear.stowed)
 for frame in 20:await physics_frame
 for frame in 70:await physics_frame
 print("SPEAR PRACTICE ",story.lesson," hit ",partner.get_meta("training_hit",""))
 check(story.lesson==5,"physical spear contact advances lesson")
 if story.active:story.finish()
 Input.action_press("jump")
 for frame in 3:await physics_frame
 Input.action_release("jump")
 player.get_node("ChachaKit").strike()
 for frame in 30:await physics_frame
 check(story.lesson==6,"airborne spear attack advances jump lesson")
 if story.active:story.finish()
 player.get_node("ChachaKit").equip("utility_knife")
 partner=story.community.members[2]
 player.global_position=partner.global_position+Vector3(0,.9,-.7);player.get_node("VisualRoot").global_rotation.y=0
 for frame in 15:await physics_frame
 player.get_node("KnifeStrike").strike()
 for frame in 90:await physics_frame
 print("KNIFE PRACTICE ",story.lesson," hit ",partner.get_meta("training_hit",""))
 check(story.lesson==7,"physical dagger contact advances lesson")
 if story.active:story.finish()
 story.reset_partners()
 var grapple: Node=player.get_node("RearGrapple")
 for i in 3:
  partner=story.community.members[i]
  player.global_position=partner.global_position-partner.global_basis.z*.65+Vector3.UP*.9
  for frame in 15:await physics_frame
  var event:=InputEventKey.new();event.physical_keycode=KEY_Q;event.pressed=true;story._input(event)
  check(grapple.active,"Q begins consent-based paired knockout")
  for frame in 120:await physics_frame
  check(not partner.get_meta("dead",false),"practice partner survives")
 check(story.state=="complete" and story.completed_partners.size()==3,"all three knockout practices complete tutorial")
 var saved: Dictionary=story.export_state();story.state="complete";story.restore_state(saved)
 check(story.state=="complete" and story.lesson==8,"completed lesson progress restoration")
 check(story.community.college!=null and story.community.courtyard!=null,"gathering places integrated")
 print("DEV STORY: "+("PASS" if failures.is_empty() else "FAIL "+str(failures)))
 world.queue_free();await process_frame;call_deferred("finish",0 if failures.is_empty() else 1)
func finish(code: int) -> void:preload("res://tools/test_audio_cleanup.gd").finish(self,code)

func review_acting(story: Node,inquiry: Node,player: Node3D,temporary: String) -> void:
 if DisplayServer.get_name()!="headless":
  DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
  DisplayServer.window_set_size(Vector2i(960,540))
 var sun:=DirectionalLight3D.new();story.get_parent().add_child(sun);sun.rotation_degrees=Vector3(-45,-25,0);sun.light_energy=1.2
 var environment:=WorldEnvironment.new();story.get_parent().add_child(environment);environment.environment=Environment.new()
 environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.25,.30,.36)
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color(.8,.8,.8);environment.environment.ambient_light_energy=.7
 if OS.get_environment("TLM_STORY_LATER_NATURAL")=="1":
  for i in story.beats.size():
   if story.beats[i].cue=="beating":story.beat_index=i;break
  story.enter_beat()
  var captured: Dictionary={}
  var maximum_support:=0.0
  var maximum_carry:=0.0
  while story.active:
   await process_frame
   if story.cue=="discard" and story.age>.02:
    maximum_carry=maxf(maximum_carry,story.carry_contact_error)
    check(story.carry_contact_error<.06,"live carry contact stays within reach")
   if story.cue in ["rescue","support_walk"] and story.age>.02:
    maximum_support=maxf(maximum_support,story.support_contact_error)
    check(story.support_contact_error<.06,"live rescue contact stays within reach")
   var key: String=story.cue+"_"+str(int(story.age))
   if not captured.has(key):
    captured[key]=true
    if DisplayServer.get_name()!="headless":
     await RenderingServer.frame_post_draw
     root.get_texture().get_image().save_png(temporary.path_join(key+".png"))
  print("STORY LIVE LATER carry=",maximum_carry," support=",maximum_support)
  return
 if OS.get_environment("TLM_STORY_RECOVERY_NATURAL")=="1":
  for index in story.beats.size():
   if story.beats[index].cue=="bed_arrival":story.beat_index=index;break
  story.enter_beat()
  var photographed: Dictionary={}
  var held_frames:=0
  while story.active:
   await process_frame
   if story.cue=="drink":
    held_frames+=1;check(story.cup_contact_error<.04,"live drinking palm follows cup")
   if story.cue=="bed_sit" and story.age>2.5:check(story.support_contact_error<.12,"live sitting support remains within reach")
   var key: String=story.cue
   var when: float=3.5 if key=="drink" else 1.8 if key=="tea_offer" else 3.0
   if story.active and story.age>when and not photographed.has(key):
    photographed[key]=true
    if DisplayServer.get_name()!="headless":
     await RenderingServer.frame_post_draw
     root.get_texture().get_image().save_png(temporary.path_join("natural_"+key+".png"))
  check(held_frames>0,"uninterrupted recovery reaches drinking")
  return
 if OS.get_environment("TLM_STORY_POLICE_NATURAL")=="1":
  var captured: Dictionary={}
  var contact_frames:=0
  while story.active and story.cue!="beating":
   await process_frame
   var key: String=str(story.beat_index)+"_"+story.cue
   var photograph: bool=story.age>1.2 if story.cue!="collar" else story.age>5.2
   if photograph and not captured.has(key):
    captured[key]=true
    if DisplayServer.get_name()!="headless":
     await RenderingServer.frame_post_draw
     root.get_texture().get_image().save_png(temporary.path_join(key+".png"))
   if story.cue=="collar" and story.age>5.2:
    contact_frames+=1
    check(story.collar_contact_error<.08,"live collar contact remains within reach")
   if story.cue=="collar" and story.age<2:
    check(story.pose.weight<.1,"approach precedes collar reach")
   if story.cue in ["entry","chamber"]:check(not story.hero_path.is_empty(),"live station approach has a route")
  check(contact_frames>0,"natural review reaches collar contact")
  return
 story.set_process(false);story.set_physics_process(false)
 if OS.get_environment("TLM_STORY_REVIEW_FAST")=="1":story.shade.hide()
 var cues: Array[String]=["entry","chamber","humiliation","collar","beating","collapse","discard","throw","rescue","support_walk","bed_arrival","bed_sit","tea_offer","drink"]
 if OS.get_environment("TLM_STORY_POLICE_REVIEW")=="1":cues=["entry","reception","chamber","humiliation","objection","collar","guards"]
 for cue in cues:
  for i in story.beats.size():
   if story.beats[i].cue==cue:story.beat_index=i;break
  story.enter_beat()
  print("ACTING REVIEW ",cue)
  var times: Array[float]=[1.0]
  if cue=="beating":times=[.648,1.998,3.348,4.698]
  elif cue=="collapse":times=[.3,.9,1.7,2.3]
  elif cue=="collar":times=[1.0,3.0,5.5]
  elif cue in ["throw","rescue"]:times=[.3,1.0,2.5]
  elif cue in ["entry","chamber","bed_sit"]:times=[float(story.beats[story.beat_index].seconds)]
  if cue=="rescue":times.append(5.5)
  if cue=="tea_offer":times=[.3,1.6,2.8]
  if cue=="drink":times=[1.0,3.5,6.5]
  for sample in times:
   story.age=sample
   var t: float=sample/float(story.beats[story.beat_index].seconds)
   story.update_acting(1.0,t)
   # Sampled seeks must settle the same seated/standing blend as live elapsed time.
   if cue=="collar":inquiry.officials[0]._process(minf(sample,.8))
   if cue in ["bed_arrival","bed_sit","tea_offer","drink"]:
    # The rest controller also animates model placement outside the tree.
    story.visual._process(1.0)
   story.pose.tree.advance(0)
   # Let graph/locomotion evaluate, then apply director-owned contacts last.
   await process_frame
   story.update_acting(0,t)
   if cue=="discard":
    print("STORY CARRY CONTACT error=",story.carry_contact_error)
    check(story.carry_contact_error<.06,"two carriers reach the supported body")
   if cue in ["rescue","support_walk"]:
    print("STORY SUPPORT CONTACT ",cue," error=",story.support_contact_error)
    if OS.get_environment("TLM_STORY_SUPPORT_DIAG")=="1" and cue=="rescue":
     var helper: Node3D=story.chacha
     print("SUPPORT DIAG ",sample," root=",helper.global_position," shoulder=",helper._skeleton.to_global(helper._skeleton.get_bone_global_pose(helper._bones["upperarm_r"]).origin)," palm=",helper.palm_world("r")," hero upperarm=",story.visual.skeleton.to_global(story.visual.skeleton.get_bone_global_pose(story.visual.bones["upperarm_l"]).origin))
    if cue=="support_walk" or sample>=2.5:check(story.support_contact_error<.06,"helper hand supports the upper arm")
    for side in ["l","r"]:
     var ankle: Vector3=story.chacha._skeleton.to_global(story.chacha._skeleton.get_bone_global_pose(story.chacha._bones["foot_"+side]).origin)
     check(ankle.y<story.chacha.global_position.y+.25,"helper feet stay below the knees after scene transfer")
   if cue=="collar" and sample>=5:
    print("STORY COLLAR CONTACT error=",story.collar_contact_error)
    check(story.collar_contact_error<.08,"both palms reach the posed collar")
   if cue=="bed_sit":
    print("BED SUPPORT CONTACT error=",story.support_contact_error)
    check(story.support_contact_error<.10,"helper supports Arjun while sitting up")
   if cue=="tea_offer" and t<.85:check(story.tea_helper_contact_error<.10,"helper retains cup during handoff")
   if cue=="drink" or (cue=="tea_offer" and t>.45):
    print("TEA CONTACT ",cue," error=",story.cup_contact_error)
    check(story.cup_contact_error<.04,"palm follows cup wall")
   if cue=="beating":
    print("STORY CONTACT ",int(sample/1.35)%4," error=",story.strike_contact_error)
    check(story.strike_contact_error<.12,"cinematic attack reaches near body surface")
   if DisplayServer.get_name()!="headless" and (OS.get_environment("TLM_STORY_REVIEW_FAST")!="1" or cue in ["bed_sit","tea_offer","drink"]):
    # Keep the director active through a real rendered frame for paired contact.
    # A disabled director permits the next locomotion frame to replace the seek pose.
    if cue in ["collar","guards","discard","rescue","support_walk","bed_sit","tea_offer","drink"]:
     story.set_process(true)
     await process_frame
    await RenderingServer.frame_post_draw
    story.set_process(false)
    if cue=="collar" and sample>=5:
     var after_draw:=0.0
     var rig: Skeleton3D=story.visual.skeleton
     var official: Node3D=inquiry.officials[0]
     var chest: Vector3=official._skeleton.to_global(official._skeleton.get_bone_global_pose(official._bones["spine_02"]).origin)
     for side in ["l","r"]:
      var target: Vector3=chest+official.global_basis*Vector3(.10 if side=="l" else -.10,.25,.18)
      var palm: Vector3=rig.to_global(rig.get_bone_global_pose(story.visual.bones["hand_"+side])*story.visual.equipment.palm_offsets[side])
      after_draw=maxf(after_draw,palm.distance_to(target))
     print("STORY RENDERED COLLAR error=",after_draw)
     check(after_draw<.08,"collar contacts survive rendered-frame evaluation")
    if cue=="discard":
     var after_draw:=0.0
     for index in 2:
      var guard: Node3D=inquiry.guards[index]
      for side in guard.cinematic_palms:after_draw=maxf(after_draw,guard.palm_world(side).distance_to(guard.cinematic_palms[side]))
     print("STORY RENDERED CARRY error=",after_draw)
     check(after_draw<.06,"carry posture and palms survive rendered-frame evaluation")
    root.get_texture().get_image().save_png(temporary.path_join(cue+"_"+str(sample)+".png"))
