extends SceneTree
## Real new-game opening -> station gate -> film -> recovery -> farm/map checkpoint.
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 if not ok:failures.append(label);push_error(label)
func silence_review_input(node: Node) -> void:
 node.set_process_input(false);node.set_process_unhandled_input(false);node.set_process_unhandled_key_input(false)
 for child in node.get_children():silence_review_input(child)
func run() -> void:
 var temporary:=OS.get_environment("TLM_STORY_TEST_DIR")
 if temporary.is_empty() or not temporary.begins_with(OS.get_environment("TMPDIR")):quit(2);return
 var manager: Node=root.get_node("SaveManager");manager.save_root=temporary;manager.pending_slot=0
 var world: Node3D=load("res://world/suryagarh/suryagarh_world.tscn").instantiate();root.add_child(world);current_scene=world
 if DisplayServer.get_name()!="headless":silence_review_input(world)
 if OS.get_environment("TLM_INQUIRY_ISOLATE_RIVER")=="1":
  for node in world.find_children("*","Node",true,false):
   if node.get_script()!=null and node.get_script().resource_path.ends_with("village_river_routine.gd"):node.set_physics_process(false)
  print("STORY WORLD: river routine isolated in fixture")
 for frame in 30:await physics_frame
 var story: Node=world.get_node("DevStory");var inquiry: Node=world.get_node("DevInquiry");var player: CharacterBody3D=world.get_node("Player")
 check(world.has_node("WorldDistricts/Village") and world.has_node("WorldDistricts/City"),"main world installs separate village and city districts")
 var opening: Node=world.get_node("OpeningSequence")
 check(story.configured and inquiry.stage=="dormant","story waits for main opening")
 var event:=InputEventKey.new();event.keycode=KEY_SPACE;event.pressed=true;opening._input(event)
 await create_timer(.9).timeout;check(inquiry.stage=="dormant","morning seat precedes story")
 opening._input(event) # The first press reveals the skip hint; the second skips.
 # The opening now owns the complete dawn rise and walk out of the house.
 opening.set_process(false)
 for step in 200:
  opening._process(.25);await process_frame
  if opening.state=="done":break
 check(opening.state=="done","morning releases control")
 var tutorial: Node=player.get_node_or_null("UI/HUDRoot/MorningTutorial")
 check(tutorial!=null,"morning tutorial available")
 while tutorial.step<10:tutorial.advance()
 story.set_process(false)
 var horse: Node=world.get_node("VillageHorse")
 player.global_position=horse.global_position+Vector3(1,.9,0);player.velocity=Vector3.ZERO
 check(horse.get_meta("owner","")=="Arjun","home horse belongs to Arjun")
 check(horse.board(player),"home horse boards through production mount")
 for frame in 100:await physics_frame
 tutorial._process(.1);story._process(0)
 check(story.active and story.cue=="horse_departure","mount starts cinematic journey to station")
 check(world.has_node("StableHorse01") and world.has_node("StableHorse02"),"village stable retains two additional horses")
 var bridge: Node=world.get_node("TimberBridge")
 check(not bridge.has_node("RevenueCrossingGate") and bridge.has_node("BridgeInspectionPost/BridgeInspectionOfficer"),"open bridge has seated inspection officer and no barrier")
 check(story.community.farm.global_position.distance_to(world.get_node("ChachaHouse").global_position)<30,"family farm adjoins Chacha's house")
 check(world.get_node("ChachaHouse").has_node("FamilyCourtyardGate"),"family boundary has working gate")
 var activities: Node=world.get_node("VillageDailyActivities")
 for resident in activities.residents:
  if resident.household_job=="groom":check(resident.global_position.distance_to(horse.global_position)>70,"horse keeper stays at stable, away from family home")
 print("STORY WORLD: horse cinematic active ",story.active)
 for actor in [player.get_node("VisualRoot/CharacterVisual")]+inquiry.officials+inquiry.guards+[inquiry.police_prompt.get_meta("attendant")]:
  var rig: Skeleton3D=actor.skeleton if actor==player.get_node("VisualRoot/CharacterVisual") else actor._skeleton
  var head: Vector3=rig.to_global(rig.get_bone_global_rest(rig.find_bone("head")).origin)
  var ankle: Vector3=rig.to_global(rig.get_bone_global_rest(rig.find_bone("foot_l")).origin)
  check(absf(head.y-ankle.y-story.rest_stature(player.get_node("VisualRoot/CharacterVisual").skeleton))<.015,"station personnel match Arjun stature: "+str(actor.name))

 story.update_acting(.1,.5)
 check(horse.rigged_anim.current_animation.ends_with("Walk"),"cinematic horse advances its walking clip")
 if OS.get_environment("TLM_STORY_ARRIVAL_NATIVE")=="1":
  DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
  DisplayServer.window_set_size(Vector2i(1280,720))
  story.set_process(true)
  var photos: Dictionary={}
  while story.active and story.cue!="reception":
   await process_frame
   if story.age>1.3 and not photos.has(story.cue):
    photos[story.cue]=true
    if DisplayServer.get_name()!="headless":
     await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(temporary.path_join(story.cue+".png"))
  story.finish();story.set_process(false)
 var reviewed: Array[String]=[]
 var natural:=OS.get_environment("TLM_STORY_NATURAL")=="1"
 story.set_process(natural)
 var standing_position:=Vector3.INF
 if natural and DisplayServer.get_name()!="headless":
  DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
  DisplayServer.window_set_size(Vector2i(1280,720))
 while story.active:
  if natural:
   await physics_frame
   if story.cue=="entry" and not standing_position.is_finite():standing_position=horse.global_position
   if story.cue in ["beating","discard","throw","rescue","support_walk","bed_arrival"]:
    check(horse.rider==null and (not player.has_meta("mounted_vehicle") or player.get_meta("mounted_vehicle")==null),"natural later acting has no mounted owner")
    check(Vector2(horse.global_position.x,horse.global_position.z).distance_to(Vector2(standing_position.x,standing_position.z))<.15,"horse stays parked through natural assault and Chacha")
   if story.cue=="discard" and story.age>.1:check(story.carry_contact_error<.06,"main-world live carry contact")
   if story.cue in ["rescue","support_walk"] and story.age>.1:check(story.support_contact_error<.06,"main-world live helper contact")
   if story.age>1 and story.cue not in reviewed:
    reviewed.append(story.cue)
    if DisplayServer.get_name()!="headless":
     await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(temporary+"/"+story.cue+".png")
  else:
   if story.cue in ["entry","chamber"]:check(not story.hero_path.is_empty(),"cinematic approach has a traversable station path")
   if story.cue=="entry":
    check((not player.has_meta("mounted_vehicle") or player.get_meta("mounted_vehicle")==null) and horse.rider==null,"station acting releases horse ownership")
    check(horse.global_position.distance_to(inquiry.station.to_global(Vector3(0,0,26)))>5,"horse parks clear of rescue")
   if story.cue=="horse_dismount":
    for frame in 100:await physics_frame
    check(horse.rider==null,"horse completes physical dismount before entry")
   story._process(float(story.beats[story.beat_index].seconds)+.1);await process_frame
 check(story.state=="farm" and player.is_physics_processing(),"main film ends at recovery checkpoint")
 player.inventory.add_item("talwar",1)
 var gear: Node=player.get_node("VisualRoot/CharacterVisual").equipment
 gear.select_weapon(0);gear.stowed=false;gear._refresh()
 check(player.get_node("TalwarSlash").strike(),"actual horse story arrival allows sword animation")
 player.get_node("CombatInput").interrupt()
 check(inquiry.destination.global_position==story.community.farm.global_position,"farm map destination integrated")
 await check_arrival_variants(story,inquiry,player,world)
 var community: Node=story.community
 for attempt in 100:
  if community.pending.is_empty():break
  community.wait=0;community._process(.2);await physics_frame
 var road_residents: Array[Node3D]=[]
 for resident in community.residents:
  if resident.get_child_count()>0:
   for child in resident.get_children():
    if child.get_script()!=null and child.get_script().resource_path.ends_with("city_street_journey.gd"):road_residents.append(resident)
 check(road_residents.size()==20,"community residents distributed over five road routes")
 for i in road_residents.size():
  for j in range(i+1,road_residents.size()):check(road_residents[i].global_position.distance_to(road_residents[j].global_position)>2.0,"distributed road residents retain personal spacing")
 print("STORY COMMUNITY DISTRIBUTION: ",road_residents.size()," road walkers")
 var expansion: Node=world.get_node("PopulationExpansion")
 var station_sources: Dictionary={}
 var gate: Vector3=inquiry.station.to_global(Vector3(0,0,20))
 for key: String in expansion.originals:
  var source: Node3D=world.get_node_or_null(NodePath(key))
  if source!=null and source.global_position.distance_to(gate)<45:station_sources[key]=true
 var near_gate:=0
 for record: Dictionary in expansion.pending:
  if station_sources.has(record.source_id) and record.phase.point.distance_to(Vector2(gate.x,gate.z))<25:near_gate+=1
 for person: Node3D in expansion.pedestrians:
  if station_sources.has(person.get_meta("counterpart_of","")) and person.global_position.distance_to(gate)<25:near_gate+=1
 if station_sources.size()>=4:check(near_gate<=ceili(station_sources.size()*.5),"station colleagues spread beyond the entrance")
 print("STORY REGIONAL DISTRIBUTION: ",near_gate," nearby colleagues from ",station_sources.size()," station sources")
 check(manager.save_game(world,1),"main recovery checkpoint saves")
 var saved_road_position: Vector3=road_residents[0].global_position if not road_residents.is_empty() else Vector3.ZERO
 if not road_residents.is_empty():road_residents[0].global_position+=Vector3(3,0,0)
 story.state="awaiting_inquiry";manager.pending_slot=1;manager.apply_pending(world)
 if not road_residents.is_empty():check(road_residents[0].global_position.distance_to(saved_road_position)<.01,"community walking route restores through main save")
 check(story.state=="farm" and inquiry.stage=="released","main load restores film completion and farm objective")
 check(story.community.members.size()==3,"farm partners present in main world")
 check(story.community.college.has_meta("parking_label") and story.community.courtyard.has_meta("parking_label"),"main map gathering places discoverable")
 print("DEV STORY WORLD: "+("PASS" if failures.is_empty() else "FAIL "+str(failures)))
 world.queue_free();await process_frame;call_deferred("finish",0 if failures.is_empty() else 1)
func finish(code: int) -> void:preload("res://tools/test_audio_cleanup.gd").finish(self,code)

func check_arrival_variants(story: Node,inquiry: Node,player: CharacterBody3D,world: Node3D) -> void:
 var cart=preload("res://vehicles/horse_cart_candidate.gd").new()
 cart.set_meta("owner","Arjun")
 world.add_child(cart)
 cart.global_position=inquiry.station.to_global(Vector3(7,0,40))
 cart.global_position.y=world.layout.height(cart.global_position.x,cart.global_position.z)+.1
 player.global_position=cart.seat_sockets["DriverSeat"].global_position
 check(cart.board_at(player,"DriverSeat","driver"),"station arrival boards actual cart")
 for frame in 100:await physics_frame
 story.state="awaiting_inquiry";inquiry.stage="police"
 var started: bool=story.start_inquiry()
 check(started,"mounted cart starts station arrival")
 if not started:cart.queue_free();return
 if OS.get_environment("TLM_STORY_ARRIVAL_NATIVE")=="1" and DisplayServer.get_name()!="headless":
  story.set_process(true)
  var photographed: Dictionary={}
  while story.active and story.cue!="entry":
   await process_frame
   if story.age>1.3 and not photographed.has(story.cue):
    photographed[story.cue]=true
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(OS.get_environment("TLM_STORY_TEST_DIR").path_join("cart_"+story.cue+".png"))
  check(cart.rider==null,"natural cart exit completes before entry")
 story.set_process(false)
 while story.active and story.cue!="entry":
  if story.cue=="horse_arrival":
   story.update_acting(.1,.5)
   check(cart.boarding.speed>.5,"cinematic cart drives draft and wheel motion")
  if story.cue=="horse_dismount":
   for frame in 100:await physics_frame
   check(cart.rider==null,"cart completes physical exit before entry")
  story._process(float(story.beats[story.beat_index].seconds)+.1);await process_frame
 check(cart.rider==null and player.get_meta("cart_role","")=="","cart seat releases before station acting")
 check(not story.hero_path.is_empty(),"cart parking connects to station walk")
 var parked: Vector3=cart.global_position
 story.update_acting(.1,.5);await physics_frame
 check(cart.global_position.distance_to(parked)<.01,"parked cart stays still during entry")
 story.finish()
 story.state="awaiting_inquiry";inquiry.stage="police"
 player.global_position=inquiry.station.to_global(Vector3(0,.9,20))
 var origin: Vector3=player.global_position
 check(story.start_inquiry(),"on-foot station arrival starts")
 check(story.cue=="entry" and not story.hero_path.is_empty(),"on-foot arrival uses walking path")
 check(player.global_position.distance_to(origin)<.01,"on-foot arrival preserves starting position")
 story.update_acting(.1,.5)
 check(player.velocity.length()>.1,"on-foot arrival advances walking locomotion")
 story.finish();story.set_process(true)
 print("STORY ARRIVAL VARIANTS: cart and on-foot checked")
