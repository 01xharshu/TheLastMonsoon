extends SceneTree
## Actual title-menu New Journey input route; writes no save or capture.
var failed:=false
class Watchdog:
 extends Node
 var started:=Time.get_ticks_msec()
 func _process(_delta:float)->void:
  if Time.get_ticks_msec()-started>240000:get_tree().quit(2)
func _initialize()->void:
 call_deferred("run")
 var watchdog:=Watchdog.new();root.add_child(watchdog)
func check(ok:bool,label:String)->void:
 print(("PASS " if ok else "FAIL ")+label)
 if not ok:failed=true
func run()->void:
 var menu:Node=await preload("res://tools/maintenance/startup_fixture.gd").open_title(self)
 if menu==null:quit(1);return
 menu._begin_journey(0)
 var loading:Node
 for child in root.get_children():
  if child.get_script()==preload("res://ui/journey_loading.gd"):loading=child;break
 while current_scene==null or current_scene.scene_file_path!=root.get_node("SaveManager").WORLD:await process_frame
 while is_instance_valid(loading):await process_frame
 var world:Node3D=current_scene
 var opening:=world.find_child("OpeningSequence",true,false)
 if opening!=null:opening._release()
 var player:CharacterBody3D=world.get_node("Player")
 player.get_node("PlayerSafety").set_physics_process(false)
 for body in world.find_children("*","CollisionObject3D",true,false):body.disable_mode=CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE
 world.process_mode=Node.PROCESS_MODE_DISABLED;player.process_mode=Node.PROCESS_MODE_ALWAYS;player.set_physics_process(true);player.is_swimming=false
 player.set_meta("story_cinematic",false);player.set_meta("tutorial_reading",false)
 player.get_node("UI/HUDRoot/MorningTutorial").set_process(false)
 player.get_node("UI/HUDRoot/MorningTutorial").set_process_input(false)
 player.get_node("UI/HUDRoot/MorningTutorial").set_process_unhandled_input(false)
 var target:Node3D
 for npc in get_nodes_in_group("combat_actors"):
  npc.set_meta("sleeping",true)
  if target==null and npc.get_meta("combat_faction","") in ["police","british"] and not npc.get_meta("dead",false) and "/CombatEncounters/" in str(npc.get_path()):target=npc
 if target==null:quit(1);return
 target.process_mode=Node.PROCESS_MODE_ALWAYS;target.movement_enabled=false;target.travel_speed=0
 target.set_meta("sleeping",false)
 player.global_position=target.global_position-target.global_basis.z*.65+Vector3.UP*.9
 for i in 5:await physics_frame
 var crime:Node=world.get_node("CombatEncounters")
 crime.wanted=false;crime.wanted_level=0;crime.evidence.clear()
 var notifications:Array[String]=[]
 player.inventory.message_requested.connect(func(message:String):notifications.append(message))
 var grapple:Node=player.get_node("RearGrapple")
 var key:=InputEventKey.new();key.physical_keycode=KEY_Q;key.keycode=KEY_Q;key.pressed=true
 Input.parse_input_event(key)
 for i in 2:await process_frame
 check(grapple.active,"New Journey ordinary Q starts paired knockout on placed enemy")
 for i in 230:await physics_frame
 check(target.get_meta("knocked_out",false) and not target.get_meta("dead",false),"placed enemy survives and stays knocked out")
 check(not crime.wanted and crime.evidence.is_empty(),"unseen knockout records no main-game crime")
 var witnesses:Array[String]=["verified_test_witness"]
 crime.record_incident("takedown",player.global_position,witnesses,2)
 player.get_node("UI/HUDRoot")._process(0.0)
 var crime_notifications:=notifications.filter(func(message:String):return message.begins_with("Crime reported"))
 check(player.get_node("UI/HUDRoot").wanted_level==1 and crime_notifications.is_empty(),"main HUD shows wanted star with no crime notification")
 print("MAIN KNOCKOUT: ","FAIL" if failed else "PASS")
 preload("res://tools/test_audio_cleanup.gd").stop(root)
 quit(1 if failed else 0)
