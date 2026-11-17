extends SceneTree
## Real-world player, resident, merchant and generated positional speech.
var errors:Array[String]=[]
func check(ok:bool,message:String) -> void:
 if not ok:errors.append(message);push_error(message)
func _initialize() -> void:run.call_deferred()
func run() -> void:
 var saves:Node=root.get_node("SaveManager")
 saves.start_new_game();await scene_changed
 var world:Node3D=current_scene
 var deadline:=Time.get_ticks_msec()+240000
 var opening:Node=world.get_node_or_null("OpeningSequence")
 while opening==null and Time.get_ticks_msec()<deadline:
  await process_frame;opening=world.get_node_or_null("OpeningSequence")
 if opening==null:
  push_error("Opening sequence did not initialise");saves.quit_game(1);return
 var skip:=InputEventKey.new();skip.keycode=KEY_ESCAPE;skip.pressed=true
 opening._input(skip)
 for i in 2:await process_frame
 opening._input(skip)
 var player:CharacterBody3D=world.get_node("Player");player.set_physics_process(false)
 var manager:Node=world.get_node_or_null("PlayerStreetConversation")
 var crowd:Node=world.get_node("PopulationSocial")
 var store:Node=world.get_node_or_null("CityWeaponSeller")
 if manager==null and OS.get_environment("TLM_CONTEXT_TEST_ATTACH")=="1":
  manager=load("res://world/suryagarh/player_street_conversation.gd").new();world.add_child(manager)
 if manager==null:
  push_error("World has no PlayerStreetConversation");saves.quit_game(1);return
 if OS.get_environment("TLM_CONTEXT_SAMPLE_AUDIO")=="1":
  var resident_sample:=load("res://assets/audio/dialogue/f1c8f3e6cfb85f3b033a33fa4fc203263ad7ba189b8afc41363a76d766975ada.wav") as AudioStream
  var player_sample:=load("res://assets/audio/dialogue/fae4e2ae6f1f470cf13e952af2750e18f4b8b32db4786a3c9cb32eb2b815c6f3.wav") as AudioStream
  for variant in 2:
   for profile in ["male","male_alt","female","female_alt"]:
    for part in ["hello","farewell","collision","assault"]:manager.streams["%s_%s_%d"%[profile,part,variant]]=resident_sample
    for part in ["question","answer"]:manager.streams["peer_%s_%d_%s"%[profile,variant,part]]=resident_sample
    if OS.get_environment("TLM_CONTEXT_REAL_PASSING")=="1":
     var path: String=ProjectSettings.globalize_path("res://assets/audio/dialogue/context_pass_%s_%d.wav"%[profile,variant])
     manager.streams["pass_%s_%d"%[profile,variant]]=AudioStreamWAV.load_from_file(path)
    else:manager.streams["pass_%s_%d"%[profile,variant]]=resident_sample
    if OS.get_environment("TLM_CONTEXT_REAL_WORKER")=="1":
     var worker_path: String=ProjectSettings.globalize_path("res://assets/audio/dialogue/context_worker_%s_%d.wav"%[profile,variant])
     manager.streams["worker_%s_%d"%[profile,variant]]=AudioStreamWAV.load_from_file(worker_path)
    else:manager.streams["worker_%s_%d"%[profile,variant]]=resident_sample
   for part in ["reply","goodbye","collision","assault","shop"]:manager.streams["arjun_%s_%d"%[part,variant]]=player_sample
   manager.streams["police_collision_%d"%variant]=resident_sample
   manager.streams["police_assault_%d"%variant]=resident_sample
   manager.streams["shop_hello_%d"%variant]=resident_sample
 manager.set_process(false);manager.set_physics_process(false)
 if OS.get_environment("TLM_CONTEXT_REAL_PEER")=="1":
  for profile in ["male"]:
   for part in ["question","answer"]:
    var filename:String="context_peer_%s_0_%s.wav"%[profile,part]
    if profile=="female" and manager.mary_ready:filename="context_mary_peer_female_0_%s.wav"%part
    manager.streams["peer_%s_0_%s"%[profile,part]]=load("res://assets/audio/dialogue/"+filename)
 if OS.get_environment("TLM_CONTEXT_REAL_SHOP")=="1":
  for variant in 2:
   for part in ["shop_hello_%d"%variant,"arjun_shop_%d"%variant]:
    manager.streams[part]=load("res://assets/audio/dialogue/context_"+part+".wav")
 if OS.get_environment("TLM_CONTEXT_REAL_REACTIONS")=="1":
  for kind in ["collision","assault"]:
   for profile in ["male","male_alt","female","female_alt","police"]:
    var filename:String="context_%s_%s_0.wav"%[profile,kind]
    if profile=="female" and manager.mary_ready:filename="context_mary_female_%s_0.wav"%kind
    manager.streams["%s_%s_0"%[profile,kind]]=AudioStreamWAV.load_from_file(ProjectSettings.globalize_path("res://assets/audio/dialogue/"+filename))
   manager.streams["arjun_%s_0"%kind]=AudioStreamWAV.load_from_file(ProjectSettings.globalize_path("res://assets/audio/dialogue/context_arjun_%s_0.wav"%kind))
 var selected:Node
 deadline=Time.get_ticks_msec()+120000
 while selected==null and Time.get_ticks_msec()<deadline:
  for candidate:Node in crowd.members:
   if crowd.available(candidate) and candidate.social_partner==null and candidate.actor.get_meta("combat_faction","")=="indian" and candidate.actor.get_node_or_null("CivilianReaction")!=null:
    if OS.get_environment("TLM_CONTEXT_REAL_PEER")!="1" or manager.resident_profile(candidate.actor)=="male":selected=candidate;break
  if selected==null:await process_frame
 if selected==null:
  push_error("No ordinary resident materialised");saves.quit_game(1);return
 var person:Node3D=selected.actor;selected.set_physics_process(false)
 player.global_position=person.global_position+Vector3(.9,0,0);player.velocity=Vector3.ZERO
 player.set_meta("story_cinematic",false);player.set_meta("opening_active",false);player.set_meta("document_busy",false);player.remove_meta("mounted_vehicle")
 manager.age=20;manager.passing_next=0;manager.passing_seen.clear()
 check(manager.try_passing_response() and manager.passing_voice.playing,"real nearby resident gives a passing response")
 manager.passing_voice.stop()
 check(manager.begin(selected,0),"real nearby resident begins a recorded conversation")
 check(manager.resident_voice.playing and manager.speaker==person,"resident owns the first real positional voice")
 person.travel_speed=1.0;selected._physics_process(.1)
 check(person.travel_speed==0.0 and person.get_meta("player_street_chat",false),"real resident pauses while speaking to the player")
 manager.resident_voice.emit_signal("finished")
 if manager.choice_pending:manager.choose_response(1)
 check(manager.player_voice.playing and manager.caption.text.begins_with("Arjun:"),"Arjun answers with his real stream")
 manager.player_voice.emit_signal("finished")
 check(manager.resident_voice.playing and manager.turn==2,"resident speaks the farewell")
 manager.finish()
 check(not person.has_meta("player_street_chat"),"resident is released back to the existing route")
 # Exercise actual city journey speaking turns with two real residents.
 var other:Node
 deadline=Time.get_ticks_msec()+90000
 while other==null and Time.get_ticks_msec()<deadline:
  for candidate:Node in crowd.members:
   if candidate!=selected and crowd.available(candidate) and candidate.social_partner==null and candidate.actor.get_meta("combat_faction","")=="indian":
    if OS.get_environment("TLM_CONTEXT_REAL_PEER")!="1" or manager.resident_profile(candidate.actor)=="male":other=candidate;break
  if other==null:await process_frame
 if other!=null:
  other.set_physics_process(false);other.actor.global_position=person.global_position+Vector3(1.6,0,0)
  # Social meetings are only created during daytime when both journeys
  # are open; the fixture must not fabricate a meeting during closing.
  if OS.get_environment("TLM_CONTEXT_REAL_PEER")=="1":
   selected.closing=false;other.closing=false
   if crowd.clock!=null:crowd.clock.current_hour=12;crowd.clock.clock_paused=true
  selected.social_partner=other;other.social_partner=selected
  selected.social_speaker=true;other.social_speaker=false
  selected.social_end=crowd.age+10;other.social_end=selected.social_end
  selected.social_voice_sent=false;other.social_voice_sent=false
  if OS.get_environment("TLM_CONTEXT_REAL_PEER")=="1":selected.personal_seed=0;other.personal_seed=0
  selected.converse(.1)
  check(selected.social_voice_sent and manager.peer_voice.playing,"real first resident begins the peer question")
  if OS.get_environment("TLM_CONTEXT_REAL_PEER")!="1":crowd.age+=2.8
  selected.converse(.1);other.converse(.1)
  check(person.get_meta("street_action","")=="talking" and other.actor.get_meta("street_action","")=="listening","speaker and listener gestures follow the active peer voice")
  if OS.get_environment("TLM_CONTEXT_REAL_PEER")=="1":
   print("PEER PRECHECK closing=",selected.closing,"/",other.closing," available=",crowd.available(selected),"/",crowd.available(other)," hour=",crowd.clock.current_hour if crowd.clock!=null else -1)
   var peer_deadline:int=Time.get_ticks_msec()+25000
   var saw_answer:=false
   var previous_state:=""
   while Time.get_ticks_msec()<peer_deadline:
    await physics_frame
    if not is_instance_valid(selected.social_partner) or not is_instance_valid(other.social_partner):break
    selected._physics_process(1.0/60.0);other._physics_process(1.0/60.0)
    if other.social_voice_sent and manager.peer_voice.playing and manager.peer_journey==other:saw_answer=true
    var state:String="playing=%s first=%s second=%s partner=%s speaker=%s"%[manager.peer_voice.playing,selected.social_voice_sent,other.social_voice_sent,is_instance_valid(selected.social_partner),"first" if manager.peer_journey==selected else "second" if manager.peer_journey==other else "none"]
    if state!=previous_state:print("PEER TRACE ",state," remaining=",selected.social_end-crowd.age);previous_state=state
    if saw_answer and not manager.peer_voice.playing:break
   print("PEER RESULT saw_answer=",saw_answer," playing=",manager.peer_voice.playing," partner=",is_instance_valid(selected.social_partner)," remaining=",selected.social_end-crowd.age)
   check(saw_answer and not manager.peer_voice.playing and is_instance_valid(selected.social_partner),"real peer WAVs play question then answer without meeting truncation")
  else:
   manager.peer_voice.stop();other.converse(.1)
   check(other.social_voice_sent and manager.peer_voice.playing,"real second resident answers on its speaking turn")
  manager.peer_voice.stop();selected.social_partner=null;other.social_partner=null
 else:check(false,"second peer resident was not available")
 manager.next_reaction=0;manager.reaction_cooldowns.clear()
 check(manager.report_collision(person,0) and manager.mode=="collision" and manager.resident_voice.playing,"real resident receives a recorded collision response")
 if OS.get_environment("TLM_CONTEXT_REAL_REACTIONS")=="1":
  check(manager.resident_voice.stream==manager.streams["%s_collision_0"%manager.resident_profile(person)],"collision uses the resident's actual recording")
  manager.resident_voice.emit_signal("finished")
  check(manager.player_voice.playing and manager.player_voice.stream==manager.streams["arjun_collision_0"],"Arjun answers with actual collision WAV")
 manager.finish()
 deadline=Time.get_ticks_msec()+60000
 while (store==null or not store.configured) and Time.get_ticks_msec()<deadline:
  await process_frame;store=world.get_node_or_null("CityWeaponSeller")
 if store!=null and store.configured:
  player.global_position=store.global_position+Vector3(0,0,1)
  check(store.request("shop",player),"actual weapon merchant opens the existing shop")
  manager._process(.1)
  check(manager.mode=="shop" and manager.resident_voice.playing,"actual merchant greeting starts on shop entry")
  if OS.get_environment("TLM_CONTEXT_REAL_SHOP")=="1":
   check(manager.resident_voice.stream==manager.streams["shop_hello_0"],"merchant uses the actual imported shop greeting")
  manager.resident_voice.emit_signal("finished")
  check(manager.player_voice.playing and manager.caption.text.begins_with("Arjun:"),"Arjun responds while the shop remains open")
  if OS.get_environment("TLM_CONTEXT_REAL_SHOP")=="1":check(manager.player_voice.stream==manager.streams["arjun_shop_0"],"Arjun uses the actual imported shop response")
  store.close_shop();manager._process(.1)
  check(manager.turn==-1 and not manager.player_voice.playing,"closing the actual shop stops the exchange")
  if OS.get_environment("TLM_CONTEXT_REAL_SHOP")=="1":
   check(store.request("shop",player),"actual merchant shop reopens")
   manager._process(.1)
   check(manager.mode=="shop" and manager.resident_voice.stream==manager.streams["shop_hello_1"],"second shop visit uses its distinct actual greeting")
   manager.resident_voice.emit_signal("finished")
   check(manager.player_voice.playing and manager.player_voice.stream==manager.streams["arjun_shop_1"],"second shop visit uses its matching actual reply")
   store.close_shop();manager._process(.1)
 else:check(false,"weapon merchant was not ready")
 # Use the production damage owner on a real civilian, not only a mock method.
 player.global_position=person.global_position+Vector3(.9,0,0)
 manager.next_assault=0;manager.reaction_cooldowns.clear();manager.watched_vitals.clear()
 if OS.get_environment("TLM_CONTEXT_REAL_REACTIONS")=="1":manager.last_reaction["%d:assault"%person.get_instance_id()]=1
 manager.watch_person(person)
 var vitality:Node=person.get_node_or_null("Vitality")
 if vitality!=null:
  var accepted:bool=vitality.receive_hit(5.0,player,"punch")
  manager.observe_hits()
  check(accepted and manager.mode=="assault" and manager.resident_voice.playing,"real NPC health damage triggers the separate assault dialogue")
  if OS.get_environment("TLM_CONTEXT_REAL_REACTIONS")=="1":
   check(manager.resident_voice.stream==manager.streams["%s_assault_0"%manager.resident_profile(person)],"assault uses the resident's actual recording")
   manager.resident_voice.emit_signal("finished")
   check(manager.player_voice.playing and manager.player_voice.stream==manager.streams["arjun_assault_0"],"Arjun answers with actual assault WAV")
  manager.finish()
 else:check(false,"resident has no Vitality damage owner")
 if OS.get_environment("TLM_CONTEXT_REAL_REACTIONS")=="1":
  var officer:Node3D
  deadline=Time.get_ticks_msec()+90000
  while officer==null and Time.get_ticks_msec()<deadline:
   for record:Dictionary in manager.encounters.patrols:
    var candidate:Node3D=record.get("actor")
    if is_instance_valid(candidate) and candidate.get_meta("combat_faction","")=="police" and not candidate.get_meta("dead",false):officer=candidate;break
   if officer==null:await process_frame
  if officer!=null:
   player.global_position=officer.global_position+Vector3(.8,0,0)
   manager.next_reaction=0;manager.reaction_cooldowns.clear()
   check(manager.report_collision(officer,0) and manager.voice_prefix=="police" and manager.resident_voice.stream==manager.streams["police_collision_0"],"real police patrol uses its actual collision warning")
   manager.resident_voice.emit_signal("finished")
   check(manager.player_voice.playing and manager.player_voice.stream==manager.streams["arjun_collision_0"],"Arjun answers actual police warning")
   manager.finish()
  else:check(false,"no police patrol became available")
 if OS.get_environment("TLM_CONTEXT_FLIRT_TEST")=="1":
  var adult:Node
  deadline=Time.get_ticks_msec()+90000
  while adult==null and Time.get_ticks_msec()<deadline:
   for candidate:Node in crowd.members:
    if crowd.available(candidate) and candidate.social_partner==null and candidate.actor.get_meta("adult_character",false) and manager.resident_profile(candidate.actor)=="female":
     adult=candidate;break
   if adult==null:await process_frame
  if adult!=null:
   adult.set_physics_process(false);player.global_position=adult.actor.global_position+Vector3(.8,0,0)
   if OS.get_environment("TLM_CONTEXT_PRODUCTION_MARY")=="1":
    manager.mary_ready=false;manager.end_passing();manager.peer_voice.stop();manager.finish()
    manager.refresh_mary_voice()
    check(manager.mary_ready,"complete imported Mary set activates without forcing readiness")
   else:
    manager.mary_ready=true
    for part in ["mary_flirt_1","arjun_mary_flirt_1"]:
     manager.streams[part]=AudioStreamWAV.load_from_file(ProjectSettings.globalize_path("res://assets/audio/dialogue/context_"+part+".wav"))
    manager.streams["mary_flirt_followup_1"]=load("res://assets/audio/dialogue/f1c8f3e6cfb85f3b033a33fa4fc203263ad7ba189b8afc41363a76d766975ada.wav")
    manager.streams["arjun_mary_flirt_close_1"]=load("res://assets/audio/dialogue/fae4e2ae6f1f470cf13e952af2750e18f4b8b32db4786a3c9cb32eb2b815c6f3.wav")
   var variants:int=4 if OS.get_environment("TLM_CONTEXT_PRODUCTION_MARY")=="1" and OS.get_environment("TLM_CONTEXT_FIRST_EXTENDED")!="1" else 1
   for variant in variants:
    check(manager.begin_flirt(adult,variant) and manager.resident_voice.playing,"real adult female begins Mary exchange %d"%variant)
    if OS.get_environment("TLM_CONTEXT_PRODUCTION_MARY")=="1":
     check(manager.resident_voice.stream.resource_path.ends_with("context_mary_flirt_%d.wav"%[variant+1]),"normal resource loader selects Mary recording %d"%variant)
    manager.resident_voice.emit_signal("finished")
    if manager.choice_pending:manager.choose_response(1)
    check(manager.player_voice.playing and manager.caption.text.begins_with("Arjun:"),"Arjun answers exchange %d"%variant)
    if OS.get_environment("TLM_CONTEXT_PRODUCTION_MARY")=="1":
     check(manager.player_voice.stream.resource_path.ends_with("context_arjun_mary_flirt_%d.wav"%[variant+1]),"normal resource loader selects Arjun recording %d"%variant)
    manager.player_voice.emit_signal("finished")
    check(manager.turn==2 and manager.resident_voice.playing,"resident continues exchange %d"%variant)
    if OS.get_environment("TLM_CONTEXT_PRODUCTION_MARY")=="1":
     check(manager.resident_voice.stream.resource_path.ends_with("context_mary_flirt_followup_%d.wav"%[variant+1]),"normal resource loader selects Mary follow-up %d"%variant)
    manager.resident_voice.emit_signal("finished")
    check(manager.turn==3 and manager.player_voice.playing,"Arjun closes exchange %d"%variant)
    if OS.get_environment("TLM_CONTEXT_PRODUCTION_MARY")=="1":
     check(manager.player_voice.stream.resource_path.ends_with("context_arjun_mary_flirt_close_%d.wav"%[variant+1]),"normal resource loader selects Arjun closing %d"%variant)
    manager.player_voice.emit_signal("finished")
    check(manager.turn==-1,"four-turn exchange %d completes"%variant)
    manager.finish()
   if OS.get_environment("TLM_CONTEXT_PRODUCTION_MARY")=="1":
    check(manager.begin(adult,0) and manager.resident_voice.playing,"normal Mary greeting starts with imported recording")
    check(manager.resident_voice.stream.resource_path.ends_with("context_mary_female_hello_0.wav"),"ordinary greeting uses Mary")
    manager.resident_voice.emit_signal("finished")
    if manager.choice_pending:manager.choose_response(1)
    check(manager.player_voice.playing and manager.player_voice.stream.resource_path.ends_with("context_arjun_reply_0.wav"),"ordinary greeting uses Arjun's real response")
    manager.finish()
    # Exercise the same standing/proximity path used in ordinary play.
    player.global_position=adult.actor.global_position+Vector3(.25,0,0);player.velocity=Vector3.ZERO
    # Teleporting in the fixture requires the real proximity index to refresh;
    # normal walking lets its regular quarter-second refresh keep up.
    crowd.index_age=0
    for frame in 3:await process_frame
    var identity:int=int(adult.actor.get_meta("population_index",str(adult.actor.name).hash()))
    manager.age=120.0*float(5-posmod(identity,5));manager.next_time=0;manager.still=2.0;manager.poll=0;manager.per_person.clear()
    manager._process(.1)
    check(manager.mode=="flirt" and manager.speaker==adult.actor and manager.resident_voice.playing,"real proximity triggers imported Mary exchange without forced readiness")
    if manager.mode=="flirt":
     adult.actor.travel_speed=1.0;adult._physics_process(.1)
     check(adult.actor.travel_speed==0.0 and adult.actor.get_meta("player_street_chat",false),"adult resident stops during automatic exchange")
    manager.finish()
    check(not adult.actor.has_meta("player_street_chat"),"automatic exchange releases the real resident")
    if OS.get_environment("TLM_CONTEXT_REAL_CHOICES")=="1":
     check(manager.begin_flirt(adult,0),"real adult choice conversation starts")
     manager.resident_voice.emit_signal("finished")
     check(manager.choice_pending and manager.choice_label.visible,"actual conversation displays two choices")
     var visual:Node=player.get_node("VisualRoot/CharacterVisual")
     var previous_weapon:int=visual.equipment.selected
     var choice:=InputEventKey.new();choice.physical_keycode=KEY_2;choice.pressed=true
     Input.parse_input_event(choice);await process_frame
     check(visual.equipment.selected==previous_weapon,"choice input does not switch the player's weapon")
     check(manager.mode=="flirt_busy" and manager.player_voice.playing and manager.player_voice.stream.resource_path.ends_with("context_arjun_choice_busy.wav"),"busy choice plays actual Arjun recording")
     manager.player_voice.emit_signal("finished")
     check(manager.resident_voice.playing and manager.resident_voice.stream.resource_path.ends_with("context_mary_depart_0.wav"),"resident answers busy choice with actual goodbye")
     manager.resident_voice.emit_signal("finished")
     check(manager.turn==-1 and not adult.actor.has_meta("player_street_chat"),"busy choice completes and releases real resident")
   adult.set_physics_process(true)
  else:check(false,"no eligible adult female resident was available")
 # Mary activation clears the stream cache; restore fixture-only worker
 # samples for this unrelated behavior check, never for the Mary exchange.
 if OS.get_environment("TLM_CONTEXT_SAMPLE_AUDIO")=="1" and OS.get_environment("TLM_CONTEXT_PRODUCTION_MARY")=="1":
  var worker_sample:=load("res://assets/audio/dialogue/f1c8f3e6cfb85f3b033a33fa4fc203263ad7ba189b8afc41363a76d766975ada.wav") as AudioStream
  for variant in 2:
   for profile in ["male","male_alt","female","female_alt"]:manager.streams["worker_%s_%d"%[profile,variant]]=worker_sample
 # Exercise the real daily worker owner and release its existing schedule.
 var workers:Node=world.get_node_or_null("VillageDailyActivities")
 if workers!=null and not workers.residents.is_empty():
  var worker:Node3D=workers.residents[0]
  var activity:Node=worker.get_node_or_null("DailyActivity")
  if activity!=null:
   activity.set_physics_process(false)
   player.global_position=worker.global_position+Vector3(1,0,0)
   worker.set_meta("daily_activity","hoe");manager.passing_next=0;manager.passing_seen.clear()
   check(manager.try_worker_response() and worker.get_meta("player_conversation",false),"real working resident begins a greeting")
   activity._physics_process(.1)
   check(worker.travel_speed==0.0,"real worker pauses during greeting")
   manager.end_passing()
   check(not worker.has_meta("player_conversation"),"real worker activity is released after greeting")
   activity.set_physics_process(true)
  else:check(false,"daily worker activity is missing")
 else:check(false,"village workers are not available")
 print("PLAYER STREET WORLD ","PASS" if errors.is_empty() else "FAIL"," resident=",person.name," errors=",errors)
 await load("res://tools/test_audio_cleanup.gd").finish(self,0 if errors.is_empty() else 1)
