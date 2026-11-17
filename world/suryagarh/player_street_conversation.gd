extends Node
## Bounded, interruptible nearby resident/Arjun exchanges; owns no schedules.
const FaceExpression=preload("res://story/dialogue_expression.gd")
const RADIUS := 3.0
const LEAVE_RADIUS := 7.0
const GLOBAL_COOLDOWN := 45.0
const PERSON_COOLDOWN := 120.0
const WORKER_LINES := [
 ["Good day. How are you?", "I am well, thank you. How is the work going?", "It keeps me busy, but I am glad to see you.", "I will let you get back to it. Take care."],
 ["Hello. I must get back to my work.", "Of course. Is everything all right here?", "Yes, thank you. There is just much to do.", "Then I will not keep you. See you later."]
]
const SHOP_LINES := [["Welcome. What would you like to see?", "Let me see what you have."], ["Good day. Are you looking for anything?", "Show me what is available, please."]]
const COLLISIONS := ["Please, watch where you are going!", "Careful there, you nearly knocked me over!"]
const POLICE_WARNINGS := ["Watch where you are going.", "Be careful there. Keep your distance."]
const ASSAULTS := ["Why did you strike me?", "Leave me alone!"]
const POLICE_ASSAULTS := ["Do not strike an officer!", "Stop! You will answer for that!"]
const ASSAULT_REPLIES := ["I am sorry. I should not have done that.", "Stay out of my way."]
const COLLISION_REPLIES := ["I am sorry. Are you all right?", "Mind your own way, then."]
const MARY_DEPARTURES := ["It was lovely seeing you. Take care, Arjun.", "Come by again when you have time. Goodbye."]
const FLIRT_LINES := [
 ["You always make me smile, Arjun. Will you stay and talk a little longer?", "Then I would be happy to stay for a while.", "Then tell me, did you find what you were looking for?", "Not yet, but talking with you has made the day kinder."],
 ["There you are. I was beginning to think you had forgotten me.", "Never. It is good to see you again.", "Your family must be glad to have you near.", "They are. Please give your family my regards."],
 ["You are looking rather handsome today. Has someone caught your eye?", "Perhaps I am looking at her.", "Careful, Arjun. I might believe you.", "Then perhaps I should come by again."],
 ["Come back when you have a moment. I would like to hear more of your stories.", "I will. Until then, take care.", "I will hold you to that. Safe travels.", "Until next time. Take care."]
]
const LINES := [
 ["Good day, traveller. Are you keeping well?", "I am well, thank you. How is your family?", "They are well. Safe travels.", "I am glad to hear that. Until we meet again."],
 ["The day is busy. Are you keeping well?", "Well enough, thank you for asking.", "Good. Take care on the road.", "You too. I will let you get back to it."]
]
var viewer: Node3D
var crowd: Node
var encounters: Node
var world_audio: Node
var saves: Node
var player_voice: AudioStreamPlayer3D
var resident_voice: AudioStreamPlayer3D
var peer_voice: AudioStreamPlayer3D
var passing_voice: AudioStreamPlayer3D
var passing_person: WeakRef
var passing_poll := 0.0
var passing_next := 0.0
var passing_seen: Dictionary = {}
var daily_workers: Node
var worker_poll := 0.0
var peer_journey: Node
var speaker: Node3D
var journey: Node
var age := 0.0
var poll := 0.0
var still := 0.0
var next_time := 8.0
var per_person: Dictionary = {}
var last_exchange: Dictionary = {}
var last_reaction: Dictionary = {}
var exchange := -1
var turn := -1
var voice_prefix := ""
var leaving := false
var conversation_has_closing := false
var mode := ""
var last_velocity := Vector3.ZERO
var horse_poll := 0.0
var next_reaction := 0.0
var next_assault := 0.0
var reaction_cooldowns:Dictionary={}
var watched_vitals:Dictionary={}
var hit_poll:=0.0
var asset_check:=0.0
var collision_available:=false
var assault_available:=false
var shop_was_open := false
var shop_visits := 0
var caption: Label
var choice_label: Label
var choices_enabled:=true
var choice_pending:=false
var choice_made:=false
var choice_time:=0.0
var expression: RefCounted
var expression_age:=0.0
var streams:Dictionary={}
var mary_ready:=false

func _ready() -> void:
 name="PlayerStreetConversation"
 viewer=get_parent().get_node_or_null("Player")
 crowd=get_parent().get_node_or_null("PopulationSocial")
 encounters=get_parent().get_node_or_null("CombatEncounters")
 world_audio=get_tree().root.get_node_or_null("WorldAudio")
 saves=get_tree().root.get_node_or_null("SaveManager")
 player_voice=AudioStreamPlayer3D.new();player_voice.max_distance=14;player_voice.unit_size=4;add_child(player_voice)
 resident_voice=AudioStreamPlayer3D.new();resident_voice.max_distance=14;resident_voice.unit_size=4;add_child(resident_voice)
 peer_voice=AudioStreamPlayer3D.new();peer_voice.max_distance=14;peer_voice.unit_size=4;peer_voice.volume_db=-8;add_child(peer_voice)
 passing_voice=AudioStreamPlayer3D.new();passing_voice.max_distance=14;passing_voice.unit_size=4;passing_voice.volume_db=-8;add_child(passing_voice)
 passing_voice.finished.connect(end_passing)
 player_voice.finished.connect(_next_turn);resident_voice.finished.connect(_next_turn)
 var layer:=CanvasLayer.new();layer.layer=34;add_child(layer)
 caption=Label.new();layer.add_child(caption)
 caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 caption.offset_left=75;caption.offset_right=-75;caption.offset_top=-135;caption.offset_bottom=-45
 caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 caption.add_theme_font_size_override("font_size",23);caption.add_theme_constant_override("outline_size",6);caption.hide()
 choice_label=Label.new();layer.add_child(choice_label)
 choice_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 choice_label.offset_left=75;choice_label.offset_right=-75;choice_label.offset_top=-200;choice_label.offset_bottom=-145
 choice_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;choice_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 choice_label.add_theme_font_size_override("font_size",20);choice_label.add_theme_constant_override("outline_size",6);choice_label.hide()

# Switch the primary female voice only when the entire matching set is
# imported. This avoids changing a character voice halfway through a scene.
func refresh_mary_voice() -> void:
 if mary_ready or turn>=0 or passing_voice.playing or peer_voice.playing:return
 var parts:Array[String]=[]
 for variant in 2:
  for kind in ["hello","farewell","collision","assault"]:parts.append("female_%s_%d"%[kind,variant])
  parts.append("pass_female_%d"%variant);parts.append("worker_female_%d"%variant)
  for kind in ["question","answer"]:parts.append("peer_female_%d_%s"%[variant,kind])
 for part in parts:
  if not ResourceLoader.exists("res://assets/audio/dialogue/context_mary_"+part+".wav"):return
 mary_ready=true
 streams.clear()

# Cache imported clips per world; absent recordings never play placeholder audio.
func voice_for(part:String) -> AudioStream:
 if streams.has(part):return streams[part]
 var female_line:bool=part.begins_with("female_") or part.begins_with("pass_female_") or part.begins_with("worker_female_") or part.begins_with("worker_followup_female_") or part.begins_with("peer_female_")
 # Alternate female profiles retain their own distinct voice.
 if part.begins_with("female_alt_") or part.begins_with("pass_female_alt_") or part.begins_with("worker_female_alt_") or part.begins_with("worker_followup_female_alt_") or part.begins_with("peer_female_alt_"):female_line=false
 var path: String="res://assets/audio/dialogue/context_"+("mary_" if mary_ready and female_line else "")+part+".wav"
 if not ResourceLoader.exists(path):return null
 var result:=load(path) as AudioStream
 if result!=null:streams[part]=result
 return result

func blocked() -> bool:
 if not is_instance_valid(viewer) or not is_instance_valid(crowd):return true
 if is_instance_valid(saves) and int(saves.get("pending_slot"))>=0:return true
 if is_instance_valid(world_audio) and world_audio.has_method("is_opening_quiet") and world_audio.is_opening_quiet():return true
 return viewer.get_meta("opening_active",false) or viewer.get_meta("story_cinematic",false) or viewer.get_meta("document_busy",false) or viewer.get_meta("map_open",false) or viewer.get_meta("dead",false)

func mounted() -> Node:
 return viewer.get_meta("mounted_vehicle") if is_instance_valid(viewer) and viewer.has_meta("mounted_vehicle") else null

func _input(event:InputEvent) -> void:
 if not choice_pending:return
 var selection:=0
 if event is InputEventKey and event.pressed and not event.echo:
  var key:int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
  if key==KEY_1:selection=1
  elif key==KEY_2:selection=2
 elif event is InputEventJoypadButton and event.pressed:
  if event.button_index==JOY_BUTTON_A:selection=1
  elif event.button_index==JOY_BUTTON_B:selection=2
 if selection>0:
  choose_response(selection);get_viewport().set_input_as_handled()

func choose_response(selection:int) -> void:
 if not choice_pending or selection not in [1,2]:return
 choice_pending=false;choice_label.hide();choice_made=true
 if selection==1:
  turn=0;_next_turn()
 else:
  mode="flirt_busy" if mode=="flirt" else "conversation_busy"
  turn=-1;_next_turn()

func _process(delta:float) -> void:
 age+=delta
 if expression!=null and is_instance_valid(speaker):
  expression_age+=delta
  var speaking_weight:=0.0
  if resident_voice.playing and resident_voice.stream!=null:
   speaking_weight=FaceExpression.speech_weight(resident_voice.get_playback_position(),resident_voice.stream.get_length())
  var warmth:float=.45 if mode in ["flirt","flirt_busy","flirt_departure"] else .12
  var concern:float=.4 if mode=="assault" else 0.0
  expression.apply(concern,0.0,0.0,speaking_weight,FaceExpression.blink_weight(expression_age),warmth)
 if choice_pending:
  choice_time+=delta
  if choice_time>=8.0:choose_response(2)
 if passing_voice.playing:
  var passing_actor:Node3D=passing_person.get_ref() if passing_person!=null else null
  if blocked() or not is_instance_valid(passing_actor) or passing_actor.get_meta("dead",false) or passing_actor.get_meta("knocked_out",false) or passing_actor.get_meta("civilian_reacting",false) or viewer.global_position.distance_squared_to(passing_actor.global_position)>196.0:
   end_passing()
  else:passing_voice.global_position=passing_actor.global_position+Vector3.UP*1.35
 if peer_voice.playing:
  if blocked() or not is_instance_valid(peer_journey) or not is_instance_valid(peer_journey.actor) or not is_instance_valid(peer_journey.social_partner) or viewer.global_position.distance_squared_to(peer_journey.actor.global_position)>256.0:
   peer_voice.stop();peer_journey=null
  else:peer_voice.global_position=peer_journey.actor.global_position+Vector3.UP*1.35
 asset_check-=delta
 if asset_check<=0:
  asset_check=5.0
  refresh_mary_voice()
  collision_available=voice_for("arjun_collision_0")!=null or voice_for("arjun_collision_1")!=null
  assault_available=voice_for("arjun_assault_0")!=null or voice_for("arjun_assault_1")!=null
 if blocked() or not assault_available:watched_vitals.clear()
 else:
  hit_poll-=delta
  if hit_poll<=0:hit_poll=.25;observe_hits()
 var shop_open:bool=is_instance_valid(viewer) and viewer.get_meta("weapon_shop_open",false)
 if shop_open and not shop_was_open:
  shop_was_open=true;begin_shop()
 elif not shop_open:shop_was_open=false
 if turn>=0:
  if (blocked() and mode!="shop") or (mode=="shop" and (not shop_open or viewer.get_meta("story_cinematic",false))) or not is_instance_valid(speaker) or speaker.get_meta("dead",false) or speaker.get_meta("knocked_out",false) or (mode in ["conversation","flirt","flirt_departure","conversation_busy","flirt_busy","worker"] and (speaker.get_meta("civilian_reacting",false) or is_instance_valid(mounted()))):
   finish();return
  var distance:float=viewer.global_position.distance_squared_to(speaker.global_position)
  if distance>196.0:finish();return
  if mode=="flirt" and distance>LEAVE_RADIUS*LEAVE_RADIUS and not leaving:
   var goodbye:=voice_for("mary_depart_%d"%[exchange%2])
   if goodbye==null:finish();return
   choice_pending=false;choice_label.hide();choice_made=true
   leaving=true;mode="flirt_departure"
   player_voice.stop();resident_voice.stop();turn=-1;_next_turn()
  if mode=="worker" and distance>LEAVE_RADIUS*LEAVE_RADIUS and not leaving:
   leaving=true
   if turn<3:
    player_voice.stop();resident_voice.stop();turn=2;_next_turn()
  if mode=="conversation" and distance>LEAVE_RADIUS*LEAVE_RADIUS and not leaving:
   # The listener is leaving; use the matching short farewell and do not
   # continue into a reply after the resident has said goodbye.
   choice_pending=false;choice_label.hide();choice_made=true
   leaving=true
   if turn<2:
    player_voice.stop();resident_voice.stop();turn=1;_next_turn()
  if resident_voice.playing:resident_voice.global_position=speaker.global_position+Vector3.UP*1.35
  if player_voice.playing:player_voice.global_position=viewer.global_position+Vector3.UP*1.35
  return
 if blocked() or shop_open or is_instance_valid(mounted()):still=0;return
 var velocity:Vector3=viewer.get("velocity") if viewer.get("velocity") is Vector3 else Vector3.ZERO
 if velocity.length_squared()>.04:
  still=0;passing_poll-=delta
  if passing_poll<=0:
   passing_poll=.5;try_passing_response()
  return
 still+=delta;poll-=delta;worker_poll-=delta
 if still>=2.0 and worker_poll<=0:
  worker_poll=.5
  if try_worker_response():return
 if still<2.0 or age<next_time or poll>0:return
 poll=.5
 var best:Node;var closest:=RADIUS*RADIUS
 for candidate:Node in crowd.neighbours(viewer.global_position):
  if not crowd.available(candidate) or candidate.social_partner!=null:continue
  var person:Node3D=candidate.actor
  if person.get_meta("combat_faction","") in ["british","police"]:continue
  if person.get_meta("mission_active",false) or person.get_meta("speaking",false) or age<float(per_person.get(person.get_instance_id(),0.0)):continue
  var distance:float=person.global_position.distance_squared_to(viewer.global_position)
  if distance<closest:closest=distance;best=candidate
 if is_instance_valid(best):
  var person:Node3D=best.actor
  var identity:int=int(person.get_meta("population_index",str(person.name).hash()))
  var playful:bool=person.get_meta("adult_character",false) and resident_profile(person)=="female" and posmod(identity+int(age/120.0),5)==0
  if not playful or not begin_flirt(best):begin(best)

# Release only the temporary attention flag; the worker retains its schedule.
func end_passing() -> void:
 passing_voice.stop()
 var person:Node3D=passing_person.get_ref() if passing_person!=null else null
 if is_instance_valid(person):person.remove_meta("player_conversation")
 passing_person=null

func worker_exchange_ready(profile:String,variant:int) -> bool:
 for part in ["worker_%s_%d"%[profile,variant],"arjun_worker_reply_%d"%variant,"worker_followup_%s_%d"%[profile,variant],"arjun_worker_close_%d"%variant]:
  if voice_for(part)==null:return false
 return true

func try_worker_response() -> bool:
 if blocked() or age<passing_next or turn>=0 or passing_voice.playing or peer_voice.playing:return false
 if not is_instance_valid(daily_workers):daily_workers=get_parent().get_node_or_null("VillageDailyActivities")
 if not is_instance_valid(daily_workers):return false
 var best:Node3D;var closest:=9.0
 for person:Node3D in daily_workers.residents:
  if not is_instance_valid(person) or person.get_meta("dead",false) or person.get_meta("knocked_out",false) or person.get_meta("civilian_reacting",false) or person.get_meta("mission_active",false):continue
  var activity:String=str(person.get_meta("daily_activity",""))
  if activity.is_empty() or activity.begins_with("going_") or activity=="waiting_for_clear_path":continue
  if age<float(passing_seen.get(person.get_instance_id(),0.0)):continue
  var distance:=person.global_position.distance_squared_to(viewer.global_position)
  if distance<closest and clear_sight(person):closest=distance;best=person
 if not is_instance_valid(best):return false
 var identity:=best.get_instance_id()
 var variant:=posmod(int(best.get_meta("population_index",str(best.name).hash()))+int(age/30.0),2)
 var profile:=resident_profile(best)
 var extended:=worker_exchange_ready(profile,variant)
 if not extended and worker_exchange_ready(profile,1-variant):variant=1-variant;extended=true
 if extended:
  if passing_seen.size()>256:passing_seen.clear()
  passing_seen[identity]=age+90.0;passing_next=age+15.0
  peer_voice.stop();peer_journey=null;end_passing()
  speaker=best;journey=null;voice_prefix=profile;exchange=variant;mode="worker";leaving=false;turn=-1
  best.set_meta("player_conversation",true);_next_turn();return true
 # Until the full recorded exchange exists, retain the established short call.
 var clip:=voice_for("worker_%s_%d"%[profile,variant])
 if clip==null:clip=voice_for("worker_%s_%d"%[profile,1-variant])
 if clip==null:return false
 if passing_seen.size()>256:passing_seen.clear()
 passing_seen[identity]=age+90.0;passing_next=age+15.0
 best.set_meta("player_conversation",true)
 passing_person=weakref(best);passing_voice.stream=clip
 passing_voice.global_position=best.global_position+Vector3.UP*1.35;passing_voice.play()
 return true

# Brief responses follow existing walkers without pausing or changing their routes.
func try_passing_response() -> bool:
 if blocked() or age<passing_next or turn>=0 or passing_voice.playing or peer_voice.playing:return false
 var best:Node;var closest:=4.0
 for candidate:Node in crowd.neighbours(viewer.global_position):
  if not crowd.available(candidate) or candidate.social_partner!=null:continue
  var person:Node3D=candidate.actor
  if person.get_meta("combat_faction","") in ["british","police"] or person.get_meta("mission_active",false) or person.get_meta("speaking",false):continue
  if age<float(passing_seen.get(person.get_instance_id(),0.0)):continue
  var distance:=person.global_position.distance_squared_to(viewer.global_position)
  if distance<closest and clear_sight(person):closest=distance;best=candidate
 if not is_instance_valid(best):return false
 var person:Node3D=best.actor
 var identity:=person.get_instance_id()
 var variant:=posmod(int(person.get_meta("population_index",identity))+int(age/30.0),2)
 var clip:=voice_for("pass_%s_%d"%[resident_profile(person),variant])
 if clip==null:clip=voice_for("pass_%s_%d"%[resident_profile(person),1-variant])
 if clip==null:return false
 if passing_seen.size()>256:passing_seen.clear()
 passing_seen[identity]=age+90.0;passing_next=age+12.0
 passing_person=weakref(person);passing_voice.stream=clip
 passing_voice.global_position=person.global_position+Vector3.UP*1.35;passing_voice.play()
 return true

# Avoid starting a face-to-face exchange through a closed door or wall.
func clear_sight(person:Node3D) -> bool:
 if not is_instance_valid(viewer) or not is_instance_valid(person):return false
 var query:=PhysicsRayQueryParameters3D.create(viewer.global_position+Vector3.UP*1.2,person.global_position+Vector3.UP*1.2,1)
 var excluded:Array[RID]=[]
 if viewer is CollisionObject3D:excluded.append(viewer.get_rid())
 var body:=person.get_node_or_null("BodyCollider") as CollisionObject3D
 if body!=null:excluded.append(body.get_rid())
 query.exclude=excluded
 return viewer.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

# Stable voice assignment follows the actor identity, independent of the line.
func resident_profile(person:Node3D) -> String:
 var gender: String="female" if person.get("movement_profile")==&"female" else "male"
 var identity:int=int(person.get_meta("population_index",str(person.name).hash()))
 return gender+("_alt" if posmod(identity,2)==1 else "")

func begin(candidate:Node, selected: int = -1) -> bool:
 if blocked() or is_instance_valid(mounted()) or not crowd.available(candidate) or candidate.social_partner!=null or not clear_sight(candidate.actor):return false
 speaker=candidate.actor;journey=candidate
 voice_prefix=resident_profile(speaker)
 var identity:int=speaker.get_instance_id()
 exchange=posmod(selected,2) if selected>=0 else 1-int(last_exchange.get(identity,posmod(int(speaker.get_meta("population_index",0)),2)))
 # Prefer the alternating variant, but use its complete counterpart if a
 # recording is still being imported or was unavailable at startup.
 var reservation:=exchange_reservation(voice_prefix,exchange)
 if reservation<0 and selected<0:
  exchange=1-exchange;reservation=exchange_reservation(voice_prefix,exchange)
 if reservation<0:speaker=null;journey=null;next_time=age+10.0;return false
 var closing:=voice_for("arjun_goodbye_%d"%exchange)
 conversation_has_closing=closing!=null
 if conversation_has_closing:reservation+=closing.get_length()
 if per_person.size()>256:per_person.clear();last_exchange.clear()
 per_person[identity]=age+PERSON_COOLDOWN;last_exchange[identity]=exchange
 next_time=age+GLOBAL_COOLDOWN
 journey.social_cooldown=maxf(journey.social_cooldown,crowd.age+reservation)
 peer_voice.stop();peer_journey=null;end_passing()
 speaker.set_meta("player_street_chat",true)
 mode="conversation";leaving=false;choice_made=false;turn=-1;_next_turn();return true

func exchange_reservation(prefix:String,variant:int) -> float:
 var duration:=2.0
 for part in ["%s_hello_%d"%[prefix,variant],"arjun_reply_%d"%variant,"%s_farewell_%d"%[prefix,variant]]:
  var stream:=voice_for(part)
  if stream==null:return -1.0
  duration+=stream.get_length()
 return duration

func flirt_reservation(choice:int) -> float:
 var index:=choice+1
 var duration:=2.0
 for part in ["mary_flirt_%d"%index,"arjun_mary_flirt_%d"%index,"mary_flirt_followup_%d"%index,"arjun_mary_flirt_close_%d"%index]:
  var stream:=voice_for(part)
  if stream==null:return -1.0
  duration+=stream.get_length()
 return duration

# Playful exchanges are limited to explicitly adult, primary-female residents.
# Missing recordings fall back to the ordinary conversation instead of silence.
func begin_flirt(candidate:Node, selected:int=-1) -> bool:
 if not mary_ready or blocked() or is_instance_valid(mounted()) or not crowd.available(candidate) or candidate.social_partner!=null:return false
 var person:Node3D=candidate.actor
 if not person.get_meta("adult_character",false) or resident_profile(person)!="female" or not clear_sight(person):return false
 var identity:int=person.get_instance_id()
 var choice:int=posmod(selected,4) if selected>=0 else posmod(int(person.get_meta("population_index",identity))+int(age/120.0),4)
 var reservation:=flirt_reservation(choice)
 if reservation<0 and selected<0:
  for offset in range(1,4):
   var other:=posmod(choice+offset,4)
   var other_reservation:=flirt_reservation(other)
   if other_reservation>=0:choice=other;reservation=other_reservation;break
 if reservation<0:return false
 if per_person.size()>256:per_person.clear();last_exchange.clear()
 per_person[identity]=age+PERSON_COOLDOWN;next_time=age+GLOBAL_COOLDOWN
 candidate.social_cooldown=maxf(candidate.social_cooldown,crowd.age+reservation)
 peer_voice.stop();peer_journey=null;end_passing()
 speaker=person;journey=candidate;voice_prefix="mary";exchange=choice;mode="flirt";leaving=false;choice_made=false;turn=-1
 speaker.set_meta("player_street_chat",true)
 _next_turn();return true

# Called only on an existing social speaking turn. Return -1 if this pair has
# no complete recordings (caller retains legacy greetings), 0 if busy, 1 if
# a positional line actually started. Both partners derive the same variant.
func peer_speaking_status(social:Node) -> int:
 if not peer_voice.playing or not is_instance_valid(peer_journey):return -1
 if social==peer_journey:return 1
 if social==peer_journey.social_partner:return 0
 return -1

func try_peer_speech(social:Node) -> int:
 if not is_instance_valid(social) or not is_instance_valid(social.actor) or not is_instance_valid(social.social_partner) or not is_instance_valid(social.social_partner.actor):return -1
 var first:Node=social if social.social_speaker else social.social_partner
 var second:Node=social.social_partner if social.social_speaker else social
 if first.actor.get_meta("combat_faction","") in ["british","police"] or second.actor.get_meta("combat_faction","") in ["british","police"]:return -1
 var variant:int=posmod(first.personal_seed+second.personal_seed,2)
 var question:String="peer_%s_%d_question"%[resident_profile(first.actor),variant]
 var answer:String="peer_%s_%d_answer"%[resident_profile(second.actor),variant]
 var question_stream:=voice_for(question);var answer_stream:=voice_for(answer)
 if question_stream==null or answer_stream==null:
  variant=1-variant
  question_stream=voice_for("peer_%s_%d_question"%[resident_profile(first.actor),variant])
  answer_stream=voice_for("peer_%s_%d_answer"%[resident_profile(second.actor),variant])
 if question_stream==null or answer_stream==null:return -1
 # The responder waits until the question actually started.
 if not social.social_speaker and not first.social_voice_sent:return 0
 if blocked() or turn>=0 or peer_voice.playing or passing_voice.playing or viewer.global_position.distance_squared_to(social.actor.global_position)>196.0:return 0
 if social.social_speaker:
  # Both existing residents remain in their meeting long enough for the
  # recordings and a possible speaking-turn gap, with a bounded extension.
  var end:float=crowd.age+minf(20.0,question_stream.get_length()+answer_stream.get_length()+5.4)
  first.social_end=maxf(first.social_end,end);second.social_end=maxf(second.social_end,end)
 peer_journey=social;peer_voice.stream=question_stream if social.social_speaker else answer_stream
 peer_voice.global_position=social.actor.global_position+Vector3.UP*1.35;peer_voice.play()
 return 1

# Observe the existing weapon merchant panel; do not acquire input or change
# the store transaction. Unfamiliar merchants do not assume Arjun's name.
func shop_ready(choice:int) -> bool:
 return voice_for("shop_hello_%d"%choice)!=null and voice_for("arjun_shop_%d"%choice)!=null

func begin_shop(selected:int=-1) -> bool:
 var store:Node=get_parent().get_node_or_null("CityWeaponSeller")
 if not is_instance_valid(store) or not is_instance_valid(store.seller):return false
 var choice:int=posmod(selected,2) if selected>=0 else posmod(shop_visits,2)
 if not shop_ready(choice) and selected<0:choice=1-choice
 if not shop_ready(choice):return false
 if turn>=0:finish()
 peer_voice.stop();peer_journey=null;end_passing()
 speaker=store.seller;journey=null;voice_prefix="shop";exchange=choice;mode="shop";leaving=false;turn=-1
 shop_visits+=1;next_time=maxf(next_time,age+GLOBAL_COOLDOWN)
 _next_turn();return true

# The existing collision contacts are inspected directly; no world scan is added.
# A mounted horse warning uses the already maintained crowd spatial index.
func _physics_process(delta:float) -> void:
 if not is_instance_valid(viewer) or blocked():return
 if not collision_available:
  if viewer is CharacterBody3D:last_velocity=viewer.velocity
  return
 var mount:Node=mounted()
 if mount is CharacterBody3D and mount.is_in_group("horses"):
  horse_poll-=delta
  if horse_poll<=0 and mount.velocity.length_squared()>9.0:
   horse_poll=.25
   var warned:=false
   for candidate:Node in crowd.neighbours(mount.global_position):
    if not crowd.available(candidate):continue
    if horse_warning(mount,candidate.actor):warned=true;break
   # Police patrols are not registered as ordinary social pedestrians.
   if not warned and is_instance_valid(encounters):
    for record:Dictionary in encounters.patrols:
     var officer:Node3D=record.get("actor")
     if is_instance_valid(officer) and officer.get_meta("combat_faction","")=="police" and horse_warning(mount,officer):break
  last_velocity=Vector3.ZERO;return
 if viewer is CharacterBody3D:
  if last_velocity.length_squared()>=4.84:
   for i in viewer.get_slide_collision_count():
    var collider:Object=viewer.get_slide_collision(i).get_collider()
    if collider is Node and collider.get_parent() is Node3D and report_collision(collider.get_parent()):break
  last_velocity=viewer.velocity

func horse_warning(horse:CharacterBody3D,person:Node3D) -> bool:
 if not is_instance_valid(person):return false
 var offset:=person.global_position-horse.global_position
 if absf(offset.y)>1.5:return false
 offset.y=0
 if offset.length_squared()>=9.0 or offset.dot(horse.velocity)<=0.0:return false
 var ray:=PhysicsRayQueryParameters3D.create(horse.global_position+Vector3.UP*1.2,person.global_position+Vector3.UP*1.2,1)
 var excluded:Array[RID]=[horse.get_rid()]
 var body:=person.get_node_or_null("BodyCollider") as CollisionObject3D
 if body!=null:excluded.append(body.get_rid())
 ray.exclude=excluded
 if not horse.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():return false
 return report_collision(person)

# Track only nearby people already present in the world-scoped index. Keeping a
# weak reference briefly after an NPC begins reacting lets us see the actual
# health change without a world scan or changing the combat owner.
func watch_person(person:Node3D) -> void:
 if not is_instance_valid(person) or person.global_position.distance_squared_to(viewer.global_position)>100.0:return
 var vitality:=person.get_node_or_null("Vitality")
 if vitality==null:return
 var key:=person.get_instance_id()
 if not watched_vitals.has(key):watched_vitals[key]={"actor":weakref(person),"health":float(vitality.health)}

func observe_hits() -> void:
 for key in watched_vitals.keys():
  var record:Dictionary=watched_vitals[key]
  var person:Node3D=record.actor.get_ref()
  if not is_instance_valid(person) or person.global_position.distance_squared_to(viewer.global_position)>144.0:
   watched_vitals.erase(key);continue
  var vitality:=person.get_node_or_null("Vitality")
  if vitality==null:watched_vitals.erase(key);continue
  var health:float=float(vitality.health)
  if health<float(record.health)-.001 and health>0 and person.get_meta("last_attacker",null)==viewer and person.get_meta("last_hit_kind","") not in ["silent_takedown","takedown"]:
   report_reaction(person,"assault")
  record.health=health
 if watched_vitals.size()>128:watched_vitals.clear()
 for candidate:Node in crowd.neighbours(viewer.global_position):
  if is_instance_valid(candidate) and is_instance_valid(candidate.actor):watch_person(candidate.actor)
 if is_instance_valid(encounters):
  for record:Dictionary in encounters.patrols:
   var officer:Node3D=record.get("actor")
   if is_instance_valid(officer) and officer.get_meta("combat_faction","")=="police":watch_person(officer)

func report_collision(person:Node3D, selected:int=-1) -> bool:
 return report_reaction(person,"collision",selected)

func reaction_ready(prefix:String,kind:String,choice:int) -> bool:
 return voice_for("%s_%s_%d"%[prefix,kind,choice])!=null and voice_for("arjun_%s_%d"%[kind,choice])!=null

func report_reaction(person:Node3D,kind:String,selected:int=-1) -> bool:
 if kind not in ["collision","assault"] or blocked() or not is_instance_valid(person):return false
 if age<(next_assault if kind=="assault" else next_reaction):return false
 if person==viewer or person.get_meta("dead",false) or person.get_meta("knocked_out",false) or person.get_meta("mission_active",false):return false
 var faction:String=str(person.get_meta("combat_faction","indian"))
 if faction=="british":return false # Separate British warnings are not recorded yet.
 if person.get_node_or_null("CivilianReaction")==null and faction!="police":return false
 var identity:int=person.get_instance_id()
 var reaction_key: String="%d:%s"%[identity,kind]
 if age<float(reaction_cooldowns.get(reaction_key,0.0)):return false
 var prefix:String="police" if faction=="police" else resident_profile(person)
 var choice:int=posmod(selected,2) if selected>=0 else 1-int(last_reaction.get(reaction_key,posmod(identity,2)))
 if not reaction_ready(prefix,kind,choice) and selected<0:choice=1-choice
 if not reaction_ready(prefix,kind,choice):return false
 if turn>=0:finish()
 peer_voice.stop();peer_journey=null;end_passing()
 speaker=person;journey=null;voice_prefix=prefix;exchange=choice;mode=kind;leaving=false;turn=-1
 if reaction_cooldowns.size()>256:reaction_cooldowns.clear();last_reaction.clear()
 reaction_cooldowns[reaction_key]=age+25.0;last_reaction[reaction_key]=choice
 if kind=="assault":next_assault=age+5.0
 else:next_reaction=age+5.0
 next_time=maxf(next_time,age+GLOBAL_COOLDOWN)
 _next_turn();return true

func _next_turn() -> void:
 if not is_instance_valid(speaker):finish();return
 if expression==null:
  expression=FaceExpression.new();expression.configure(speaker);expression_age=0.0
 speaker.set_meta("speaking",false)
 turn+=1
 if turn==1 and choices_enabled and mode in ["conversation","flirt"] and not choice_made:
  var goodbye:=voice_for("mary_depart_%d"%[exchange%2]) if mode=="flirt" else voice_for("%s_farewell_%d"%[voice_prefix,exchange])
  if goodbye!=null and voice_for("arjun_choice_busy")!=null:
   choice_pending=true;choice_time=0.0
   choice_label.text="[1 / A] Talk more       [2 / B] I need to go"
   choice_label.show();return
 if turn>=(1 if mode=="flirt_departure" else 4 if mode in ["flirt","worker"] or (mode=="conversation" and conversation_has_closing) else 2 if mode in ["collision","assault","shop","flirt_busy","conversation_busy"] else 3):finish();return
 var name:String
 var text:String
 if mode in ["flirt_busy","conversation_busy"]:
  name="arjun_choice_busy" if turn==0 else "mary_depart_%d"%[exchange%2] if mode=="flirt_busy" else "%s_farewell_%d"%[voice_prefix,exchange]
  text="I am sorry, I have to go. Let us talk later." if turn==0 else MARY_DEPARTURES[exchange%2] if mode=="flirt_busy" else LINES[exchange][2]
 elif mode=="flirt_departure":
  name="mary_depart_%d"%[exchange%2]
  text=MARY_DEPARTURES[exchange%2]
 elif mode=="flirt":
  var prefixes: Array[String]=["mary_flirt_","arjun_mary_flirt_","mary_flirt_followup_","arjun_mary_flirt_close_"]
  name=prefixes[turn]+str(exchange+1)
  text=FLIRT_LINES[exchange][turn]
 elif mode=="worker":
  name=("worker_%s_%d"%[voice_prefix,exchange] if turn==0 else "arjun_worker_reply_%d"%exchange if turn==1 else "worker_followup_%s_%d"%[voice_prefix,exchange] if turn==2 else "arjun_worker_close_%d"%exchange)
  text=WORKER_LINES[exchange][turn]
 elif mode=="shop":
  name="shop_hello_%d"%exchange if turn==0 else "arjun_shop_%d"%exchange
  text=SHOP_LINES[exchange][turn]
 elif mode in ["collision","assault"]:
  name="%s_%s_%d"%[voice_prefix,mode,exchange] if turn==0 else "arjun_%s_%d"%[mode,exchange]
  if mode=="assault":text=(POLICE_ASSAULTS[exchange] if voice_prefix=="police" else ASSAULTS[exchange]) if turn==0 else ASSAULT_REPLIES[exchange]
  else:text=(POLICE_WARNINGS[exchange] if voice_prefix=="police" else COLLISIONS[exchange]) if turn==0 else COLLISION_REPLIES[exchange]
 else:
  name=("%s_hello_%d"%[voice_prefix,exchange] if turn==0 else "arjun_reply_%d"%exchange if turn==1 else "%s_farewell_%d"%[voice_prefix,exchange] if turn==2 else "arjun_goodbye_%d"%exchange)
  text=LINES[exchange][turn]
 var stream:=voice_for(name)
 if stream==null:finish();return
 var player_turn:bool=turn==0 if mode in ["flirt_busy","conversation_busy"] else turn%2==1
 var voice:=player_voice if player_turn else resident_voice
 var person:=viewer if player_turn else speaker
 voice.global_position=person.global_position+Vector3.UP*1.35;voice.stream=stream;voice.volume_db=-8;voice.play()
 if not player_turn:speaker.set_meta("speaking",true)
 caption.text=("Arjun: " if player_turn else "Officer: " if voice_prefix=="police" else "Merchant: " if voice_prefix=="shop" else "Resident: ")+text;caption.show()

func finish() -> void:
 if expression!=null:expression.restore();expression=null
 player_voice.stop();resident_voice.stop();caption.hide()
 choice_pending=false;choice_made=false;choice_label.hide()
 if is_instance_valid(speaker):
  speaker.set_meta("speaking",false)
  speaker.remove_meta("player_street_chat")
  if mode=="worker":speaker.remove_meta("player_conversation")
 speaker=null;journey=null;turn=-1;mode="";leaving=false;conversation_has_closing=false;still=0.0

func _exit_tree() -> void:
 if expression!=null:expression.restore();expression=null
