extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 if not ok:failures.append(label);push_error(label)
class Fixture:
 extends Node3D
 var layout=preload("res://world/suryagarh/landscape_layout.gd").new()
func run() -> void:
 var temporary:=OS.get_environment("TLM_STORY_TEST_DIR")
 if temporary.is_empty() or not temporary.begins_with(OS.get_environment("TMPDIR")):quit(2);return
 root.get_node("SaveManager").save_root=temporary
 var world:=Fixture.new();root.add_child(world);current_scene=world
 var clock=load("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock)
 var player: CharacterBody3D=load("res://player/player.tscn").instantiate();player.name="Player";world.add_child(player)
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
 var cues: Array[String]=[]
 while story.active:
  cues.append(story.cue);story._process(float(story.beats[story.beat_index].seconds)+.1)
  await process_frame
 check("collar" in cues and "beating" in cues and "collapse" in cues and "drink" in cues,"collar beating unconscious recovery story")
 check(story.state=="farm" and player.health==100 and player.is_physics_processing(),"recovery heals and returns control")
 check(inquiry.stage=="released","cinematic replaces old automatic custody")
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
