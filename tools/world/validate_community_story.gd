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
  var clock: Node = load("res://world/suryagarh/systems/game_time_system.gd").new()
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
  if DisplayServer.get_name() != "headless":
   var environment := WorldEnvironment.new()
   var settings := Environment.new()
   settings.background_mode = Environment.BG_COLOR
   settings.background_color = Color(.55,.65,.75)
   settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
   settings.ambient_light_color = Color.WHITE
   settings.ambient_light_energy = .65
   environment.environment = settings
   world.add_child(environment)
   var sun := DirectionalLight3D.new()
   sun.rotation_degrees = Vector3(-45,-25,0)
   world.add_child(sun)
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
  check(story.stage == "available", "actual delivered state preserves pending community contact")
  var consignment=world.get_node_or_null("ConsignmentStory")
  if consignment!=null:
   check(not story.can_request("contact") and story.destination().is_empty(), "community contact waits for next consignment mission")
   consignment.stage="complete"
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
   check(not mission.witness.visible and mission.witness.process_mode == Node.PROCESS_MODE_DISABLED, "first actor stays hidden/non-colliding until state is applied")
   check(float(mission.witness.foot_plant.ankle_height.l)>7, "first-frame ankle cache uses real spawn height")
   for i in 120:
    await process_frame
    if mission.built: break
   check(mission.built, "two complete MPFB actors are created in staggered setup")
   print("COMMUNITY CHECK: rescue actors ready")
   if mission.built:
    check(mission.witness.get_meta("human_source", "") != "", "witness retains sourced human asset")
    check(not story.request("witness_report",player), "cannot report safety before rescue")
    var helpers: Node = mission.helpers
    check(helpers.members.size()==3, "exactly one bounded three-member group")
    helpers.witness_attack(mission.enforcer)
    check(helpers.responders.is_empty(), "untrusted group does not recruit")
    story.remaining = 0
    player.global_position = story.prompts.witness_allies.global_position
    check(story.request("witness_allies",player), "meet local protectors through real interaction")
    player.global_position = mission.enforcer.global_position+Vector3(0,0,2)
    helpers.witness_attack(mission.enforcer)
    helpers.witness_attack(mission.enforcer)
    check(helpers.responders.size()>0 and helpers.responders.size()<=3, "visible attack recruits capped responders without duplicates")
    var member: Node3D = helpers.members[0]
    var actor_state: Dictionary = helpers.export_state()
    helpers.responders.clear()
    member.global_rotation.y = PI
    for other in helpers.members: other.global_rotation.y = PI
    helpers.witness_attack(mission.enforcer)
    check(helpers.responders.is_empty(), "rear-facing protectors do not see the attack")
    helpers.restore_state(actor_state)
    check(helpers.trusted and not helpers.responders.is_empty(), "trust and responders survive restore")
    helpers.responders.clear()
    var wall := StaticBody3D.new()
    var wall_shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(20,3,.2)
    wall_shape.shape = box
    wall.add_child(wall_shape)
    world.add_child(wall)
    wall.global_position = mission.enforcer.global_position+Vector3(0,1.5,-3)
    await physics_frame
    await physics_frame
    helpers.witness_attack(mission.enforcer)
    check(helpers.responders.is_empty(), "occluded protectors cannot recruit through a wall")
    wall.queue_free()
    await physics_frame
    helpers.restore_state(actor_state)
    var guard_health: float = mission.enforcer.get_node("Vitality").health
    for step in 600:
     await physics_frame
     helpers.tick(1.0/60)
     if mission.enforcer.get_node("Vitality").health < guard_health: break
    var travelled := false
    for i in helpers.members.size():
     travelled = travelled or helpers.members[i].global_position.distance_to(helpers.homes[i])>1
    check(travelled, "protectors physically approach the attacker")
    for i in helpers.members.size():
     var protector: Node3D = helpers.members[i]
     print("ALLY CONTACT ",i," distance ",protector.global_position.distance_to(mission.enforcer.global_position)," at ",protector.global_position," nav ",helpers.navigation[i].path)
    check(mission.enforcer.get_node("Vitality").health < guard_health, "protector punch makes real shared hand contact")
    await snapshot(world,mission.enforcer.global_position,"ally_contact")
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
    await snapshot(world,mission.witness.global_position,"shelter")
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
     world.get_node("DevStory").state = "complete"
     player.get_node("UI/HUDRoot/MorningTutorial").restore_step(11)
     world.get_node("RebellionStory").captured_rifles = 12
     check(manager.save_game(world,1), "real SaveManager writes temporary completed mission")
     var disk: Dictionary = manager.read_slot(1)
     check(disk.get("community_story",{}).get("witness_mission",{}).get("stage","") == "complete", "disk save contains completed witness mission")
     check(disk.get("community_story",{}).get("witness_mission",{}).get("help_awarded",false), "disk save retains reward guard")
     var old_id: int = world.get_instance_id()
     check(manager.start_loaded_game(1), "real Continue load route starts from temporary slot")
     var loaded: Node
     for frame in 3600:
      await process_frame
      loaded = current_scene
      if loaded != null and loaded.get_instance_id() != old_id:
       var chapter: Node = loaded.get_node_or_null("CommunityStory")
       if chapter != null and chapter.configured and chapter.witness_mission != null and chapter.witness_mission.built: break
     check(loaded != null and loaded.get_instance_id()!=old_id, "Continue replaced the old world")
     if loaded != null and loaded.get_instance_id()!=old_id:
      world = loaded
      var chapter: Node = world.get_node("CommunityStory")
      var restored: Node = chapter.witness_mission
      check(restored.built and restored.stage == "complete" and restored.help_awarded, "Continue rebuilds completed witness mission")
      check(restored.enforcer.get_meta("knocked_out",false), "Continue preserves nonlethal enforcer outcome")
      check(restored.helpers.trusted and restored.helpers.members.size()==3, "Continue restores trusted protection group")
      check(world.get_node("Player/FameComponent").points == before_fame+4, "Continue does not award help twice")

 if failures.is_empty(): print(("COMMUNITY FOCUSED PASS" if focused else "COMMUNITY WORLD PASS")+": installation/contacts/combat/physical-escort/restore/reward")
 root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)

func freeze_callbacks(node: Node) -> void:
 node.set_process(false)
 node.set_physics_process(false)
 for child in node.get_children(): freeze_callbacks(child)

func snapshot(world: Node, at: Vector3, label: String) -> void:
 var folder := OS.get_environment("TLM_COMMUNITY_IMAGES")
 if folder.is_empty() or not folder.begins_with(OS.get_environment("TMPDIR")) or DisplayServer.get_name() == "headless": return
 var camera := Camera3D.new()
 world.add_child(camera)
 camera.global_position = at+Vector3(4,2,-4)
 camera.look_at(at+Vector3.UP)
 camera.make_current()
 root.disable_3d = false
 for frame in 20: await process_frame
 RenderingServer.force_draw()
 print("COMMUNITY PIXELS ",label," camera ",root.get_camera_3d()," 3D disabled ",root.disable_3d)
 root.get_texture().get_image().save_png(folder.path_join(label+".png"))
 camera.queue_free()
