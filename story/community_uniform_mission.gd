extends Node
## Behind the Uniform, protection chapter. The adult survivor speaks by private
## correspondence; no assault reenactment, forced disclosure or invented actor.
const STAGES = ["locked", "notice", "witness", "watch", "return", "protected", "confront", "report", "complete"]
var director: Node
var stage := "locked"
var skipped_details := false
var complaint_authorized := false
var intermediary_offered := false
var testimony_secured := false
var watch_agreed := false
var guard: Node3D
var navigation: Node
var building := false
var saved_guard: Dictionary = {}
var elapsed := 0.0
var attack_age := 0.0
var hit := false

func configure(chapter: Node) -> void:
 director = chapter
 var house: Node3D = chapter.get_parent().get_node("ChachaHouse")
 var chacha: Node3D = house.get_node("Chacha")
 chapter.add_prompt("uniform_start", chacha.global_position+Vector3(0,1,-.8), "Read a private request for help — sensitive subject")
 chapter.add_prompt("uniform_read", chacha.global_position+Vector3(.7,1,-.8), "Read the brief account (non-graphic)")
 chapter.add_prompt("uniform_skip", chacha.global_position+Vector3(-.7,1,-.8), "Skip the account and arrange protection")
 chapter.add_prompt("uniform_witness", house.to_global(Vector3(0,1,9)), "Ask the sheltered witness about the threatening patrol")
 chapter.add_prompt("uniform_watch", house.to_global(Vector3(2,1,17)), "Arrange a watch with the village protectors")
 chapter.add_prompt("uniform_confront", house.to_global(Vector3(0,1,28)), "Challenge the soldier threatening the shelter")
 chapter.add_prompt("uniform_report", chacha.global_position+Vector3(0,1,.8), "Confirm the patrol threat has ended")
 chapter.add_prompt("uniform_private", chacha.global_position+Vector3(-.7,1,.8), "Return the evidence privately; let her decide")
 chapter.add_prompt("uniform_complaint", chacha.global_position+Vector3(.7,1,.8), "Offer a complaint through her chosen intermediary")

func available() -> bool:
 return director.stage == "introduced" and director.witness_mission != null and director.witness_mission.stage == "complete"

func can_request(id: String) -> bool:
 if not available(): return false
 match id:
  "uniform_confront": return stage == "protected"
  "uniform_report": return stage == "report"
  "uniform_start": return stage == "locked"
  "uniform_read", "uniform_skip": return stage == "notice"
  "uniform_witness": return stage == "witness"
  "uniform_watch":
   if stage != "watch" or not director.witness_mission.built: return false
   for member in director.witness_mission.helpers.members:
    if not director.witness_mission.defeated(member) and member.global_position.distance_to(director.prompts.uniform_watch.global_position) < 8: return true
   return false
  "uniform_private", "uniform_complaint": return stage == "return"
 return false

func request(id: String) -> bool:
 if not can_request(id): return false
 match id:
  "uniform_start":
   stage = "notice"
   director.say("Sensitive subject: an adult woman has survived sexual violence. Nothing is shown. Read her brief, non-graphic letter, or skip directly to arranging protection. Both choices keep the mission available.")
  "uniform_read", "uniform_skip":
   skipped_details = id == "uniform_skip"
   stage = "witness"
   director.say("Chacha: She asks for a safe place and a watch against threats. Speak to the sheltered witness about the patrol; do not ask her to repeat her account." if skipped_details else "Her letter: A soldier assaulted me and threatened my household if I spoke. I want safety first. Ask the witness about the threats, but do not carry my name through the village. I will decide whether to complain.")
  "uniform_witness":
   testimony_secured = true
   stage = "watch"
   director.say("Witness: I saw the patrol threaten her household. I did not see the assault. With my permission, Chacha may keep my account of those threats. Arrange a watch before anyone approaches the soldier.")
  "uniform_watch":
   watch_agreed = true
   director.witness_mission.helpers.trusted = true
   stage = "return"
   director.say("Village protector: We agree to watch this shelter. Do not announce her name. Take the witness’s account back to Chacha and let her choose what happens next.")
  "uniform_private", "uniform_complaint":
   # The player's offer is not consent. A complaint remains sealed until her reply.
   complaint_authorized = false
   intermediary_offered = id == "uniform_complaint"
   stage = "protected"
   director.say("Chacha: I will offer her a complaint through an intermediary of her choosing. Nothing will be sent without her permission. The witness’s account stays here; the watch remains agreed." if id == "uniform_complaint" else "Chacha: The account is sealed for her. She asks us to keep it private for now. The watch remains agreed. She may decide differently later; you have not lost her trust by respecting her wishes.")
  "uniform_confront":
   stage = "confront"
   build_guard()
   director.say("Soldier: Hand over the witness or I will drag him out. Arjun: This household is under our protection. Leave them alone. Chacha keeps the woman’s identity and account private.")
  "uniform_report":
   stage = "complete"
   director.say("Chacha: The soldier can no longer carry out his threat. We will keep the watch and the sealed account. She decides whether to complain; defeating him has not made that choice for her. Recovery will take longer than this fight.")
 return true

func build_guard() -> void:
 if building: return
 if is_instance_valid(guard):
  if not guard.visible: director.witness_mission.restore_person(guard,saved_guard)
  return
 var rescue: Node = director.witness_mission
 if not rescue.built: return
 building = true
 guard = rescue.person("ThreateningSoldier", "res://characters/npcs/british/private_man.glb", Vector3(0,0,28), "british")
 guard.set_meta("entity_id", "community.uniform.soldier")
 await get_tree().process_frame
 if is_queued_for_deletion(): return
 navigation = preload("res://story/community_navigation.gd").new()
 add_child(navigation)
 navigation.configure(guard,rescue.encounters)
 rescue.restore_person(guard,saved_guard)
 if stage not in ["confront", "report", "complete"]:
  guard.hide()
  guard.process_mode = Node.PROCESS_MODE_DISABLED
 building = false

func _physics_process(delta: float) -> void:
 if director == null or get_tree().paused: return
 if stage in ["confront", "report", "complete"] and not is_instance_valid(guard):
  build_guard()
 if stage != "confront" or building or not is_instance_valid(navigation): return
 var rescue: Node = director.witness_mission
 if rescue.defeated(guard):
  navigation.cancel()
  stage = "report"
  director.say("Arjun: The threat has stopped. Return to Chacha and check that the household remains protected.")
  return
 var player: CharacterBody3D = director.player
 if player.health <= 0 or player.get_meta("story_cinematic",false) or player.get_meta("detention_action","") != "":
  navigation.cancel()
  return
 elapsed += delta
 if elapsed < preload("res://systems/simulation_budget.gd").interval(guard,player,guard.global_position.distance_to(player.global_position)<35): return
 delta = elapsed
 elapsed = 0
 var victim: Node3D = player
 var attacker: Node = guard.get_meta("last_attacker",null)
 if attacker in rescue.helpers.members and not rescue.defeated(attacker): victim = attacker
 var toward := victim.global_position-guard.global_position
 if toward.length()>28:
  navigation.cancel()
  return
 if not guard.has_meta("last_attacker") and not preload("res://systems/visual_perception.gd").sees(guard,player,18):
  navigation.cancel()
  return
 if guard.get_meta("grappled",false) or guard.get_meta("combat_action","") == "hit":
  navigation.cancel()
  attack_age = 0
  return
 if toward.length()>.95:
  navigation.advance(victim.global_position-toward.normalized()*.65,1.65,delta,.10)
  attack_age = 0
  return
 navigation.cancel()
 guard.global_rotation.y = atan2(toward.x,toward.z)
 attack_age += delta
 if attack_age>=1.35:
  attack_age = 0
  hit = false
  guard.combat_react("strike")
  if victim == player: rescue.helpers.witness_attack(guard)
 var contact: bool = rescue.encounters.strike_hits_player(guard) if victim == player else rescue.encounters.strike_hits_actor(guard,victim)
 if attack_age>=.28 and attack_age<=.60 and not hit and contact:
  hit = true
  if victim == player:
   player.receive_combat_hit(6,guard)
   rescue.helpers.witness_attack(guard)
  else: victim.get_node("Vitality").receive_hit(6,guard,"punch")

func objective() -> String:
 if not available(): return ""
 match stage:
  "protected": return "Stop the soldier threatening the shelter outside the gate."
  "confront": return "Defeat or incapacitate the threatening soldier."
  "report": return "Return to Chacha to confirm the household’s safety."
  "locked": return "Ask Chacha about a private request for protection."
  "notice": return "Choose whether to read the brief account or skip to protection."
  "witness": return "Ask the sheltered witness about threats against the household."
  "watch": return "Arrange a watch with the village protectors."
  "return": return "Return the account to Chacha; keep it private or offer an intermediary."
 return ""

func destination() -> Dictionary:
 var label := objective()
 if label.is_empty(): return {}
 var id := "uniform_start"
 match stage:
  "protected", "confront": id = "uniform_confront"
  "report": id = "uniform_report"
  "notice": id = "uniform_skip"
  "witness": id = "uniform_witness"
  "watch": id = "uniform_watch"
  "return": id = "uniform_private"
 return {"position":director.prompts[id].global_position,"label":label,"endpoint":""}

func export_state() -> Dictionary:
 if is_instance_valid(guard) and not building: saved_guard = director.witness_mission.person_state(guard)
 return {"guard":saved_guard.duplicate(true),"stage":stage,"skipped_details":skipped_details,"testimony_secured":testimony_secured,"watch_agreed":watch_agreed,"complaint_authorized":false,"intermediary_offered":intermediary_offered}

func restore_state(data: Dictionary) -> void:
 saved_guard = data.get("guard",{}).duplicate(true) if data.get("guard",{}) is Dictionary else {}
 if is_instance_valid(guard) and not building:
  director.witness_mission.restore_person(guard,saved_guard)
  navigation.cancel()
 var candidate := str(data.get("stage","locked"))
 stage = candidate if candidate in STAGES else "locked"
 intermediary_offered = bool(data.get("intermediary_offered",false))
 skipped_details = bool(data.get("skipped_details",false))
 testimony_secured = bool(data.get("testimony_secured",false))
 watch_agreed = bool(data.get("watch_agreed",false))
 complaint_authorized = false

 if is_instance_valid(guard) and stage not in ["confront", "report", "complete"]:
  guard.hide()
  guard.process_mode = Node.PROCESS_MODE_DISABLED
