extends Node3D
## A Witness Taken: real combat followed by a physical, saved escort.
const Human = preload("res://characters/human_scene.gd")
const Actor = preload("res://characters/npcs/british/british_npc_actor.gd")
const Nav = preload("res://story/community_navigation.gd")
const Budget = preload("res://systems/simulation_budget.gd")
const Sight = preload("res://systems/visual_perception.gd")
const Route = preload("res://world/suryagarh/settlements/resident_walk_route.gd")
const STAGES = ["locked", "available", "rescue", "escort", "report", "complete", "failed"]
var director: Node
var player: CharacterBody3D
var encounters: Node
var house: Node3D
var witness: Node3D
var enforcer: Node3D
var witness_nav: Node
var enforcer_nav: Node
var stage := "locked"
var pending: Dictionary = {}
var built := false
var building := false
var shelter := Vector3.ZERO
var elapsed := 0.0
var attack_age := 0.0
var hit := false
var engaged := false
var help_awarded := false
var saved_people: Dictionary = {}
var registered_ground: Array[RID] = []
func configure(owner_node: Node) -> void:
 director = owner_node
 player = director.player
 house = director.get_parent().get_node("ChachaHouse")
 encounters = director.get_parent().get_node("CombatEncounters")
 director.add_prompt("witness_start", house.get_node("Chacha").global_position+Vector3(-.8,1,0), "Ask Chacha about the missing witness")
 director.add_prompt("witness_report", house.to_global(Vector3(0,1,9)), "Confirm the witness has reached shelter")
 if not pending.is_empty():
  var data := pending.duplicate(true)
  pending.clear()
  restore_state(data)
func person(label: String, source: String, local: Vector3, faction: String) -> Node3D:
 var person := Actor.new()
 person.name = label
 person.movement_enabled = false
 person.set_meta("entity_id", "community.witness."+label.to_lower())
 person.set_meta("combat_faction", faction)
 person.set_meta("external_combat_motion", true)
 person.set_meta("human_source", source)
 person.add_child(Human.instantiate(source, false))
 add_child(person)
 var at := house.to_global(local)
 at.y = director.get_parent().layout.height(at.x,at.z)
 var support := Route.support(person, at)
 person.global_position = Vector3(at.x, support if is_finite(support) else at.y, at.z)
 person._home = person.position
 var rid: RID = person.body_collider.get_rid()
 encounters.ground_exclusions.append(rid)
 registered_ground.append(rid)
 return person
func build_people() -> void:
 if built or building: return
 building = true
 witness = person("Witness", "res://characters/npcs/households/merchant.glb", Vector3(3,0,26), "indian")
 await get_tree().process_frame
 if is_queued_for_deletion(): return
 enforcer = person("EstateEnforcer", "res://characters/npcs/british/private_man.glb", Vector3(0,0,24), "british")
 await get_tree().process_frame
 if is_queued_for_deletion(): return
 witness_nav = Nav.new()
 add_child(witness_nav)
 witness_nav.configure(witness, encounters)
 enforcer_nav = Nav.new()
 add_child(enforcer_nav)
 enforcer_nav.configure(enforcer, encounters)
 shelter = house.to_global(Vector3(0,0,9))
 var support := Route.support(witness, shelter)
 if is_finite(support): shelter.y = support
 built = true
 building = false
 apply_people()
func can_request(id: String) -> bool:
 if director.stage != "introduced": return false
 if id == "witness_start": return stage in ["available", "failed"]
 if id == "witness_report": return stage == "report" and built and witness.global_position.distance_to(shelter)<1.2
 return false
func request(id: String) -> bool:
 if id == "witness_start" and can_request(id):
  stage = "rescue"
  engaged = false
  saved_people.clear()
  if built:
   reset_people()
  else: build_people()
  director.say("Chacha: An estate enforcer stopped a witness on the approach outside our gate. He intends to take him away. Help him reach our courtyard; I have agreed to shelter him.")
  return true
 if id == "witness_report" and can_request(id):
  stage = "complete"
  if not help_awarded:
   help_awarded = true
   var fame := player.get_node_or_null("FameComponent")
   if fame != null: fame.award_help()
  director.say("Witness: I am safe here. I will speak about what happened when I am ready. Chacha: We will keep watch. Thank you, Arjun.")
  return true
 return false
func defeated(actor: Node3D) -> bool:
 return actor.get_meta("dead", false) or actor.get_meta("knocked_out", false)
func _physics_process(delta: float) -> void:
 if director == null or get_tree().paused: return
 if stage == "locked" and director.stage == "introduced": stage = "available"
 if not built or stage not in ["rescue", "escort"]: return
 elapsed += delta
 if elapsed < Budget.interval(witness, player, player.global_position.distance_to(witness.global_position)<35): return
 delta = elapsed
 elapsed = 0
 if defeated(witness):
  stage = "failed"
  witness_nav.cancel()
  enforcer_nav.cancel()
  return
 if player.health<=0 or player.get_meta("story_cinematic", false) or player.get_meta("detention_action", "")!="":
  witness.travel_speed = 0
  enforcer.travel_speed = 0
  return
 if stage == "rescue":
  if defeated(enforcer):
   stage = "escort"
   enforcer_nav.cancel()
   director.say("Witness: He cannot stop us now. Please walk with me to Chacha’s courtyard.")
   return
  var toward := player.global_position-enforcer.global_position
  if toward.length()<18 and not engaged:
   enforcer.global_rotation.y = atan2(toward.x,toward.z)
  engaged = engaged or (toward.length()<12 and Sight.sees(enforcer,player,18)) or enforcer.has_meta("last_attacker")
  if not engaged: return
  if enforcer.get_meta("grappled",false) or enforcer.get_meta("combat_action", "") == "hit":
   enforcer.travel_speed = 0
   attack_age = 0
   return
  if toward.length()>30:
   enforcer_nav.cancel()
   return
  if toward.length()>1.25:
   enforcer_nav.advance(player.global_position,1.65,delta)
   attack_age = 0
  else:
   enforcer_nav.cancel()
   enforcer.global_rotation.y = atan2(toward.x,toward.z)
   attack_age += delta
   if attack_age>=1.35:
    attack_age=0
    hit=false
    enforcer.combat_react("strike")
   if attack_age>=.28 and attack_age<=.60 and not hit and encounters.strike_hits_player(enforcer):
    hit=true
    player.receive_combat_hit(6,enforcer)
 else:
  if witness.global_position.distance_to(player.global_position)>9:
   witness_nav.cancel()
   return
  if witness_nav.advance(shelter,1.15,delta):
   stage = "report"
   witness_nav.cancel()
func objective() -> String:
 match stage:
  "available": return "Ask Chacha about the missing witness."
  "rescue": return "Free the witness outside Chacha’s gate. Defeat or incapacitate the enforcer."
  "escort": return "Walk with the witness to Chacha’s courtyard. He waits if you move too far away."
  "report": return "Speak in the courtyard to confirm the witness’s safety."
  "failed": return "The witness needs help. Return to Chacha to restart from the rescue checkpoint."
 return ""
func destination() -> Dictionary:
 if stage in ["locked","complete"]: return {}
 var at: Vector3 = director.prompts.witness_start.global_position
 if stage == "rescue" and built: at = witness.global_position+Vector3.UP
 if stage in ["escort","report"] and built: at = shelter+Vector3.UP
 return {"position":at,"label":objective(),"endpoint":""}
func person_state(actor: Node3D) -> Dictionary:
 var vitality: Node = actor.get_node("Vitality")
 var at := actor.global_position
 return {"position":[at.x,at.y,at.z],"rotation":actor.global_rotation.y,"health":vitality.health,"dead":vitality.dead,"knocked_out":actor.get_meta("knocked_out",false)}
func export_state() -> Dictionary:
 if director == null: return pending.duplicate(true)
 var data := {"stage":stage,"engaged":engaged,"help_awarded":help_awarded}
 if built:
  data["witness"] = person_state(witness)
  data["enforcer"] = person_state(enforcer)
 else:
  data.merge(saved_people,true)
 return data
func restore_state(data: Dictionary) -> void:
 if director == null:
  pending = data.duplicate(true)
  return
 var candidate := str(data.get("stage","locked"))
 stage = candidate if candidate in STAGES else "locked"
 engaged = bool(data.get("engaged",false))
 help_awarded = bool(data.get("help_awarded",stage == "complete"))
 saved_people = data.duplicate(true)
 if stage not in ["locked","available"]:
  if not built: build_people()
  else: apply_people()
 elif built:
  witness.hide()
  enforcer.hide()
  witness.process_mode = Node.PROCESS_MODE_DISABLED
  enforcer.process_mode = Node.PROCESS_MODE_DISABLED
func restore_person(actor: Node3D, data: Dictionary) -> void:
 actor.process_mode = Node.PROCESS_MODE_INHERIT
 actor.show()
 var vitality: Node = actor.get_node("Vitality")
 vitality.dead = bool(data.get("dead",false))
 vitality.health = clampf(float(data.get("health",75)),0,75)
 actor.set_meta("dead",vitality.dead)
 actor.set_meta("knocked_out",bool(data.get("knocked_out",false)))
 actor.remove_meta("last_attacker")
 var position_data: Array = data.get("position",[])
 if position_data.size()==3:
  actor.global_position = Vector3(float(position_data[0]),float(position_data[1]),float(position_data[2]))
 actor.global_rotation.y = float(data.get("rotation",actor.global_rotation.y))
 actor.get_node("BodyCollider/BodyShape").set_deferred("disabled",defeated(actor))
 if defeated(actor):
  actor.combat_react("fall" if vitality.dead else "down")
 else:
  var motion: Node = actor.get_node("CombatMotion")
  motion.state = ""
  motion.set_process(false)
  actor.set_meta("combat_action", "")
  actor.animation_tree.active = true
  actor.animation_tree.set("parameters/combat/blend_amount",0.0)
  vitality.set_physics_process(true)
 actor.body_collider.force_update_transform()
func apply_people() -> void:
 witness_nav.cancel()
 enforcer_nav.cancel()
 if stage in ["locked","available"]:
  witness.hide()
  enforcer.hide()
  witness.process_mode = Node.PROCESS_MODE_DISABLED
  enforcer.process_mode = Node.PROCESS_MODE_DISABLED
  return
 for pair in [[witness,"witness"],[enforcer,"enforcer"]]:
  if saved_people.get(pair[1],{}) is Dictionary: restore_person(pair[0],saved_people.get(pair[1],{}))
func reset_people() -> void:
 for pair in [[witness,Vector3(3,0,26)],[enforcer,Vector3(0,0,24)]]:
  var actor: Node3D = pair[0]
  var at: Vector3 = house.to_global(pair[1])
  var support := Route.support(actor,at)
  if is_finite(support): at.y=support
  restore_person(actor,{"position":[at.x,at.y,at.z]})
 witness_nav.cancel()
 enforcer_nav.cancel()

func _exit_tree() -> void:
 if is_instance_valid(encounters):
  for rid in registered_ground: encounters.ground_exclusions.erase(rid)
