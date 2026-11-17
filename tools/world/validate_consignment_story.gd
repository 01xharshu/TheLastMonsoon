extends SceneTree
var failures: Array[String]=[]
class Fixture:
 extends Node3D
 var layout=preload("res://world/suryagarh/landscape_layout.gd").new()
class FirstMission:
 extends Node
 var configured=true
 var stage="dormant"
 var disguise=false
 var sites: Dictionary={}
 var player: CharacterBody3D
 func set_stage(next: String) -> void:stage=next
 func release_mount(mount: Node) -> void:
  var helper=load("res://story/rebellion_story.gd").new();helper.player=player;helper.release_mount(mount);helper.free()
 func export_state() -> Dictionary:return {"stage":stage}
func fixture() -> Node3D:
 var world:=Fixture.new();root.add_child(world);current_scene=world
 var clock=load("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock)
 var landscape:Node3D=load("res://world/suryagarh/generated/landscape.scn").instantiate();world.add_child(landscape)
 var expanded:Node3D=load("res://world/suryagarh/generated/wilderness_expansion/wilderness_expansion.scn").instantiate();world.add_child(expanded)
 landscape.get_node("DistantTerrain_NoCollision").hide()
 await preload("res://world/suryagarh/tree_trunk_collision.gd").repair_landscape(landscape)
 await preload("res://world/suryagarh/tree_trunk_collision.gd").repair_landscape(expanded)
 if DisplayServer.get_name()!="headless":
  await preload("res://world/suryagarh/tree_variety.gd").configure_landscape(landscape)
  await preload("res://world/suryagarh/tree_variety.gd").configure_landscape(expanded)
 if OS.get_environment("TLM_CHASE_MOTION")=="1" or OS.get_environment("TLM_CHASE_CONTINUOUS")=="1":
  var env:=WorldEnvironment.new();var lighting:=Environment.new();lighting.background_mode=Environment.BG_COLOR;lighting.background_color=Color(.55,.67,.74);lighting.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;lighting.ambient_light_color=Color.WHITE;lighting.ambient_light_energy=.65;env.environment=lighting;world.add_child(env)
  var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-48,-30,0);sun.light_energy=1;sun.shadow_enabled=true;world.add_child(sun)
 var player: CharacterBody3D=load("res://player/player.tscn").instantiate();player.name="Player";world.add_child(player);player.inventory.items["rupees"]=0
 var prior:=FirstMission.new();prior.name="RebellionStory";prior.player=player;world.add_child(prior)
 var prompt:=Node3D.new();prompt.position=Vector3(461,world.layout.height(461,-300)+1,-300);world.add_child(prompt);prior.sites={"prompts":{"briefing":prompt}}
 world.add_child(load("res://story/city_weapon_seller.gd").new());world.add_child(load("res://story/consignment_story.gd").new())
 return world
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
 if not ok:failures.append(label);push_error(label)
func run() -> void:
 var temporary:=OS.get_environment("TLM_STORY_TEST_DIR")
 if temporary.is_empty() or not temporary.begins_with(OS.get_environment("TMPDIR")):quit(2);return
 root.get_node("SaveManager").save_root=temporary
 var world: Node3D
 var focused:=OS.get_environment("TLM_CONSIGNMENT_FOCUSED")=="1"
 if focused:world=await fixture()
 else:world=load("res://world/suryagarh/suryagarh_world.tscn").instantiate();root.add_child(world);current_scene=world
 for i in 2400:
  await physics_frame
  if world.has_node("ConsignmentStory") and world.get_node("ConsignmentStory").configured:break
 var story: Node=world.get_node("ConsignmentStory");var first: Node=world.get_node("RebellionStory");var player: CharacterBody3D=world.get_node("Player");var shop: Node=world.get_node("CityWeaponSeller")
 check(story.configured and shop.configured,"new mission and seller configure")
 if not story.configured or not shop.configured:root.get_node("SaveManager").quit_game(1);return
 story.set_process(false);story.set_physics_process(false);first.set_process(false)
 var clock: Node=world.get_node("GameTimeSystem")
 for candidate in story.STAGES:
  story.stage=candidate;clock.total_game_minutes=1320;story.sync_guidance()
  var expected: bool=candidate in ["outbound","loading","chase","celebration"]
  check(clock._daylight_missions.has(&"consignment_escort")==expected,"consignment daylight ownership: "+candidate)
  var before_clock: float=clock.total_game_minutes
  clock._process(600);clock.advance_hours(24)
  if expected:check(clock.total_game_minutes==before_clock and clock.current_hour>=8 and clock.current_hour<17,"accepted consignment holds daylight: "+candidate)
  elif focused:check(clock.total_game_minutes>before_clock,"unaccepted/finished consignment allows time: "+candidate)
 story.stage="dormant";story.sync_guidance()
 if OS.get_environment("TLM_CONSIGNMENT_VOICE_ONLY")=="1":
  first.stage="complete";story.stage="assigned"
  player.global_position=first.sites.prompts.briefing.global_position
  check(story.request("consignment",player),"real consignment briefing starts")
  check(story.dialogue_voice.playing,"Mangal briefing voice starts")
  story.stage="loading"
  check(story.start_chase(),"real chase starts from occupied cart")
  check(not story.dialogue_voice.playing,"chase transition stops briefing")
  story.defeated.assign([0,1,2,3,4,5,6])
  check(story.begin_celebration(),"camp celebration starts")
  story.finish_celebration(1.0)
  check(story.dialogue_voice.playing and story.dialogue_queue.size()==1,"fighter and Mangal voices queue")
  if story.dialogue_queue.size()==1:
   var fighter_voice: AudioStream=story.dialogue_voice.stream
   story.dialogue_voice.finished.emit()
   check(story.dialogue_voice.playing and story.dialogue_voice.stream!=fighter_voice and story.dialogue_queue.is_empty(),"finished signal plays Mangal after the fighter")
  var skip:=InputEventAction.new();skip.action="jump";skip.pressed=true;story._input(skip)
  check(story.stage=="complete" and story.paid and player.inventory.get_item_count("rupees")==200,"skip pays reward exactly once")
  check(not story.dialogue_voice.playing and story.dialogue_queue.is_empty(),"skip clears both voices")
  print("CONSIGNMENT VOICE ","PASS" if failures.is_empty() else "FAIL",failures)
  await preload("res://tools/test_audio_cleanup.gd").finish(self,0 if failures.is_empty() else 1)
  return
 var shared_trees:Dictionary={};var shared_grass:Dictionary={}
 for batch in world.get_node("WildernessExpansion").find_children("*","MultiMeshInstance3D",true,false):
  if str(batch.name).begins_with("BroadleafTrees") and batch.multimesh.instance_count>0:shared_trees[batch.multimesh.mesh.get_instance_id()]=batch.multimesh.mesh.resource_path
  if str(batch.name).begins_with("GrassCore"):shared_grass[batch.multimesh.mesh.get_instance_id()]=batch.multimesh.mesh.resource_path
 print("CONSIGNMENT EXPANSION shared_tree_meshes=",shared_trees.size()," shared_grass_meshes=",shared_grass.size())
 check(shared_trees.size()==(7 if world.get_node("Landscape").has_meta("tree_variety_counts") else 1) and shared_grass.size()==1,"expanded forest reuses cached tree palette/grass meshes across terrain tiles")
 for i in 3:await physics_frame
 story._process(.1);check(story.stage=="dormant" and not story.can_request("consignment"),"second mission locked before first loot delivery")
 first.set_stage("complete");story._process(.1)
 await capture(story,"wanted_notice",story.posters[0].global_position+Vector3(0,0,3.5),story.posters[0].global_position)
 check(story.stage=="assigned" and story.posters.all(func(p):return p.visible),"first loot delivery circulates wanted posters and assigns next mission")
 check(not story.begin_celebration() and player.inventory.get_item_count("rupees")==0,"cannot receive reward before chase")
 # Existing complete MakeHuman character and transactional shop.
 player.global_position=shop.global_position+Vector3(2,.9,1);shop._process(.1)
 check(shop.discovered and shop.get_meta("parking_label","")=="Illegal weapon seller","proximity discovers city weapon map marker")
 check(player.get_node("UI/WorldMap").site_kind("Illegal weapon seller")=="weapon","map uses weapon symbol")
 check(shop.request("shop",player),"weapon seller opens purchase menu")
 check(not shop.buy(0) and not player.inventory.has_item("enfield"),"insufficient funds cannot grant weapon")
 player.inventory.add_item("rupees",200)
 check(shop.buy(0) and player.inventory.has_item("enfield") and player.inventory.get_item_count("rupees")==100,"weapon purchase debits exact money")
 check(not shop.buy(0) and player.inventory.get_item_count("rupees")==100,"owned weapon cannot be charged twice")
 check(shop.buy(4) and player.inventory.get_item_count("paper_cartridges")==12 and player.inventory.get_item_count("rupees")==88,"ammunition purchase uses actual inventory")
 await capture(story,"weapon_shop",shop.global_position+Vector3(5,3,7),shop.global_position+Vector3.UP)
 shop.close_shop();check(not player.get_meta("weapon_shop_open",false) and shop.lease<0,"shop close releases action permissions")
 var shop_state: Dictionary=shop.export_state();shop.discovered=false;shop.restore_state(shop_state);check(shop.discovered,"seller discovery restores")
 if not focused:
  var witness=load("res://characters/npcs/households/household_npc_actor.gd").new();witness.name="LateWantedWitness";witness.movement_enabled=false;witness.set_meta("combat_faction","indian");witness.add_child(load("res://characters/human_scene.gd").instantiate("res://characters/npcs/households/merchant.glb"));world.add_child(witness);witness.global_position=player.global_position-Vector3(0,.9,5)
  for i in 4:await physics_frame
  check(story.observer_ids.has(witness.get_instance_id()),"late-spawned civilian joins cached wanted recognition")
  var crime: Node=world.get_node("CombatEncounters");var evidence: int=crime.evidence.size()
  var prior_observers: Array[Node3D]=story.observers.duplicate();story.observers.clear();story.observers.append(witness)
  first.disguise=true;story.recognise();check(crime.evidence.size()==evidence,"disguise delays identification beyond close inspection")
  first.disguise=false;story.recognise();check(crime.evidence.size()>evidence and crime.wanted,"visible poster witness reports Arjun through existing crime")
  var reports: int=crime.evidence.size();story.recognise();check(crime.evidence.size()==reports,"recognition cooldown prevents per-frame crime spam")
  story.observers.assign(prior_observers);crime.complete_custody(player);witness.queue_free()
 # A supported route with conservative grades and no added wilderness populace.
 var length:=0.0;var steepest:=0.0;var bad_support:=0;var blocked:=0;var enters_expansion=false
 for i in range(1,story.route.size()):
  if absf(story.route[i].x)>864 or absf(story.route[i].z)>864:enters_expansion=true
  var offset: Vector3=story.route[i]-story.route[i-1];var horizontal:=Vector2(offset.x,offset.z).length();length+=offset.length();steepest=maxf(steepest,absf(offset.y)/horizontal)
 var shared_end:int=story.Route.shared_end_index(story.route)
 check(shared_end>0,"mission uses the canonical port/village road")
 var private_grade:=0.0
 for i in range(story.Route.surface_start_index(story.route)+1,story.route.size()):
  var delta:Vector3=story.route[i]-story.route[i-1]
  private_grade=maxf(private_grade,absf(delta.y)/maxf(.001,Vector2(delta.x,delta.z).length()))
 print("CONSIGNMENT PRIVATE GRADE ",private_grade)
 check(length>7000 and world.layout.SIZE>1728 and enters_expansion and steepest<=.3 and private_grade<=.1801,"shared hill road and wilderness grades support the convoy")
 var prior:Dictionary=story.export_state()
 var legacy:Dictionary=prior.duplicate(true)
 legacy.erase("route_version");legacy.erase("route_anchor");legacy.route_index=story.Route.legacy_samples().size()-1
 story.restore_state(legacy)
 check(story.route_index==story.route.size()-1 and story.stage==prior.stage and story.paid==prior.paid,"old camp checkpoint maps to the real camp without altering mission/payment state")
 story.restore_state(prior)
 check(story.export_state().get("route_version",0)==story.Route.Data.VERSION,"new mission checkpoint retains route version and anchor")
 for i in range(0,story.route.size()-1):
  var point: Vector3=story.route[i].lerp(story.route[i+1],.5);var query=PhysicsRayQueryParameters3D.create(point+Vector3.UP,point-Vector3.UP,1)
  var support=world.get_world_3d().direct_space_state.intersect_ray(query)
  if support.is_empty():bad_support+=1
  story.cart.global_position=point;story.cart.basis=story.route_frame(point,i,1)
  if not story.cart.boarding._clearance_at(point):
   blocked+=1
   if blocked<=8:
    print("CONSIGNMENT ROUTE BLOCKED index=",i," point=",point)
    for collision in story.cart.boarding.clearance_shapes:
     var overlap=PhysicsShapeQueryParameters3D.new();overlap.shape=collision.shape;overlap.transform=Transform3D(story.cart.global_basis,point+story.cart.global_basis*collision.position);overlap.exclude=story.cart.boarding._vehicle_exclusions();overlap.collision_mask=1
     for hit in world.get_world_3d().direct_space_state.intersect_shape(overlap,2):print("CONSIGNMENT ROUTE COLLIDER shape=",collision.get_index()," ",hit.collider.get_path())
 print("CONSIGNMENT WORLD size=",world.layout.SIZE," outer_tiles=",world.get_node("WildernessExpansion/TerrainTiles").get_child_count())
 print("CONSIGNMENT ROUTE length=",length," grade=",steepest," no_support=",bad_support," blocked=",blocked)
 check(bad_support==0 and blocked==0,"physical route supports and clears the whole convoy cart")
 check(story.route[story.holding_start].distance_to(story.route[story.holding_end])<.001,"holding circuit closes without teleport or height jump")
 player.global_position=first.sites.prompts.briefing.global_position
 print("CONSIGNMENT BEFORE BOARD health=",player.health)
 check(story.cart.has_node("RebelCoveredWagon/StitchedCanvasRoof"),"mission cart has an actual physical roof")
 check(story.request("consignment",player),"Mangal starts companion-driven outbound convoy")
 check(story.dialogue_voice.playing and story.dialogue_voice.stream!=null,"Mangal consignment briefing plays")
 for i in 200:await physics_frame
 print("CONSIGNMENT BOARDED health=",player.health," cart=",story.cart.global_position)
 check(story.cart.rider==player and player.get_meta("cart_role","")=="passenger" and story.driver.driving,"Arjun remains passenger with a real companion driver")
 check(not player.get_node("RifleCombat").available(),"concealed outbound passenger cannot fire")
 var cover:Node=story.cart.get_node("RebelCoveredWagon")
 check(cover.openness<.01 and cover.curtain_body.collision_layer==1,"outbound concealment has opaque physical rear curtain")
 check(not story.cart.boarding.dismount(),"active running convoy cannot switch player to driving/foot")
 if OS.get_environment("TLM_CHASE_MOTION")=="1":await motion_review(story,player,"concealed")
 await capture(story,"outbound_conceal",story.cart.global_position+story.cart.global_basis*Vector3(5,2,7),story.cart.global_position+Vector3.UP*1.4)
 if OS.get_environment("TLM_CONSIGNMENT_TRAVEL")=="1":
  var stalled:=0;var travelled:=0.0
  for i in 12000:
   if story.stage!="outbound":break
   var before: Vector3=story.cart.global_position;story._physics_process(.1)
   var step: float=story.cart.global_position.distance_to(before);travelled+=step;stalled=stalled+1 if step<.001 else 0
   if step<.001:
    # A physical traffic wait needs the same elapsed time for the pedestrians.
    for frame in 6:await physics_frame
   elif i%5==0:await physics_frame
   if stalled>100:
    print("CONSIGNMENT TRAVEL STALL index=",story.route_index," at=",story.cart.global_position)
    for collision in story.cart.boarding.clearance_shapes:
     var direction: Vector3=(story.route[maxi(0,story.route_index-1)]-story.cart.global_position).normalized()
     var basis:=Basis.from_euler(Vector3(atan2(direction.y,Vector2(direction.x,direction.z).length()),story.heading(direction),0))
     var candidate: Vector3=story.cart.global_position+direction*.1
     var overlap=PhysicsShapeQueryParameters3D.new();overlap.shape=collision.shape;overlap.transform=Transform3D(basis,candidate+basis*collision.position);overlap.exclude=story.cart.boarding._vehicle_exclusions();overlap.collision_mask=1
     for hit in world.get_world_3d().direct_space_state.intersect_shape(overlap,4):print("CONSIGNMENT TRAVEL COLLIDER ",hit.collider.get_path())
    break
  print("CONSIGNMENT FULL OUTBOUND travelled=",travelled," stage=",story.stage," health=",player.health)
  check(story.stage=="loading" and travelled>3500 and player.health>0,"whole long route physically drives to port without fatal gaps or stalls")
  if story.stage!="loading":root.get_node("SaveManager").quit_game(1);return
 else:
  story.cart.global_position=story.route[0];story.route_index=0;story.cart.rotation.y=story.heading(story.route[0]-story.route[1])
 var safety=player.get_node_or_null("PlayerSafety")
 if safety!=null and OS.get_environment("TLM_CONSIGNMENT_TRAVEL")!="1":safety.tracked_vehicle=null;safety.peak=-INF
 story._physics_process(.1)
 print("CONSIGNMENT YARD health=",player.health," stage=",story.stage," safety_peak=",safety.peak if safety!=null else 0)
 check(story.stage=="loading","yard arrival requires interactive consignment load")
 check(story.start_chase() and story.wave==1,"consignment departure starts first pair of pursuers")
 check(not story.dialogue_voice.playing and story.dialogue_queue.is_empty(),"chase transition stops the briefing")
 if OS.get_environment("TLM_CHASE_MOTION")=="1":
  for mount in story.pursuers:mount.set_physics_process(false)
  await transition_review(story,player)
 check(story.pursuers.filter(func(p):return p.visible).size()==3,"exactly three mounted pursuers active initially")
 story._physics_process(1.0/60.0) # The first real chase tick sets departure heading.
 for frame in 65:await physics_frame # Physical rear curtain/seat must open before firing.
 check(preload("res://story/rear_passenger_combat.gd").allowed(player) and player.get_node("RifleCombat").available(),"real firearm available only in armed rear mission seat")
 check(player.get_meta("suppress_destination_marker",false),"chase hides destination markers")
 check(story.riders[0].firearm.gun.name=="MountedAdamsPistol","mounted police use pistol asset")
 var feedback:Node=player.get_node("ConsignmentDamageFeedback");feedback.set_process(false)
 var saved_health:float=player.health;feedback.last_health=player.health;feedback.last_shots=player.get_node("RifleCombat").shots_fired
 player.health=15;feedback._process(.01)
 check(feedback.overlay.visible and feedback.impact>.9 and float(feedback.shader.get_shader_parameter("critical"))>.9,"damage displays impact and critical vignette")
 feedback._process(2.0);check(is_equal_approx(player.health,15.0),"damage recovery waits for quiet period")
 feedback._process(3.1);check(player.health>15.0,"health recovers after quiet period")
 player.health=saved_health;feedback.last_health=saved_health;feedback.impact=0;feedback.quiet=0;feedback.set_process(true)
 var pistol:Node=story.riders[0].firearm
 var prior_hostile:bool=pistol.hostile;pistol.hostile=false;pistol.cartridges=8;pistol.chambered=0;pistol.reloading=true;pistol.cooldown=.01;pistol._process(.02)
 check(not pistol.reloading and pistol.chambered==5,"officer pistol reloads five shots from reserve")
 pistol.hostile=prior_hostile
 var health: float=player.health
 var gun: Node=player.get_node("RifleCombat");gun.rounds=0;gun.start_reload()
 check(gun.reload_remaining>0 and gun.pending_rounds==1,"moving passenger uses real ammunition reload")
 for i in 120:await physics_frame
 check(gun.rounds==1,"passenger reload completes")
 story.cart.boarding.seat_name="DriverSeat";check(not gun.available(),"driver seat cannot inherit rear firearm permission");story.cart.boarding.seat_name="ConsignmentRearSeat"
 if OS.get_environment("TLM_CHASE_MOTION")=="1":await motion_review(story,player,"armed")
 var shot_count:=0
 for rider in story.riders:shot_count+=rider.firearm.shots
 print("CONSIGNMENT POLICE live_shots=",shot_count," player_health=",player.health)
 if shot_count==0:
  # Rendering-heavy setup must not let horses overtake a fixture-parked cart.
  # Restore the real checkpoint and run both sides at normal physics cadence.
  story.restore_state(story.export_state());story.set_physics_process(true)
  for frame in 600:
   await physics_frame
   shot_count=0
   for rider in story.riders:shot_count+=rider.firearm.shots
   if shot_count>0 and player.health<health:break
  story.set_physics_process(false)
 if shot_count==0:
  for i in 2:
   var shooter: Node=story.riders[i].firearm
   var muzzle: Vector3=shooter.gun.to_global(shooter.MUZZLE)
   var excluded: Array[RID]=[story.riders[i].body_collider.get_rid()]
   for rid in story.riders[i].get_meta("firearm_exclusions",[]):excluded.append(rid)
   var hit=preload("res://combat/ballistic_trace.gd").sight(world.get_world_3d().direct_space_state,self,muzzle,player.global_position,excluded)
   print("CONSIGNMENT SHOOTER ",i," engage=",shooter.can_engage()," muzzle=",muzzle," target=",player.global_position," hit=",hit.collider.get_path() if not hit.is_empty() else "none")
 if OS.get_environment("TLM_CHASE_CONTINUOUS")=="1":await continuous_review(story,player)
 await capture(story,"rear_passenger",story.cart.global_position+story.cart.global_basis*Vector3(6,3,10),story.cart.global_position+Vector3.UP*1.4)
 check(story.riders[0].firearm.hostile,"mounted pursuers have active real firearms")
 check(shot_count>0 and player.health<health,"mounted police genuinely shoot and hit the rear passenger")
 var saved: Dictionary=story.export_state();story.restore_state(saved)
 for i in 200:await physics_frame
 check(story.stage=="chase" and story.cart.rider==player and story.wave==1,"armed passenger chase checkpoint restores")
 if not focused:
  var saves: Node=root.get_node("SaveManager")
  check(saves.save_game(world,1),"SaveManager saves live consignment chase")
  var data: Dictionary=saves.read_slot(1)
  check(data.get("consignment_story",{}).get("stage","")=="chase" and data.get("weapon_seller",{}).get("discovered",false),"save file contains mission and merchant discovery")
  story.stage="assigned";shop.discovered=false;saves.pending_slot=1;saves.apply_pending(world)
  for i in 200:await physics_frame
  check(story.stage=="chase" and story.cart.rider==player and shop.discovered and player.inventory.get_item_count("rupees")==88,"SaveManager restores actual rear passenger, purchases and mission")
 check(not story.begin_celebration(),"live pursuers prevent escape completion")
 var chase_rifle:Node=player.get_node("RifleCombat")
 check(is_equal_approx(chase_rifle.reload_duration(),1.0),"rear mounted weapon reload takes one second")
 for rider in story.riders:rider.firearm.hostile=false
 var before_move: Vector3=story.cart.global_position
 for i in 20:story._physics_process(.1);await physics_frame
 print("CONSIGNMENT CONVOY travel=",story.cart.global_position.distance_to(before_move)," index=",story.route_index," speed=",story.speed)
 check(story.cart.global_position.distance_to(before_move)>2 and player.get_meta("cart_role","")=="passenger","convoy actually travels while player remains armed passenger")
 # Actual rifle ray impacts, finite ammunition and reloads defeat the live mounts.
 await shoot_mount(story,player,0)
 check(story.defeated.size()==1 and story.wave==1 and story.riders[0].get_node("Vitality").dead,"fallen mount causes a real officer death; one death cannot unlock next pair")
 var checkpoint: Dictionary=story.export_state();var hp: float=story.pursuers[1].vitality.health
 story.pursuers[1].vitality.take_damage(100);story.restore_state(checkpoint)
 for i in 4:await physics_frame
 check(story.defeated==[0] and story.wave==1 and not story.pursuers[1].vitality.dead and is_equal_approx(story.pursuers[1].vitality.health,hp),"earlier chase checkpoint recreates killed target with exact saved health")
 for rider in story.riders:rider.firearm.hostile=false
 await shoot_mount(story,player,1)
 check(story.wave==1 and story.defeated.size()==2,"two officers do not unlock the second wave")
 await shoot_mount(story,player,2)
 check(story.wave==2 and story.defeated.size()==3,"three officers unlock second pair")
 var retry_safety:Node=player.get_node("PlayerSafety")
 player.health=0;retry_safety.show_death()
 var retry_button:Button=null
 for button in retry_safety.find_children("*","Button",true,false):
  if button.text=="Restart from last chase checkpoint":retry_button=button;break
 check(retry_button!=null and not retry_button.disabled,"death offers chase checkpoint restart")
 if retry_button!=null:retry_button.pressed.emit()
 for frame in 4:await physics_frame
 check(player.health>=60 and not player.get_meta("dead",false) and story.stage=="chase" and story.wave==2 and story.defeated.size()==3,"death retry restores wave, health and active chase")
 if OS.get_environment("TLM_CHASE_MOTION")=="1":
  for frame in 4:await process_frame
  var officer:Node3D=story.riders[3]
  await capture(story,"mounted_police_wave2",officer.global_position+Vector3(2.5,1.6,4),officer.global_position+Vector3.UP*.9)
 check(story.pursuers[3].visible and story.pursuers[4].visible,"second two horses are real live targets")
 for rider in story.riders:rider.firearm.hostile=false
 await shoot_mount(story,player,3);check(not story.begin_celebration(),"four defeats cannot end chase")
 await shoot_mount(story,player,4)
 check(story.wave==3 and story.defeated.size()==5 and story.pursuers[5].visible and story.pursuers[6].visible,"five deaths unlock final pair")
 await shoot_mount(story,player,5);check(not story.begin_celebration(),"six defeats cannot end chase")
 await shoot_mount(story,player,6)
 var before: int=player.inventory.get_item_count("rupees")
 check(story.stage=="celebration" and story.riders[6].get_node("Vitality").dead,"seventh officer actually dead before fade")
 check(story.curtain.color.a<.01 and not story.celebration_arrived,"fade starts clear at the chase location")
 story.finish_celebration(.5)
 check(story.curtain.color.a>.4 and story.curtain.color.a<.6 and not story.celebration_arrived,"fade darkens gradually before moving")
 story.finish_celebration(.5)
 check(story.curtain.color.a>.99 and story.celebration_arrived,"move to camp under full black")
 check(not player.is_physics_processing(),"camp discussion owns player movement until completion")
 check(story.dialogue_voice.playing and story.dialogue_queue.size()==1,"fighter and Mangal voices begin in order")
 story.finish_celebration(4.0)
 await capture(story,"camp_discussion",story.discussion_camera.global_position,first.sites.prompts.briefing.global_position)
 var skip:=InputEventAction.new();skip.action="jump";skip.pressed=true;story._input(skip)
 check(player.global_position.distance_to(first.sites.prompts.briefing.global_position+Vector3(1,0,1))<.01,"celebration skip places Arjun at camp discussion endpoint")
 check(story.stage=="complete" and story.paid and player.inventory.get_item_count("rupees")==before+200,"Mangal pays exactly200rupees after victory")
 check(not story.dialogue_voice.playing and story.dialogue_queue.is_empty(),"celebration skip stops and clears speech")
 check(player.is_physics_processing(),"camp discussion restores player physics after skip")
 var complete: Dictionary=story.export_state();story.restore_state(complete);story._process(20)
 check(player.inventory.get_item_count("rupees")==before+200,"completed checkpoint cannot repeat reward")
 check(not player.has_meta("consignment_fpv_camera") and not player.has_meta("consignment_aim_uv"),"mission releases FPV camera and pointer")
 check(story.paused_traffic.is_empty() and not player.get_meta("consignment_camera",false) and not player.get_meta("consignment_rear_combat",false),"mission restores ambient movement and clears passenger capability")
 # A skip in the first frame also frees the FPV camera in that same frame.
 story.restore_state(checkpoint)
 for frame in 70:await physics_frame
 story.defeated.assign([0,1,2,3,4,5,6]);story.paid=true
 check(story.begin_celebration(),"early celebration skip fixture starts")
 var early_skip:=InputEventAction.new();early_skip.action="jump";early_skip.pressed=true;story._input(early_skip)
 print("CONSIGNMENT EARLY SKIP immediate stage=",story.stage," player=",player.global_position," expected=",story.camp_player_position()," physics=",player.is_physics_processing())
 await process_frame
 print("CONSIGNMENT EARLY SKIP after frame stage=",story.stage," player=",player.global_position," velocity=",player.velocity," mounted=",player.get_meta("mounted_vehicle",false))
 var active_camera:=root.get_camera_3d()
 check(story.stage=="complete" and player.global_position.distance_to(story.camp_player_position())<.1,"early skip reaches camp after mount release")
 check(active_camera!=null and not active_camera.is_queued_for_deletion(),"early skip restores a live gameplay camera")
 check(player.inventory.get_item_count("rupees")==before+200,"early skip does not repeat prior payment")
 # Three real death-screen cycles unlock skip, which advances without the reward.
 story.chase_deaths=0;story.restore_state(checkpoint)
 for frame in 4:await physics_frame
 var cash_before_skip:int=player.inventory.get_item_count("rupees")
 for death_number in range(1,4):
  player.health=0;retry_safety.show_death()
  var retry_control:Button=null;var skip_control:Button=null
  for button in retry_safety.find_children("*","Button",true,false):
   if button.text=="Restart from last chase checkpoint":retry_control=button
   if button.text=="Skip mission (forfeit reward)":skip_control=button
  check((skip_control!=null)==(death_number==3),"skip appears only on third death")
  if death_number<3 and retry_control!=null:retry_control.pressed.emit()
  elif skip_control!=null:skip_control.pressed.emit()
  for frame in 4:await physics_frame
 check(story.stage=="celebration" and story.mission_skipped,"third-death skip starts fade sequence")
 story.finish_celebration(story.celebration_duration)
 check(story.stage=="complete" and story.paid and player.inventory.get_item_count("rupees")==cash_before_skip,"skipped mission completes without reward")
 if OS.get_environment("TLM_CHASE_MOTION")=="1":await rebel_outfit_review(story)
 print("CONSIGNMENT STORY: "+("PASS" if failures.is_empty() else "FAIL "+str(failures)))
 var review:=OS.get_environment("TLM_CONSIGNMENT_REVIEW_PATH")
 if not review.is_empty() and DisplayServer.get_name()!="headless":
  print("CONSIGNMENT REVIEW READY")
  var deadline:=Time.get_ticks_msec()+90000
  while Time.get_ticks_msec()<deadline and not FileAccess.file_exists(review.path_join("consignment_done")):await process_frame
 root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)
func shoot_mount(story: Node,player: CharacterBody3D,index: int) -> void:
 var moving:bool=OS.get_environment("TLM_CHASE_CONTINUOUS")=="1"
 if moving and index==0:
  # Isolate firing/reload motion on a long supported straight. A frozen ray target
  # around a corner correctly becomes obscured by the physical side curtain.
  var staged:Dictionary=story.export_state();staged.route_index=0
  story.restore_state(staged)
  for frame in 70:await physics_frame
  for rider in story.riders:rider.firearm.hostile=false
 var start:Vector3=story.cart.global_position
 if moving:story.set_physics_process(true)
 var horse: Node=story.pursuers[index];var gun: Node=player.get_node("RifleCombat")
 # Keep a moving live target behind the rear seat, clear of friendly cover.
 horse.global_position=story.cart.global_position+story.cart.global_basis*Vector3(-3.7 if index%2==0 else 3.7,0,14)
 horse.set_physics_process(false)
 var track:Callable=func():
  horse.global_position=story.cart.to_global(Vector3(-3.7 if index%2==0 else 3.7,0,14))
 if moving:physics_frame.connect(track)
 for i in 4:await physics_frame
 for shot in 2:
  if gun.rounds==0:
   gun.start_reload()
   for i in 120:await physics_frame
  var view:Camera3D=preload("res://story/rear_passenger_combat.gd").aim_camera(player,player.get_node("CameraPivot/SpringArm3D/Camera3D"))
  if view.name=="ConsignmentFirstPerson":view.move_pointer(view.unproject_position(horse.global_position+Vector3.UP*1.2)/root.get_visible_rect().size-view.pointer)
  else:view.look_at(horse.global_position+Vector3.UP*1.2)
  Input.action_press("aim")
  for i in 3:await physics_frame
  var camera: Camera3D=view
  if view.name=="ConsignmentFirstPerson":view.move_pointer(view.unproject_position(horse.global_position+Vector3.UP*1.2)/root.get_visible_rect().size-view.pointer)
  else:camera.look_at(horse.global_position+Vector3.UP*1.2)
  var gear: Node=player.get_node("VisualRoot/CharacterVisual").equipment;gear.aiming=true;gear.aim_direction=preload("res://story/rear_passenger_combat.gd").aim_direction(player,camera)
  var trace=preload("res://combat/ballistic_trace.gd").sight(player.get_world_3d().direct_space_state,self,camera.global_position,camera.global_position+gear.aim_direction*350,preload("res://story/rear_passenger_combat.gd").camera_exclusions(player))
  print("CONSIGNMENT AIM mount=",index," camera_hit=",trace.collider.get_path() if not trace.is_empty() else "none"," muzzle=",gear.enfield_hand.to_global(gun.MUZZLE)," cart=",story.cart.global_position," player=",player.global_position," driver=",story.driver.global_position)
  gun.aiming=true;gun.fire()
  if not gun.impacts.is_empty() and is_instance_valid(gun.impacts[-1]):print("CONSIGNMENT SHOT mount=",index," hit=",gun.impacts[-1].get_parent().get_path()," health=",horse.vitality.health," camera=",camera.global_position)
  for i in 4:await physics_frame
  if story.stage=="chase" and gun.rounds==0 and player.inventory.get_item_count("paper_cartridges")>0:
   for auto_frame in 3:await process_frame
   check(gun.reload_remaining>0 and gun.pending_rounds==1,"empty chase weapon auto reloads using ammunition")
  if horse.vitality.dead:break
 if moving:physics_frame.disconnect(track)
 check(horse.vitality.dead,"real rear passenger rifle impacts defeat mount%d"%index)
 if moving:
  story.set_physics_process(false)
  print("CONSIGNMENT MOVING FIRE target=",index," travel=",story.cart.global_position.distance_to(start))
  check(story.cart.global_position.distance_to(start)>5,"cart continues through real firing and reload target%d"%index)
 Input.action_release("aim")

func capture(story: Node,label: String,at: Vector3,focus: Vector3) -> void:
 var output:=OS.get_environment("TLM_CONSIGNMENT_REVIEW_PATH")
 if output.is_empty() or DisplayServer.get_name()=="headless":return
 if not output.begins_with(OS.get_environment("TMPDIR")):return
 var prior:=root.get_camera_3d();var camera:=Camera3D.new();current_scene.add_child(camera);camera.fov=52;camera.global_position=at;camera.look_at(focus);camera.make_current()
 for i in 8:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(label+".png"))
 if is_instance_valid(prior):prior.make_current()
 camera.queue_free()

func motion_review(story:Node,player:CharacterBody3D,label:String) -> void:
 var camera:Camera3D=preload("res://story/rear_passenger_combat.gd").aim_camera(player,player.get_node("CameraPivot/SpringArm3D/Camera3D"))
 camera.make_current()
 story.set_physics_process(true)
 for mount in story.pursuers:
  if mount.visible:mount.set_physics_process(true)
 for frame in 45:await process_frame
 check(player.get_meta("consignment_camera",false),"mission camera authentic rear seat profile active")
 check(story.cart.boarding.seat_name=="ConsignmentRearSeat","motion keeps passenger seat")
 if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
 var visual:Node=player.get_node("VisualRoot/CharacterVisual")
 print("CONSIGNMENT MOTION ",label," conceal=",visual.consignment_conceal_blend," seat=",story.cart.seat_sockets.ConsignmentRearSeat.position," fpv=",camera.name=="ConsignmentFirstPerson"," fov=",camera.fov)
 if label=="concealed":
  check(visual.consignment_conceal_blend>.95,"conceal reaches stable folded seated pose")
  var rig:Skeleton3D=visual.skeleton
  var head:Vector3=rig.to_global(rig.get_bone_global_pose(rig.find_bone("head")).origin)
  await physics_frame
  print("CONSIGNMENT CONCEAL HEAD local=",story.cart.to_local(head))
  for offset in [story.cart.global_basis*Vector3(4,0,0),story.cart.global_basis*Vector3(0,0,5),Vector3.UP*5]:
   var ray:=PhysicsRayQueryParameters3D.create(head+offset,head,1)
   var ignored:Array[RID]=[]
   var wagon:Node=story.cart.get_node("RebelCoveredWagon")
   for collider in story.cart.find_children("*","CollisionObject3D",true,false):
    if not wagon.is_ancestor_of(collider):ignored.append(collider.get_rid())
   ray.exclude=ignored
   var hit:Dictionary=player.get_world_3d().direct_space_state.intersect_ray(ray)
   print("CONSIGNMENT COVER RAY ",hit.collider.get_path() if not hit.is_empty() else "none")
   check(not hit.is_empty() and story.cart.get_node("RebelCoveredWagon").is_ancestor_of(hit.collider),"opaque covered cart occludes concealed head from side/rear/above")
 else:
  check(visual.consignment_conceal_blend<.05,"combat rises smoothly out of conceal")
  for rider in story.riders:
   if rider.visible and is_instance_valid(rider.patrol_mount):
    check(absf(angle_difference(rider.global_rotation.y,rider.patrol_mount.global_rotation.y+PI))<.05,"police aiming retains saddle-aligned pelvis")
    var hip:Vector3=rider._skeleton.to_global(rider._skeleton.get_bone_global_pose(rider._skeleton.find_bone("pelvis")).origin)
    check(hip.distance_to(rider.patrol_mount.seat_world())<.08,"mounted fire/reload preserves actual saddle contact")
 var output:=OS.get_environment("TLM_CONSIGNMENT_REVIEW_PATH")
 if not output.is_empty() and DisplayServer.get_name()!="headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(output.path_join("motion_"+label+"_camera.png"))
 if label=="armed":
  var cover: Node3D=story.cart.get_node("RebelCoveredWagon")
  check(not cover.curtain.visible and cover.swivel_support.visible,"torn curtain exposes the fixed swivel")
  for remnant in cover.torn_edges:check(remnant.visible,"torn canvas stays attached at the rear edge")
  if not output.is_empty() and DisplayServer.get_name()!="headless":
   var exterior:=Camera3D.new()
   story.cart.add_child(exterior)
   exterior.position=Vector3(2.7,2.65,7.5)
   exterior.look_at(story.cart.to_global(Vector3(0,1.9,3.55)))
   exterior.make_current()
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(output.path_join("motion_torn_exterior.png"))
   camera.make_current()
   exterior.queue_free()
  var rifle:Node=player.get_node("RifleCombat");Input.action_press("aim");rifle.aiming=true
  for frame in 25:await process_frame
  check(camera.name=="ConsignmentFirstPerson" and is_equal_approx(camera.fov,72.0),"fixed first-person camera retains FOV while aiming")
  for frame in 25:await physics_frame
  camera=player.get_meta("consignment_rear_camera",camera)
  var before:Transform3D=camera.transform;var pointer_before:Vector2=player.get_meta("consignment_aim_uv",Vector2(.5,.5))
  var motion:=InputEventMouseMotion.new();motion.relative=Vector2(100,-40);Input.parse_input_event(motion)
  for frame in 3:await process_frame
  check(camera.transform.is_equal_approx(before) and Vector2(player.get_meta("consignment_aim_uv")).distance_to(pointer_before)>.03,"mouse moves pointer without moving FPV camera")
  if not output.is_empty() and DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(output.path_join("motion_aim_camera.png"))
  Input.action_release("aim");rifle.aiming=false
 story.set_physics_process(false)
 for mount in story.pursuers:mount.set_physics_process(false)

func transition_review(story:Node,player:Node) -> void:
 var output:=OS.get_environment("TLM_CONSIGNMENT_REVIEW_PATH")
 for sample in 3:
  for frame in 7:await process_frame
  var current: Camera3D=root.get_camera_3d()
  print("CONSIGNMENT TRANSITION ",sample," blend=",player.get_meta("consignment_conceal_blend",0.0)," seat=",story.cart.seat_sockets.ConsignmentRearSeat.position.z," camera=",current.name if current!=null else "none")
  if current!=null and current.name=="ConsignmentTransitionCamera":
   check(story.cart.to_local(current.global_position).z>preload("res://story/consignment_cart_cover.gd").BACK+.5,"transition camera stays outside cart canvas and cargo")
  if not output.is_empty() and DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(output.path_join("transition_%d.png"%sample))

func rebel_outfit_review(story:Node) -> void:
 var probe:Node3D=preload("res://story/rebellion_actor.gd").new();probe.name="RebelOutfitReview";probe.viewer=story.player;probe.movement_enabled=false;probe.set_meta("external_combat_motion",true);probe.set_meta("mission_active",true)
 probe.add_child(preload("res://characters/human_scene.gd").instantiate("res://characters/npcs/mangal_rebels/mangal_rebel.glb"));current_scene.add_child(probe)
 probe.global_position=story.cart.global_position+Vector3(5,0,0);probe.global_rotation.y=0;probe.set_process(false)
 var query:=PhysicsRayQueryParameters3D.create(probe.global_position+Vector3.UP*100,probe.global_position-Vector3.UP*100,1)
 for collider in probe.find_children("*","CollisionObject3D",true,false):query.exclude.append(collider.get_rid())
 var support:Dictionary=probe.get_world_3d().direct_space_state.intersect_ray(query)
 if not support.is_empty():probe.global_position.y=support.position.y
 check(not support.is_empty(),"outfit review has actual local ground support")
 var full_body=false;var foundation=false;var hem=false
 for mesh in probe.find_children("*","MeshInstance3D",true,false):
  var label=(str(mesh.name)+" "+mesh.mesh.resource_name).to_lower()
  if "complete original mpfb body" in label:full_body=mesh.visible
  if "foundation" in label:foundation=mesh.visible
  if "woven waist sash" in label:hem=mesh.visible
 check(full_body and foundation and hem,"rebel retains visible full MPFB body/foundation and distinct woven waist sash")
 for pose in ["idle","walk","run","turn","seated"]:
  probe.travel_speed=3.8 if pose=="run" else 1.3 if pose=="walk" else 0.0
  probe.set_meta("patrol_turning",pose=="turn");probe._turn_progress=.5
  if pose=="seated":
   var socket:=Node3D.new();current_scene.add_child(socket);socket.global_position=probe.global_position+Vector3.UP*.8;socket.rotation.y=story.cart.global_rotation.y
   probe.riding_cart=story.cart;probe.riding_socket=socket;probe.seated_foot_drop=.38;probe.seated_foot_forward=-.48
   var builder=load("res://world/suryagarh/settlements/settlement_builder.gd").new();builder.wood=builder.material(Color(.34,.23,.13))
   builder.piece(socket,"ReviewSeatSupport",Vector3(0,-.07,0),Vector3(.85,.08,.6),builder.wood)
   var board:Node3D=builder.piece(socket,"ReviewFootSupport",Vector3.ZERO,Vector3(.8,.07,.42),builder.wood)
   board.global_transform=Transform3D(story.cart.global_basis,socket.global_position+story.cart.global_basis*Vector3(0,-.38,-.48)-Vector3.UP*.035)
   builder.free()
  for sample in 60:probe._process(1.0/60.0)
  var focus:Vector3=probe.global_position+Vector3.UP*.9
  await capture(story,"rebel_"+pose+"_front",focus+probe.global_basis*Vector3(2.0,.3,3.3),focus)
  await capture(story,"rebel_"+pose+"_side",focus+probe.global_basis*Vector3(3.3,.2,-1),focus)
  print("CONSIGNMENT REBEL POSE ",pose," animation=",probe.animation_state," blend=",probe.locomotion_blend)
  if pose in ["walk","run"]:check(probe.locomotion_blend>.95,"rebel locomotion AnimationTree active "+pose)
 if is_instance_valid(probe.riding_socket):probe.riding_socket.queue_free()
 probe.queue_free();await process_frame

func continuous_review(story:Node,player:Node) -> void:
 var checkpoint:Dictionary=story.export_state()
 for i in story.pursuers.size():story.pursuers[i].set_physics_process(false);story.riders[i].firearm.hostile=false
 story.route_index=story.holding_end-3;story.cart.global_position=story.route[story.route_index];story.cart.basis=story.route_frame(story.cart.global_position,story.route_index,1);story.speed=10
 await capture(story,"expanded_wilderness",story.cart.global_position+Vector3(18,10,24),story.cart.global_position+Vector3.UP*2)
 var distance=0.0;var minimum=INF;var maximum=0.0;var laps_before:int=story.holding_laps
 for frame in 2000:
  var before:Vector3=story.cart.global_position
  story._physics_process(.1)
  var step:float=before.distance_to(story.cart.global_position);distance+=step;minimum=minf(minimum,step);maximum=maxf(maximum,step)
  if frame%8==0:await physics_frame
  if step<.001:
   print("CONSIGNMENT CIRCUIT BLOCK at=",story.cart.global_position," index=",story.route_index," health=",player.health)
   for volume in story.cart.boarding.clearance_shapes:
    var query:=PhysicsShapeQueryParameters3D.new();query.shape=volume.shape;query.transform=volume.global_transform;query.collision_mask=1;query.exclude=story.cart.boarding._vehicle_exclusions()
    for hit in player.get_world_3d().direct_space_state.intersect_shape(query,4):print("CONSIGNMENT CIRCUIT COLLIDER ",hit.collider.get_path())
   break
 print("CONSIGNMENT CONTINUOUS metres=",distance," minimum_step=",minimum," maximum_step=",maximum," laps=",story.holding_laps-laps_before," stage=",story.stage)
 check(story.stage=="chase" and minimum>.30 and maximum<1.01 and story.holding_laps-laps_before>=2,"cart continuously crosses waypoints and repeats physical pursuit circuit without stop/teleport")
 check(story.cart.rider==player and player.get_meta("cart_role","")=="passenger","moving circuit retains actual rear passenger")
 story.restore_state(checkpoint)
 for frame in 70:await physics_frame
 print("CONSIGNMENT CIRCUIT RESTORE stage=",story.stage," health=",player.health," rider=",story.cart.rider==player)
 check(player.health>0 and story.stage=="chase" and story.cart.rider==player,"remote circuit checkpoint restore resets relocation fall history before physics")
