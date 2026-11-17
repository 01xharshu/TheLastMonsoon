extends SceneTree
## Exercises genuine positional streams, alternating turns, goodbye and interruption.
class FakeHealth extends Node:
 var health:=75.0
class Resident extends Node3D:
 var movement_profile:=&"male"
class Crowd extends Node:
 var age:=0.0
 var people:Array[Node]=[]
 func available(journey:Node) -> bool:return is_instance_valid(journey) and is_instance_valid(journey.actor) and not journey.paused
 func neighbours(_point:Vector3) -> Array[Node]:return people
class Workers extends Node:
 var residents:Array[Node3D]=[]
class PatrolRegistry extends Node:
 var patrols:Array[Dictionary]=[]
class Store extends Node3D:
 var seller:Node3D
class Journey extends Node:
 var actor:Node3D
 var social_partner:Node
 var social_cooldown:=0.0
 var paused:=false
 var personal_seed:=0
 var social_speaker:=false
 var social_voice_sent:=false
 var social_end:=0.0
var failures:Array[String]=[]
func check(ok:bool,label:String) -> void:
 if not ok:failures.append(label);push_error(label)
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var world:=Node3D.new();root.add_child(world);current_scene=world
 var player:=CharacterBody3D.new();player.name="Player";world.add_child(player)
 var crowd:=Crowd.new();crowd.name="PopulationSocial";world.add_child(crowd)
 var encounters:=PatrolRegistry.new();encounters.name="CombatEncounters";world.add_child(encounters)
 var person:=Resident.new();person.name="StreetTest";person.position=Vector3(2,0,0);person.set_meta("population_index",0);world.add_child(person)
 var journey:=Journey.new();journey.actor=person;person.add_child(journey);crowd.people.append(journey)
 var manager:Node=load("res://world/suryagarh/player_street_conversation.gd").new();world.add_child(manager)
 await process_frame
 manager.set_process(false);manager.set_physics_process(false)
 if FileAccess.file_exists("res://choice_test_enabled"):manager.choices_enabled=false
 if not FileAccess.file_exists("res://mary_test_enabled"):
  manager.refresh_mary_voice();check(not manager.mary_ready,"incomplete Mary set leaves current voice in place")
 if FileAccess.file_exists("res://mary_test_enabled"):
  manager.mary_ready=false
  manager.peer_voice.stream=manager.voice_for("peer_female_0_question");manager.peer_voice.play()
  manager.refresh_mary_voice();check(not manager.mary_ready,"Mary does not switch during active speech")
  manager.peer_voice.stop();manager.refresh_mary_voice()
  check(manager.mary_ready and manager.voice_for("female_hello_0").resource_path.ends_with("context_mary_female_hello_0.wav"),"complete set switches the primary female voice")
  check(manager.voice_for("female_alt_hello_0").resource_path.ends_with("context_female_alt_hello_0.wav"),"alternate female voice remains distinct")
  person.movement_profile=&"female";person.position.x=1.8
  check(not manager.begin_flirt(journey,0),"age-ambiguous resident cannot start flirt dialogue")
  person.set_meta("adult_character",true)
  for variant in 4:
   check(manager.begin_flirt(journey,variant) and manager.mode=="flirt" and manager.resident_voice.playing,"adult resident starts playful exchange %d"%variant)
   manager.resident_voice.emit_signal("finished")
   check(manager.player_voice.playing and manager.caption.text.begins_with("Arjun:"),"Arjun answers playful exchange %d"%variant)
   manager.player_voice.emit_signal("finished")
   check(manager.turn==2 and manager.resident_voice.playing,"resident follows up in exchange %d"%variant)
   manager.resident_voice.emit_signal("finished")
   check(manager.turn==3 and manager.player_voice.playing,"Arjun closes exchange %d"%variant)
   manager.player_voice.emit_signal("finished");check(manager.turn==-1,"playful exchange ends cleanly")
  check(manager.begin_flirt(journey,0),"adult conversation restarts")
  player.global_position=Vector3(10,0,0);manager._process(.1)
  check(manager.turn==0 and manager.mode=="flirt_departure" and manager.resident_voice.playing and manager.leaving,"walking away starts the resident's recorded goodbye")
  manager.resident_voice.emit_signal("finished")
  check(manager.turn==-1 and not person.has_meta("player_street_chat"),"closing releases the resident")
  player.global_position=Vector3.ZERO
  var departure:AudioStream=manager.voice_for("mary_depart_0");manager.streams["mary_depart_0"]=null
  check(manager.begin_flirt(journey,0),"conversation can start without an optional departure clip")
  player.global_position=Vector3(10,0,0);manager._process(.1)
  check(manager.turn==-1 and not person.has_meta("player_street_chat"),"missing goodbye ends safely without playing an unrelated line")
  manager.streams["mary_depart_0"]=departure;player.global_position=Vector3.ZERO
  manager.age=600.0;manager.still=2.0;manager.poll=0;manager.next_time=0;manager.per_person.clear()
  manager._process(.1)
  check(manager.mode=="flirt" and manager.resident_voice.playing,"nearby adult automatically starts occasional playful dialogue")
  manager.finish()
  if FileAccess.file_exists("res://natural_timing_enabled"):
   check(manager.begin_flirt(journey,0),"real-time pair starts")
   var deadline:int=Time.get_ticks_msec()+25000
   var heard_reply:=false
   while manager.turn>=0 and Time.get_ticks_msec()<deadline:
    if manager.turn==1 and manager.player_voice.playing:heard_reply=true
    await process_frame
   check(manager.turn==-1 and heard_reply,"real WAV playback advances to Arjun and completes naturally")
   manager.finish()
  person.remove_meta("adult_character");person.movement_profile=&"male";person.position.x=2
 manager.age=20.0;person.position.x=1.8;player.velocity=Vector3(1,0,0)
 manager._process(.1)
 check(manager.passing_voice.playing,"moving player triggers a nearby passer-by positional response")
 check(not manager.try_passing_response(),"passing response does not overlap itself")
 player.global_position=Vector3(20,0,0);manager._process(.1)
 check(not manager.passing_voice.playing,"passing response stops out of range")
 player.global_position=Vector3.ZERO;player.velocity=Vector3.ZERO;person.position.x=2.0
 check(not manager.try_passing_response(),"passing cooldown prevents immediate repetition")
 check(manager.begin(journey,0),"exchange starts with complete imported clips")
 check(manager.turn==0 and manager.resident_voice.playing and person.get_meta("speaking",false),"resident starts first line")
 manager.resident_voice.emit_signal("finished")
 check(manager.turn==1 and manager.player_voice.playing and not person.get_meta("speaking",false),"Arjun replies on second turn")
 manager.player_voice.emit_signal("finished")
 check(manager.turn==2 and manager.resident_voice.playing,"resident answers on third turn")
 manager.resident_voice.emit_signal("finished")
 check(manager.turn==3 and manager.player_voice.playing and manager.caption.text.begins_with("Arjun:"),"ordinary exchange has a recorded closing")
 manager.player_voice.emit_signal("finished")
 check(manager.turn==-1 and not manager.caption.visible and not person.get_meta("speaking",false),"completion clears voice and caption")
 var other:=Resident.new();other.name="OtherResident";other.position=Vector3(3,0,0);other.movement_profile=&"female";world.add_child(other)
 var other_journey:=Journey.new();other_journey.actor=other;other.add_child(other_journey)
 journey.social_partner=other_journey;other_journey.social_partner=journey
 journey.social_speaker=true;other_journey.social_speaker=false;journey.personal_seed=2;other_journey.personal_seed=4
 check(manager.try_peer_speech(other_journey)==0,"peer answer cannot start before the question")
 check(manager.try_peer_speech(journey)==1 and manager.peer_voice.playing,"first nearby resident speaks the peer question")
 journey.social_voice_sent=true
 check(journey.social_end>crowd.age+5.4 and other_journey.social_end==journey.social_end,"peer meeting reserves time for both recorded turns")
 check(manager.try_peer_speech(other_journey)==0,"second peer waits while the first voice is playing")
 check(manager.peer_speaking_status(journey)==1 and manager.peer_speaking_status(other_journey)==0,"speaking animation follows the active peer voice")
 manager.peer_voice.stop()
 check(manager.try_peer_speech(other_journey)==1 and manager.peer_voice.playing,"second nearby resident speaks the paired answer")
 player.global_position=Vector3(20,0,0);manager._process(.1)
 check(not manager.peer_voice.playing,"peer voice stops when the player moves out of range")
 player.global_position=Vector3.ZERO;journey.social_partner=null;other_journey.social_partner=null
 check(journey.social_cooldown>2.0,"participant cannot join an overlapping crowd chat")
 check(manager.begin(journey,1),"second wording is available")
 player.global_position=Vector3(10,0,0);manager._process(.1)
 check(manager.leaving and manager.turn==2 and manager.resident_voice.playing,"leaving starts the matching farewell")
 manager._process(.1)
 check(manager.leaving and manager.resident_voice.playing,"farewell continues while player is nearby")
 manager.resident_voice.emit_signal("finished")
 check(manager.turn==3 and manager.player_voice.playing,"Arjun answers the farewell")
 manager.player_voice.emit_signal("finished")
 check(manager.turn==-1,"farewell ends the exchange")
 player.global_position=Vector3.ZERO
 check(manager.begin(journey,0),"conversation restarts for interruption test")
 player.set_meta("story_cinematic",true);manager._process(.1)
 check(manager.turn==-1 and not manager.player_voice.playing and not manager.resident_voice.playing,"cinematic interrupts all speech")
 player.set_meta("story_cinematic",false)
 var wall:=StaticBody3D.new();world.add_child(wall);wall.position=Vector3(1,1.2,0)
 var wall_shape:=CollisionShape3D.new();var wall_box:=BoxShape3D.new();wall_box.size=Vector3(.2,3,2);wall_shape.shape=wall_box;wall.add_child(wall_shape)
 await physics_frame
 check(not manager.begin(journey,0),"closed wall blocks a face-to-face conversation")
 wall.queue_free();await physics_frame
 person.movement_profile=&"female"
 manager.per_person.clear();manager.age=20;manager.next_time=0;manager.still=2;manager.poll=0
 manager._process(.5)
 check(manager.turn==0 and manager.voice_prefix=="female" and manager.resident_voice.playing,"stationary approach selects nearby female resident")
 manager.finish()
 person.set_meta("population_index",1)
 check(manager.resident_profile(person)=="female_alt", "resident voice remains stable by identity")
 person.set_meta("population_index",0)
 var reaction:=Node.new();reaction.name="CivilianReaction";person.add_child(reaction)
 manager.next_reaction=0
 check(manager.report_collision(person,0) and manager.mode=="collision" and manager.resident_voice.playing,"collision triggers the resident's warning")
 manager.resident_voice.emit_signal("finished")
 check(manager.turn==1 and manager.player_voice.playing and manager.caption.text.begins_with("Arjun: I am sorry"),"collision receives an apologetic Arjun response")
 manager.player_voice.emit_signal("finished")
 check(manager.turn==-1 and not manager.report_collision(person,0),"collision ends and applies cooldown")
 manager.age+=30;manager.next_reaction=0;person.set_meta("combat_faction","police")
 check(manager.report_collision(person,1) and manager.voice_prefix=="police" and manager.caption.text.begins_with("Officer:"),"police use their own warning profile")
 manager.resident_voice.emit_signal("finished")
 check(manager.caption.text.begins_with("Arjun: Mind your own way"),"alternate collision response is distinct")
 manager.player_voice.emit_signal("finished")
 person.set_meta("combat_faction","indian");manager.reaction_cooldowns.clear();manager.next_reaction=0
 var horse:=CharacterBody3D.new();horse.add_to_group("horses");world.add_child(horse);horse.velocity=Vector3(4,0,0)
 player.set_meta("mounted_vehicle",horse);manager.horse_poll=0
 manager._physics_process(.3)
 check(manager.mode=="collision" and manager.resident_voice.playing,"nearby approaching horse triggers a warning")
 manager.finish();crowd.people.clear();manager.reaction_cooldowns.clear();manager.next_reaction=0;manager.horse_poll=0
 person.set_meta("combat_faction","police");encounters.patrols.append({"actor":person})
 manager._physics_process(.3)
 check(manager.mode=="collision" and manager.voice_prefix=="police","approaching horse also warns from a non-social police patrol")
 manager.finish();person.set_meta("combat_faction","indian");player.remove_meta("mounted_vehicle")
 var store:=Store.new();store.name="CityWeaponSeller";store.seller=person;world.add_child(store)
 player.set_meta("weapon_shop_open",true);manager._process(.1)
 check(manager.mode=="shop" and manager.caption.text.begins_with("Merchant:") and manager.resident_voice.playing,"opening the existing store starts merchant speech")
 manager.resident_voice.emit_signal("finished")
 check(manager.turn==1 and manager.caption.text.begins_with("Arjun:") and manager.player_voice.playing,"Arjun answers without closing the store")
 player.set_meta("weapon_shop_open",false);manager._process(.1)
 check(manager.turn==-1 and not manager.player_voice.playing,"closing the store stops its conversation")
 # Real CharacterBody collision, rather than invoking report_collision directly.
 var player_shape:=CollisionShape3D.new();var player_capsule:=CapsuleShape3D.new();player_capsule.radius=.3;player_capsule.height=1.5
 player_shape.shape=player_capsule;player_shape.position.y=.75;player.add_child(player_shape)
 var person_body:=StaticBody3D.new();person_body.name="BodyCollider";person.add_child(person_body)
 var person_shape:=CollisionShape3D.new();var person_capsule:=CapsuleShape3D.new();person_capsule.radius=.3;person_capsule.height=1.5
 person_shape.shape=person_capsule;person_shape.position.y=.75;person_body.add_child(person_shape)
 player.global_position=Vector3.ZERO;person.global_position=Vector3(2,0,0)
 manager.next_reaction=0;manager.reaction_cooldowns.clear();manager.last_velocity=Vector3.ZERO
 for i in 120:
  await physics_frame
  player.velocity=Vector3(4,0,0);player.move_and_slide();manager._physics_process(.0167)
  if manager.mode=="collision":break
 check(manager.mode=="collision" and manager.resident_voice.playing,"actual player collision triggers the nearby resident warning")
 manager.finish()
 # Health changes rather than stale hit metadata identify a genuine strike.
 var vitality:=FakeHealth.new();vitality.name="Vitality";person.add_child(vitality)
 manager.watched_vitals.clear();manager.next_assault=0;manager.reaction_cooldowns.clear();manager.watch_person(person)
 person.set_meta("last_attacker",horse);person.set_meta("last_hit_kind","punch");vitality.health=70
 manager.observe_hits()
 check(manager.mode=="", "damage by another attacker does not blame Arjun")
 person.set_meta("last_attacker",player);vitality.health=65;manager.observe_hits()
 check(manager.mode=="assault" and manager.resident_voice.playing and manager.caption.text in ["Resident: Why did you strike me?","Resident: Leave me alone!"],"actual health loss from Arjun triggers a distinct assault line")
 manager.resident_voice.emit_signal("finished")
 check(manager.player_voice.playing and manager.caption.text.begins_with("Arjun:"),"Arjun responds to the strike")
 manager.finish();manager.next_assault=0;manager.reaction_cooldowns.clear();manager.observe_hits()
 check(manager.mode=="", "unchanged health does not repeat stale attack metadata")
 var workers:=Workers.new();workers.name="VillageDailyActivities";world.add_child(workers)
 player.global_position=Vector3(0,0,10)
 var worker:=Resident.new();worker.name="WorkerTest";worker.position=player.global_position+Vector3(1,0,0)
 worker.set_meta("daily_activity","hoe");world.add_child(worker);workers.residents.append(worker)
 manager.passing_next=0;manager.passing_seen.clear()
 check(manager.try_worker_response() and worker.get_meta("player_conversation",false),"nearby worker starts greeting and pauses work")
 manager.passing_voice.emit_signal("finished")
 check(not worker.has_meta("player_conversation"),"worker resumes after greeting")
 manager.passing_next=0;worker.set_meta("daily_activity","going_to_hoe");manager.passing_seen.clear()
 check(not manager.try_worker_response(),"travelling worker is not interrupted")
 # A missing preferred recording should not silence a complete alternative.
 player.global_position=Vector3.ZERO;player.velocity=Vector3.ZERO;person.global_position=Vector3(1.8,0,0)
 person.movement_profile=&"male";crowd.people.clear();crowd.people.append(journey)
 var first_hello:AudioStream=manager.voice_for("male_hello_0")
 manager.streams["male_hello_0"]=null;manager.last_exchange[person.get_instance_id()]=1
 check(manager.begin(journey) and manager.exchange==1,"ordinary conversation falls back to its complete alternate")
 manager.finish();check(not manager.begin(journey,0),"explicit missing conversation variant does not substitute")
 manager.streams["male_hello_0"]=first_hello;manager.next_time=0
 var saved_goodbye:AudioStream=manager.voice_for("arjun_goodbye_0");manager.streams["arjun_goodbye_0"]=null
 check(manager.begin(journey,0) and not manager.conversation_has_closing,"ordinary conversation remains available before optional closing is imported")
 manager.resident_voice.emit_signal("finished");manager.player_voice.emit_signal("finished");manager.resident_voice.emit_signal("finished")
 check(manager.turn==-1,"ordinary conversation safely finishes when optional closing is missing")
 manager.streams["arjun_goodbye_0"]=saved_goodbye
 var first_collision:AudioStream=manager.voice_for("male_collision_0")
 manager.streams["male_collision_0"]=null;manager.next_reaction=0;manager.reaction_cooldowns.clear()
 manager.last_reaction["%d:collision"%person.get_instance_id()]=1
 check(manager.report_collision(person) and manager.exchange==1,"collision warning falls back to its complete alternate")
 manager.finish();manager.streams["male_collision_0"]=first_collision
 manager.age=20;manager.passing_next=0;manager.passing_seen.clear()
 var first_pass:AudioStream=manager.voice_for("pass_male_0");manager.streams["pass_male_0"]=null
 check(manager.try_passing_response() and manager.passing_voice.stream==manager.voice_for("pass_male_1"),"passing response falls back to available variant")
 manager.end_passing();manager.streams["pass_male_0"]=first_pass
 journey.social_partner=other_journey;other_journey.social_partner=journey;journey.social_speaker=true;other_journey.social_speaker=false
 journey.social_voice_sent=false;other_journey.social_voice_sent=false
 var first_peer:AudioStream=manager.voice_for("peer_male_0_question");manager.streams["peer_male_0_question"]=null
 check(manager.try_peer_speech(journey)==1 and manager.peer_voice.stream==manager.voice_for("peer_male_1_question"),"peer dialogue falls back to the complete paired variant")
 manager.peer_voice.stop();manager.streams["peer_male_0_question"]=first_peer;journey.social_partner=null;other_journey.social_partner=null
 var first_shop:AudioStream=manager.voice_for("shop_hello_0");manager.streams["shop_hello_0"]=null;manager.shop_visits=0
 check(manager.begin_shop() and manager.exchange==1,"shop greeting falls back to its complete alternate")
 manager.finish();manager.streams["shop_hello_0"]=first_shop
 player.global_position=Vector3(0,0,10);worker.set_meta("daily_activity","hoe");worker.set_meta("population_index",0)
 manager.age=20;manager.passing_next=0;manager.passing_seen.clear()
 var first_worker:AudioStream=manager.voice_for("worker_male_0");manager.streams["worker_male_0"]=null
 check(manager.try_worker_response() and manager.passing_voice.stream==manager.voice_for("worker_male_1"),"worker response falls back to available variant")
 manager.end_passing();manager.streams["worker_male_0"]=first_worker
 if FileAccess.file_exists("res://mary_test_enabled"):
  player.global_position=Vector3.ZERO;person.movement_profile=&"female";person.set_meta("adult_character",true)
  manager.age=480;manager.mary_ready=true
  var first_flirt:AudioStream=manager.voice_for("mary_flirt_1");manager.streams["mary_flirt_1"]=null
  check(manager.begin_flirt(journey) and manager.exchange==1,"playful dialogue falls back to a complete alternate pair")
  manager.finish();check(not manager.begin_flirt(journey,0),"explicit missing playful variant does not substitute")
  manager.streams["mary_flirt_1"]=first_flirt;person.remove_meta("adult_character")
 # A complete worker set uses four turns and returns control to the activity owner.
 player.global_position=Vector3(0,0,10);worker.set_meta("daily_activity","hoe");worker.set_meta("population_index",0)
 manager.age=20;manager.passing_next=0;manager.passing_seen.clear()
 manager.streams["arjun_worker_reply_0"]=manager.voice_for("arjun_reply_0")
 manager.streams["arjun_worker_close_0"]=manager.voice_for("arjun_goodbye_0")
 manager.streams["worker_followup_male_0"]=manager.voice_for("worker_male_0")
 check(manager.try_worker_response() and manager.mode=="worker" and worker.get_meta("player_conversation",false),"complete worker set starts four-turn exchange")
 manager.resident_voice.emit_signal("finished");check(manager.turn==1 and manager.player_voice.playing,"Arjun answers worker")
 manager.player_voice.emit_signal("finished");check(manager.turn==2 and manager.resident_voice.playing,"worker follows up")
 manager.resident_voice.emit_signal("finished");check(manager.turn==3 and manager.player_voice.playing,"Arjun closes worker exchange")
 manager.player_voice.emit_signal("finished");check(manager.turn==-1 and not worker.has_meta("player_conversation"),"worker resumes after four turns")
 manager.passing_next=0;manager.passing_seen.clear();check(manager.try_worker_response() and manager.mode=="worker","worker exchange restarts")
 player.global_position=Vector3(0,0,0);manager._process(.1)
 check(manager.turn==3 and manager.player_voice.playing,"departing starts worker exchange closing")
 manager.player_voice.emit_signal("finished")
 check(manager.turn==-1 and not worker.has_meta("player_conversation"),"departing releases worker after closing")
 if FileAccess.file_exists("res://choice_test_enabled"):
  manager.streams.erase("arjun_choice_busy");manager.mary_ready=true;manager.finish();manager.choices_enabled=true
  player.global_position=Vector3.ZERO;person.global_position=Vector3(1.8,0,0)
  person.movement_profile=&"female";person.set_meta("adult_character",true)
  check(manager.begin_flirt(journey,0),"choice conversation starts")
  manager.resident_voice.emit_signal("finished")
  check(manager.choice_pending and manager.choice_label.visible and manager.turn==1,"two response choices appear after first line")
  var key:=InputEventKey.new();key.physical_keycode=KEY_1;key.pressed=true;manager._input(key)
  check(not manager.choice_pending and manager.turn==1 and manager.player_voice.playing,"choice one continues the conversation")
  manager.finish()
  check(manager.begin_flirt(journey,0),"busy-choice conversation starts")
  manager.resident_voice.emit_signal("finished")
  var busy:=InputEventKey.new();busy.physical_keycode=KEY_2;busy.pressed=true;manager._input(busy)
  check(manager.mode=="flirt_busy" and manager.turn==0 and manager.player_voice.playing,"choice two plays Arjun's busy response")
  manager.player_voice.emit_signal("finished")
  check(manager.turn==1 and manager.resident_voice.playing,"resident answers busy response with goodbye")
  manager.resident_voice.emit_signal("finished")
  check(manager.turn==-1 and not person.has_meta("player_street_chat"),"busy response closes and releases actor")
  check(manager.begin_flirt(journey,0),"timeout conversation starts")
  manager.resident_voice.emit_signal("finished");manager._process(8.1)
  check(manager.mode=="flirt_busy" and manager.player_voice.playing,"unanswered choice defaults to polite departure")
  manager.finish()
  check(manager.begin_flirt(journey,0),"cinematic interruption choice starts")
  manager.resident_voice.emit_signal("finished");player.set_meta("story_cinematic",true);manager._process(.1)
  check(not manager.choice_pending and not manager.choice_label.visible and manager.turn==-1,"cinematic dismisses choice and releases control")
  player.set_meta("story_cinematic",false);person.remove_meta("adult_character");person.movement_profile=&"male"
  check(manager.begin(journey,0),"ordinary choice conversation starts")
  manager.resident_voice.emit_signal("finished");manager.choose_response(2)
  check(manager.mode=="conversation_busy" and manager.player_voice.playing,"ordinary busy choice starts Arjun's response")
  manager.player_voice.emit_signal("finished");check(manager.resident_voice.playing,"ordinary resident says goodbye")
  manager.resident_voice.emit_signal("finished");check(manager.turn==-1,"ordinary busy choice completes")
  person.movement_profile=&"female";person.set_meta("adult_character",true)
  check(manager.begin_flirt(journey,0),"controller choice conversation starts")
  manager.resident_voice.emit_signal("finished")
  var button:=InputEventJoypadButton.new();button.button_index=JOY_BUTTON_B;button.pressed=true;manager._input(button)
  check(manager.mode=="flirt_busy" and manager.player_voice.playing,"controller busy choice starts response")
  manager.finish()
  check(manager.begin_flirt(journey,0),"walking-away choice conversation starts")
  manager.resident_voice.emit_signal("finished");player.global_position=Vector3(10,0,0);manager._process(.1)
  check(not manager.choice_pending and not manager.choice_label.visible and manager.mode=="flirt_departure","walking away dismisses choices and starts goodbye")
  manager.finish();player.global_position=Vector3.ZERO;person.remove_meta("adult_character")
 print("PLAYER STREET CONVERSATION ","PASS" if failures.is_empty() else "FAIL"," ",failures)
 world.queue_free();await process_frame
 quit(0 if failures.is_empty() else 1)
