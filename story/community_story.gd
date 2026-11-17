extends Node3D
## First playable community handoff. No duplicate humans or frame-wide discovery.
const Prompt = preload("res://story/rebellion_prompt.gd")
const STAGES = ["dormant", "available", "message", "introduced"]
var stage := "dormant"
var configured := false
var pending: Dictionary = {}
var player: CharacterBody3D
var rebellion: Node
var prompts: Dictionary = {}
var subtitle: Label
var dialogue_voice: AudioStreamPlayer
var dialogue_queue: Array[AudioStream]=[]
var remaining := 0.0
var conversation_partner: Node3D
var poll_elapsed := 0.0
var serious_leads: Array[String] = []
var witness_mission: Node
var pending_witness: Dictionary = {}
var uniform_mission: Node
func _ready() -> void:
 name = "CommunityStory"
 dialogue_voice=AudioStreamPlayer.new();dialogue_voice.name="DialogueVoice";add_child(dialogue_voice)
 dialogue_voice.finished.connect(play_next_voice)
 call_deferred("configure")
func configure() -> void:
 var world := get_parent()
 rebellion = world.get_node_or_null("RebellionStory")
 player = world.get_node_or_null("Player")
 var house := world.get_node_or_null("ChachaHouse")
 if rebellion == null or not rebellion.configured or house == null:
  return
 var sites: Node = rebellion.get("sites")
 if not is_instance_valid(sites): return
 var contact: Node3D = sites.get("mangal")
 var chacha: Node3D = house.get_node_or_null("Chacha")
 if not is_instance_valid(contact) or not is_instance_valid(chacha): return
 add_prompt("contact", contact.global_position + Vector3(0,1,0), "Speak to Mangal about the villages")
 add_prompt("message", chacha.global_position + Vector3(.8,1,0), "Deliver Mangal’s message to Chacha")
 var layer := CanvasLayer.new()
 layer.layer = 84
 add_child(layer)
 subtitle = Label.new()
 layer.add_child(subtitle)
 subtitle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
 subtitle.offset_left = 65
 subtitle.offset_right = -65
 subtitle.offset_top = -155
 subtitle.offset_bottom = -45
 subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 subtitle.add_theme_font_size_override("font_size", 23)
 subtitle.add_theme_constant_override("outline_size", 5)
 subtitle.hide()
 if get_parent().has_node("CombatEncounters"):
  witness_mission = preload("res://story/community_witness_mission.gd").new()
  witness_mission.name = "WitnessProtection"
  add_child(witness_mission)
  witness_mission.configure(self)
  if not pending_witness.is_empty(): witness_mission.restore_state(pending_witness)
 uniform_mission = preload("res://story/community_uniform_mission.gd").new()
 uniform_mission.name = "BehindTheUniform"
 add_child(uniform_mission)
 uniform_mission.configure(self)
 configured = true
 if not pending.is_empty():
  var saved := pending.duplicate(true)
  pending.clear()
  restore_state(saved)
func add_prompt(id: String, at: Vector3, text: String) -> void:
 var prompt := Prompt.new()
 prompt.name = id.capitalize() + "CommunityContact"
 prompt.director = self
 prompt.action_id = id
 prompt.interaction_text = text
 prompt.set_meta("entity_id", "community.contact." + id)
 add_child(prompt)
 prompt.global_position = at
 prompts[id] = prompt
func _process(delta: float) -> void:
 if get_tree().paused: return
 if remaining > 0:
  remaining -= delta
  if is_instance_valid(conversation_partner) and is_instance_valid(player):
   if player.global_position.distance_to(conversation_partner.global_position)<4.0 and player.velocity.length()<.2:
    preload("res://story/conversation_facing.gd").pair(player,conversation_partner)
   else:
    preload("res://story/conversation_facing.gd").release(player)
    preload("res://story/conversation_facing.gd").release(conversation_partner)
    conversation_partner=null
  if remaining <= 0:
   if subtitle != null: subtitle.hide()
   preload("res://story/conversation_facing.gd").release(player)
   preload("res://story/conversation_facing.gd").release(conversation_partner)
   conversation_partner=null
 poll_elapsed += delta
 if poll_elapsed < .5: return
 poll_elapsed = 0
 if not configured:
  configure()
  return
 if stage == "dormant" and rebellion.stage == "complete": stage = "available"
func can_request(id: String) -> bool:
 if id=="contact" and not consignment_finished():return false
 if not configured or player == null or player.health <= 0: return false
 if not preload("res://systems/action_permissions.gd").allowed(player, &"interact") or player.get_meta("opening_active", false): return false
 if player.get_meta("detention_action", "") != "" or remaining > 0: return false
 if uniform_mission != null and uniform_mission.can_request(id): return true
 if witness_mission != null and witness_mission.can_request(id): return true
 return (id == "contact" and stage == "available") or (id == "message" and stage == "message")
func request(id: String, actor: CharacterBody3D) -> bool:
 if actor != player or not can_request(id): return false
 if not prompts.has(id): return false
 var prompt: Node3D = prompts[id]
 if actor.global_position.distance_to(prompt.global_position) > 2.6: return false
 if uniform_mission != null and id.begins_with("uniform_"): return uniform_mission.request(id)
 if witness_mission != null and id.begins_with("witness_"): return witness_mission.request(id)
 if id == "contact":
  conversation_partner=rebellion.sites.get("mangal")
  stage = "message"
  say("Mangal: The rifles are here, but the villages need help too. Tell Chacha we can offer shelter to people facing threats. Let him introduce you; do not arrive demanding their stories.")
 else:
  conversation_partner=get_parent().get_node("ChachaHouse/Chacha")
  stage = "introduced"
  serious_leads.assign(["community.behind_uniform", "community.witness_taken", "community.death_inquiry", "community.refusal"])
  say("Chacha: I will ask who wants your help. A woman has survived violence by a soldier, a witness has been taken, and a worker’s family seeks answers. Their wishes come first. We must arrange protection before confronting anyone.")
 sync_clock()
 return true
func sync_clock() -> void:
 var clock: Node=get_parent().get_node_or_null("GameTimeSystem")
 if clock!=null:clock.set_mission_daylight_locked(&"community_message",stage=="message")
func _exit_tree() -> void:
 var clock: Node=get_parent().get_node_or_null("GameTimeSystem")
 if is_instance_valid(clock):clock.set_mission_daylight_locked(&"community_message",false)
func say(text: String) -> void:
 subtitle.text = text
 subtitle.show()
 remaining = 14.0
 dialogue_voice.stop()
 dialogue_queue.clear()
 var parts:=text.split(": ",true,1)
 if parts.size()==2:
  var speaker: String=parts[0]
  var spoken: String=parts[1]
  if speaker=="Witness" and spoken.contains(" Chacha: "):
   var lines:=spoken.split(" Chacha: ",true,1)
   queue_voice(speaker,lines[0])
   queue_voice("Chacha",lines[1])
  elif speaker=="Soldier" and spoken.contains(" Arjun: "):
   var lines:=spoken.split(" Arjun: ",true,1)
   queue_voice(speaker,lines[0])
   var narration:=lines[1].find(" Chacha keeps ")
   queue_voice("Arjun",lines[1].substr(0,narration) if narration>=0 else lines[1])
  elif speaker in ["Mangal","Chacha","Arjun","Witness","Village protector"]:
   queue_voice(speaker,spoken)
 var duration:=0.0
 for stream in dialogue_queue:duration+=stream.get_length()
 remaining=maxf(remaining,duration+.25)
 play_next_voice()

func queue_voice(speaker: String, spoken: String) -> void:
 var key: String=(speaker+"\n"+spoken).sha256_text()
 var path: String="res://assets/audio/dialogue/"+key+".wav"
 if not ResourceLoader.exists(path):return
 var stream:=load(path) as AudioStream
 if stream!=null:dialogue_queue.append(stream)

func play_next_voice() -> void:
 if dialogue_queue.is_empty():return
 dialogue_voice.stream=dialogue_queue.pop_front()
 dialogue_voice.play()

func objective() -> String:
 if uniform_mission != null and not uniform_mission.objective().is_empty(): return uniform_mission.objective()
 if witness_mission != null and not witness_mission.objective().is_empty(): return witness_mission.objective()
 return "Speak to Mangal about helping the villages." if stage == "available" else "Deliver Mangal’s offer of shelter to Chacha." if stage == "message" else ""
func destination() -> Dictionary:
 if stage=="available" and not consignment_finished():return {}
 if not configured: return {}
 if uniform_mission != null:
  var uniform_point: Dictionary = uniform_mission.destination()
  if not uniform_point.is_empty(): return uniform_point
 if witness_mission != null:
  var point: Dictionary = witness_mission.destination()
  if not point.is_empty(): return point
 if stage not in ["available", "message"]: return {}
 var prompt: Node3D = prompts["contact" if stage == "available" else "message"]
 return {"position": prompt.global_position, "label": objective(), "endpoint": ""}
func consignment_finished() -> bool:
 var next_mission=get_parent().get_node_or_null("ConsignmentStory")
 return next_mission==null or next_mission.stage=="complete"
func export_state() -> Dictionary:
 if not configured and not pending.is_empty(): return pending.duplicate(true)
 return {"version": 3, "uniform_mission": uniform_mission.export_state() if uniform_mission != null else {}, "stage": stage, "serious_leads": serious_leads.duplicate(), "witness_mission": witness_mission.export_state() if witness_mission != null else pending_witness.duplicate(true)}
func restore_state(data: Dictionary) -> void:
 if not configured:
  pending = data.duplicate(true)
  return
 var candidate := str(data.get("stage", "dormant"))
 stage = candidate if candidate in STAGES else "dormant"
 sync_clock()
 serious_leads.clear()
 if stage == "introduced":
  serious_leads.assign(["community.behind_uniform", "community.witness_taken", "community.death_inquiry", "community.refusal"])
 pending_witness = data.get("witness_mission",{}).duplicate(true) if data.get("witness_mission",{}) is Dictionary else {}
 if witness_mission != null: witness_mission.restore_state(pending_witness)
 if uniform_mission != null: uniform_mission.restore_state(data.get("uniform_mission",{}) if data.get("uniform_mission",{}) is Dictionary else {})
 remaining = 0
 dialogue_voice.stop()
 dialogue_queue.clear()
 preload("res://story/conversation_facing.gd").release(player)
 preload("res://story/conversation_facing.gd").release(conversation_partner)
 conversation_partner=null
 subtitle.hide()
