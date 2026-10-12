extends SceneTree
var failures: Array[String] = []
class Prior:
 extends Node
 var configured := true
 var stage := "return"
 var sites: Node3D
func check(ok: bool, label: String) -> void:
 if not ok: failures.append(label); push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 if OS.get_environment("TLM_COMMUNITY_WORLD") in ["1", "focused"]:
  await run_world()
  return
 var world := Node3D.new()
 root.add_child(world)
 var player := CharacterBody3D.new()
 player.name = "Player"
 player.set_script(load("res://tools/world/community_test_player.gd"))
 world.add_child(player)
 var prior := Prior.new()
 prior.name = "RebellionStory"
 world.add_child(prior)
 prior.sites = Node3D.new()
 prior.sites.set_script(load("res://tools/world/community_test_sites.gd"))
 world.add_child(prior.sites)
 var mangal := Node3D.new()
 prior.sites.add_child(mangal)
 prior.sites.mangal = mangal
 var house := Node3D.new()
 house.name = "ChachaHouse"
 world.add_child(house)
 var chacha := Node3D.new()
 chacha.name = "Chacha"
 house.add_child(chacha)
 chacha.position = Vector3(10,0,0)
 var story: Node = load("res://story/community_story.gd").new()
 world.add_child(story)
 var saved := {"stage":"message"}
 story.restore_state(saved)
 saved.stage = "introduced"
 await process_frame
 await process_frame
 check(story.configured and story.stage == "message", "early restore is copied and applied")
 story.restore_state({})
 story._process(.5)
 check(story.stage == "dormant", "cannot unlock before rifle delivery")
 prior.stage = "complete"
 story._process(.5)
 check(story.stage == "available", "completed delivery unlocks community chapter")
 player.position = Vector3(100,0,0)
 check(not story.request("contact", player), "remote interactions rejected")
 player.position = story.prompts.contact.position
 check(story.request("contact", player), "Mangal gives playable message")
 check(not story.request("contact", player), "duplicate message rejected")
 var state: Dictionary = story.export_state()
 story.restore_state(state)
 check(story.stage == "message" and story.remaining == 0, "restore does not replay dialogue")
 player.position = story.prompts.message.position
 check(story.request("message", player), "Chacha receives message")
 check(story.stage == "introduced" and story.serious_leads.size() == 4, "serious story leads recorded")
 story.restore_state(story.export_state())
 check(story.destination().is_empty() and not story.request("message",player), "completed introduction retires objective and cannot repeat")
 world.queue_free()
 await process_frame
 if failures.is_empty(): print("COMMUNITY STORY PASS: progression/range/duplicate/early-restore/roundtrip/leads")
 quit(0 if failures.is_empty() else 1)

func run_world() -> void:
 var focused := OS.get_environment("TLM_COMMUNITY_WORLD") == "focused"
 if load("res://world/suryagarh/generated/landscape.scn") == null:
  push_error("Landscape unavailable; abort before instantiating a partial world")
  quit(2)
  return
 var world: Node = load("res://tools/world/community_test_world.gd").new() if focused else load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
 root.add_child(world)
 current_scene = world
 if focused:
  var clock := Node.new()
  clock.name = "GameTimeSystem"
  world.add_child(clock)
  var landscape: Node = load("res://world/suryagarh/generated/landscape.scn").instantiate()
  world.add_child(landscape)
  var house: Node = load("res://world/suryagarh/settlements/chacha_house.gd").new()
  world.add_child(house)
  var hero: CharacterBody3D = load("res://tools/world/community_test_player.gd").new()
  hero.name = "Player"
  world.add_child(hero)
  var fame: Node = load("res://player/fame_component.gd").new()
  fame.name = "FameComponent"
  hero.add_child(fame)
  var prior := Prior.new()
  prior.name = "RebellionStory"
  world.add_child(prior)
  prior.sites = load("res://tools/world/community_test_sites.gd").new()
  world.add_child(prior.sites)
  prior.sites.mangal = Node3D.new()
  prior.sites.add_child(prior.sites.mangal)
  prior.sites.mangal.position = house.position+Vector3(0,0,15)
  var movement: Node = load("res://tools/world/community_test_movement.gd").new()
  movement.name = "CombatEncounters"
  world.add_child(movement)
  movement.player = hero
  world.add_child(load("res://story/community_story.gd").new())
 var story: Node
 for i in 3600:
  await process_frame
  story = world.get_node_or_null("CommunityStory")
  if story != null and story.configured: break
 check(story != null and story.configured, "main world configures community story")
 if story != null and story.configured:
  print("COMMUNITY CHECK: production chapter configured")
  for child in world.get_children():
   if child.name not in ["CommunityStory", "Player", "GameTimeSystem"]:
    freeze_callbacks(child)
  var prior: Node = world.get_node("RebellionStory")
  prior.stage = "complete"
  story.restore_state({})
  story._process(.5)
  check(story.stage == "available", "actual delivered state unlocks contact")
  var player: CharacterBody3D = world.get_node("Player")
  player.set_physics_process(false)
  player.set_meta("opening_active", false)
  player.set_meta("story_cinematic", false)
  player.global_position = story.prompts.contact.global_position
  check(story.request("contact", player), "actual Mangal contact accepts")
  story.restore_state(story.export_state())
  player.global_position = story.prompts.message.global_position
  check(story.request("message", player), "actual Chacha contact accepts")
  story.restore_state(story.export_state())
  check(story.serious_leads.size() == 4, "actual chapter retains serious leads")
  var mission: Node = story.witness_mission
  check(mission != null, "production world installs protection mission")
  if mission != null:
   mission.set_physics_process(false)
   mission._physics_process(.5)
   check(mission.stage == "available", "community introduction unlocks witness lead")
   player.global_position = story.prompts.witness_start.global_position
   check(story.request("witness_start", player), "Chacha accepts physical rescue start")
   for i in 120:
    await process_frame
    if mission.built: break
   check(mission.built, "two complete MPFB actors are created in staggered setup")
   print("COMMUNITY CHECK: rescue actors ready")
   if mission.built:
    check(mission.witness.get_meta("human_source", "") != "", "witness retains sourced human asset")
    check(not story.request("witness_report",player), "cannot report safety before rescue")
    var saved: Dictionary = story.export_state()
    story.restore_state(saved)
    check(mission.stage == "rescue", "rescue stage roundtrip")
    mission.enforcer.get_node("Vitality").receive_hit(100,player,"punch")
    mission._physics_process(.1)
    check(mission.stage == "escort" and mission.enforcer.get_meta("knocked_out",false), "real nonlethal combat frees witness")
    story.restore_state(story.export_state())
    check(mission.stage == "escort" and mission.enforcer.get_meta("knocked_out",false), "escort restore preserves enforcer outcome")
    story.remaining = 0
    print("COMMUNITY CHECK: combat/restore passed; starting physical escort")
    print("SUPPORT ",preload("res://world/suryagarh/settlements/resident_walk_route.gd").support(mission.witness,mission.witness.global_position)," shelter ",mission.shelter," support ",preload("res://world/suryagarh/settlements/resident_walk_route.gd").support(mission.witness,mission.shelter))
    var before: Vector3 = mission.witness.global_position
    player.global_position = before+Vector3(0,0,15)
    mission._physics_process(.1)
    check(mission.witness.global_position.is_equal_approx(before), "escort waits when player leaves")
    player.global_position = before+Vector3(1,0,0)
    for i in 1800:
     await physics_frame
     player.global_position = mission.witness.global_position+Vector3(1.5,0,0)
     mission._physics_process(1.0/60)
     if mission.stage == "report": break
    print("COMMUNITY CHECK: escort ended at ",mission.witness.global_position," stage ",mission.stage," path ",mission.witness_nav.path," goal ",mission.witness_nav.goal," pending ",mission.witness_nav.pending)
    check(mission.stage == "report", "witness physically navigates through real courtyard gate")
    check(mission.witness.global_position.distance_to(before)>5, "escort made actual travel")
    story.restore_state(story.export_state())
    story.remaining = 0
    player.global_position = story.prompts.witness_report.global_position
    var fame: Node = player.get_node("FameComponent")
    var before_fame: int = fame.points
    check(story.request("witness_report",player), "shelter arrival can be confirmed")
    check(fame.points == before_fame+4 and mission.help_awarded, "help reputation awarded once")
    story.restore_state(story.export_state())
    check(mission.stage == "complete" and not mission.can_request("witness_report"), "completion persists and cannot repeat")
    check(fame.points == before_fame+4, "restore does not replay reputation")
    var temporary := OS.get_environment("TLM_COMMUNITY_SAVE_DIR")
    if not focused and not temporary.is_empty() and temporary.begins_with(OS.get_environment("TMPDIR")):
     var manager: Node = root.get_node("SaveManager")
     manager.save_root = temporary
     world.get_node("CombatEncounters").restore_crime_state({})
     check(manager.save_game(world,1), "real SaveManager writes temporary completed mission")
     var disk: Dictionary = manager.read_slot(1)
     check(disk.get("community_story",{}).get("witness_mission",{}).get("stage","") == "complete", "disk save contains completed witness mission")
     check(disk.get("community_story",{}).get("witness_mission",{}).get("help_awarded",false), "disk save retains reward guard")

 world.queue_free()
 await process_frame
 if failures.is_empty(): print(("COMMUNITY FOCUSED PASS" if focused else "COMMUNITY WORLD PASS")+": installation/contacts/combat/physical-escort/restore/reward")
 quit(0 if failures.is_empty() else 1)

func freeze_callbacks(node: Node) -> void:
 node.set_process(false)
 node.set_physics_process(false)
 for child in node.get_children(): freeze_callbacks(child)
