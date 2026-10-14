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
var remaining := 0.0
var poll_elapsed := 0.0
var serious_leads: Array[String] = []
var witness_mission: Node
var pending_witness: Dictionary = {}
func _ready() -> void:
 name = "CommunityStory"
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
  if remaining <= 0 and subtitle != null: subtitle.hide()
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
 if witness_mission != null and witness_mission.can_request(id): return true
 return (id == "contact" and stage == "available") or (id == "message" and stage == "message")
func request(id: String, actor: CharacterBody3D) -> bool:
 if actor != player or not can_request(id): return false
 var prompt: Node3D = prompts[id]
 if actor.global_position.distance_to(prompt.global_position) > 2.6: return false
 if witness_mission != null and id.begins_with("witness_"): return witness_mission.request(id)
 if id == "contact":
  stage = "message"
  say("Mangal: The rifles are here, but the villages need help too. Tell Chacha we can offer shelter to people facing threats. Let him introduce you; do not arrive demanding their stories.")
 else:
  stage = "introduced"
  serious_leads.assign(["community.behind_uniform", "community.witness_taken", "community.death_inquiry", "community.refusal"])
  say("Chacha: I will ask who wants your help. A woman has survived violence by a soldier, a witness has been taken, and a worker’s family seeks answers. Their wishes come first. We must arrange protection before confronting anyone.")
 return true
func say(text: String) -> void:
 subtitle.text = text
 subtitle.show()
 remaining = 14.0
func objective() -> String:
 if witness_mission != null and not witness_mission.objective().is_empty(): return witness_mission.objective()
 return "Speak to Mangal about helping the villages." if stage == "available" else "Deliver Mangal’s offer of shelter to Chacha." if stage == "message" else ""
func destination() -> Dictionary:
 if stage=="available" and not consignment_finished():return {}
 if not configured: return {}
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
 return {"version": 2, "stage": stage, "serious_leads": serious_leads.duplicate(), "witness_mission": witness_mission.export_state() if witness_mission != null else pending_witness.duplicate(true)}
func restore_state(data: Dictionary) -> void:
 if not configured:
  pending = data.duplicate(true)
  return
 var candidate := str(data.get("stage", "dormant"))
 stage = candidate if candidate in STAGES else "dormant"
 serious_leads.clear()
 if stage == "introduced":
  serious_leads.assign(["community.behind_uniform", "community.witness_taken", "community.death_inquiry", "community.refusal"])
 pending_witness = data.get("witness_mission",{}).duplicate(true) if data.get("witness_mission",{}) is Dictionary else {}
 if witness_mission != null: witness_mission.restore_state(pending_witness)
 remaining = 0
 subtitle.hide()
