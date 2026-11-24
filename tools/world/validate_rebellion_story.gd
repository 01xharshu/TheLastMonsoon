extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
class Fixture:
 extends Node3D
 var layout=preload("res://world/suryagarh/landscape_layout.gd").new()
class PriorStory:
 extends Node
 var state:="awaiting_inquiry"
 var active:=false
 var configured:=true
 func export_state() -> Dictionary:return {"state":state}
 func restore_state(data: Dictionary) -> void:state=str(data.get("state","complete"))
class Inquiry:
 extends Node
 var guards:Array[Node3D]=[]
 var station: Node3D
 var configured:=true
 var stage:="released"
 var destination: Node3D
 var dialogue:=""
 func export_state() -> Dictionary:return {"stage":stage}
 func restore_state(data: Dictionary) -> void:stage=str(data.get("stage","released"))
func check(ok: bool,label: String) -> void:
 if not ok:failures.append(label);push_error(label)
func run() -> void:
 var temporary:=OS.get_environment("TLM_STORY_TEST_DIR")
 if temporary.is_empty() or not temporary.begins_with(OS.get_environment("TMPDIR")):quit(2);return
 root.get_node("SaveManager").save_root=temporary
 var script=load("res://story/rebellion_story.gd")
 if script==null or not script.can_instantiate():quit(1);return
 var world:=Fixture.new();root.add_child(world);current_scene=world
 var clock=load("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock)
 var player: CharacterBody3D=load("res://player/player.tscn").instantiate();player.name="Player";player.position=Vector3(40,2,40);world.add_child(player)
 var settlement:=Node3D.new();settlement.name="Settlement";world.add_child(settlement)
 var station=load("res://world/suryagarh/settlements/civic_building.gd").new();station.name="DistrictPolice";station.police=true;settlement.add_child(station);station.position=Vector3(310,0,150)
 var fort:=Node3D.new();fort.name="OldFort";world.add_child(fort);fort.position=Vector3(520,120,-350)
 var cantonment:=Node3D.new();cantonment.name="BritishCantonment";world.add_child(cantonment);cantonment.position=Vector3(500,8.5,470)
 fixture_ground(world,Rect2(Vector2(430,-420),Vector2(200,230)))
 fixture_ground(world,Rect2(Vector2(540,420),Vector2(100,120)))
 var prior:=PriorStory.new();prior.name="DevStory";world.add_child(prior)
 var inquiry:=Inquiry.new();inquiry.name="DevInquiry";inquiry.station=station;world.add_child(inquiry);inquiry.destination=Node3D.new();world.add_child(inquiry.destination)
 var environment:=WorldEnvironment.new();var settings:=Environment.new();settings.background_mode=Environment.BG_COLOR;settings.background_color=Color(.55,.66,.75);settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color.WHITE;settings.ambient_light_energy=.7;environment.environment=settings;world.add_child(environment)
 var sun:=DirectionalLight3D.new();world.add_child(sun);sun.rotation_degrees=Vector3(-50,-30,0);sun.light_energy=1.2
 var police=load("res://world/suryagarh/combat_encounters.gd").new();police.name="CombatEncounters";world.add_child(police)
 var story: Node=script.new();world.add_child(story)
 story.restore_state({"stage":"dormant","follow_index":1})
 check(story.restore_waiting and story.export_state().get("follow_index")==1,"early restore queues an independent saved state")
 for i in 120:await physics_frame
 check(story.configured,"mission configured")
 if not story.configured:quit(1);return
 check(not story.restore_waiting and story.follow_index==1,"queued restore applies once after complete site readiness")
 # Every mandatory opening continuation remains in daylight, including restored
 # legacy night saves; accepting the next mission is a free-roam boundary.
 for saved_stage in ["ambush","confront","escape","follow","briefing","inspect","load","shoot","infiltrate","collect","rope","return"]:
  clock.total_game_minutes=1320
  story.set_stage(saved_stage)
  var frozen: float=clock.total_game_minutes
  clock._process(600);clock.advance_hours(24)
  check(clock.total_game_minutes==frozen and clock.current_hour>=8 and clock.current_hour<17,"daylight holds through "+saved_stage)
 for free_stage in ["raid_ready","complete"]:
  story.set_stage(free_stage)
  var before: float=clock.total_game_minutes
  clock._process(1)
  check(clock.total_game_minutes>before,"free roam resumes clock at "+free_stage)
 story.set_stage("dormant")
 story.follow_index=0
 story.set_process(false)
 story._process(.1)
 check(story.stage=="dormant" and not story.active,"rebellion cannot precede completed equipment training")
 prior.state="complete"
 var occupied_domains: Array[StringName]=[&"move"]
 var conflict=story.action_service.acquire(prior,occupied_domains)
 story._process(.1);check(not story.active and story.stage=="dormant","cinematic waits for an existing action lease")
 var fixture_errands:=Node.new()
 fixture_errands.name="ErrandSystem"
 world.add_child(fixture_errands)
 var visible_overlay:=CanvasLayer.new()
 var hidden_overlay:=CanvasLayer.new()
 fixture_errands.add_child(visible_overlay)
 fixture_errands.add_child(hidden_overlay)
 hidden_overlay.hide()
 story.action_service.release(conflict);story._process(.1)
 check(not visible_overlay.visible and not hidden_overlay.visible,"cinematic hides errand layers")
 check(story.active and story.cinematic=="days","training completion hands off")
 check(not root.get_node("SaveManager").save_game(world,1),"cinematic save blocked")
 story.skip_cinematic()
 check(visible_overlay.visible and not hidden_overlay.visible,"cinematic skip restores each errand layer visibility")
 fixture_errands.queue_free()
 check(player.global_position.distance_to(story.sites.tree.global_position+Vector3(0,.9,-4))<.01,"days skip reaches intended tree arrival")
 check(story.stage=="ambush" and player.is_physics_processing(),"days fade releases ambush")
 player.global_position=story.sites.tree.global_position+Vector3(0,.9,-1.5);story._process(.1)
 check(story.stage=="confront","tree ambush triggers official walk")
 story.sites.officer.get_node("Vitality").receive_hit(100,player,"sword")
 check(story.stage=="escape" and police.wanted_level>0,"real lethal contact starts wanted chase")
 check(not story.request("bundle0",player),"cannot loot before raid")
 police.complete_custody(player)
 story.set_stage("infiltrate")
 var guard: Node3D=story.sites.guards[0]
 guard.travel_speed=0;player.global_position=guard.global_position-guard.global_basis.z*.65+Vector3.UP*.9;player.velocity=Vector3.ZERO
 for i in 15:await physics_frame
 var grapple: Node=player.get_node("RearGrapple")
 check(story.rear_target()==guard,"Q rear eligibility")
 check(grapple.begin(),"real paired rear takedown begins")
 for i in 150:await physics_frame
 check(guard.get_meta("knocked_out",false) and not guard.get_meta("dead",false) and not grapple.active,"mission takedown is nonlethal and releases controls")
 var hero: Node3D=player.get_node("VisualRoot/CharacterVisual")
 var body_counts: Dictionary={}
 for mesh in hero.find_children("*","MeshInstance3D",true,false):
  if "body" in str(mesh.name).to_lower():body_counts[mesh]=mesh.mesh
 check(not body_counts.is_empty(),"player body invariant is non-vacuous")
 check(story.request("uniform0",player),"uniform transfer succeeds")
 for mesh in body_counts:check(mesh.mesh==body_counts[mesh] and mesh.visible,"disguise preserves complete body")
 check(guard._skeleton.get_node_or_null("OpaqueLungiSocket")!=null,"defeated guard retains opaque lungi")
 var retained_foundation=guard._skeleton.get_node_or_null("TakenUniformFoundation")
 check(retained_foundation!=null and "foundation" in str(retained_foundation.get_meta("source_garment","")),"guard receives actual opaque foundation garment")
 check(story.outfit.additions.size()>0,"uniform is skinned to original player rig")
 if OS.get_environment("TLM_REBELLION_MESH_AUDIT")=="1":
  for mesh in hero.find_children("*","MeshInstance3D",true,false):
   if mesh.visible:print("VISIBLE ",story.outfit.mesh_label(mesh))
 if OS.get_environment("TLM_REBELLION_NATIVE")=="1":
  story.camera.make_current();story.camera.global_position=player.global_position+Vector3(2,1,3);story.camera.look_at(player.global_position+Vector3.UP*.3)
  await capture("uniform",temporary)
  story.camera.global_position=story.sites.raid.to_global(Vector3(18,12,27));story.camera.look_at(story.sites.raid.global_position+Vector3.UP*3)
  await capture("magazine",temporary)
  story.camera.global_position=story.sites.cellar.to_global(Vector3(6,2,5));story.camera.look_at(story.sites.cellar.to_global(Vector3(-2,1.5,-2)))
  await capture("hideout",temporary)
  if OS.get_environment("TLM_REBELLION_VIEW_ONLY")=="1":
   story.set_stage("rope");story.collected.assign([0,1,2,3]);story.begin_cinematic("rope");story.update_cinematic(5)
   await capture("rope",temporary);story.finish_cinematic();story.release_mount(story.sites.goods)
   story.sites.horse.global_position=story.ground(fort.to_global(Vector3(0,0,105)));player.global_position=story.sites.horse.global_position+Vector3(1,.9,0);story.sites.horse.board(player);story.sites.horse.transition_time=5;story.sites.horse._physics_process(.02)
   story.begin_cinematic("rescue");story.update_cinematic(7.5);await capture("rescue",temporary);story.finish_cinematic();story.finish_cinematic()
   print("REBELLION VIEWS COMPLETE");world.queue_free();await process_frame;root.get_node("SaveManager").quit_game(0);return
 story.outfit.remove();story.disguise=false
 # Real controller route climbs the stairwell rather than testing only its meshes.
 player.global_position=story.sites.raid.to_global(Vector3(-5,1.1,9));player.velocity=Vector3.ZERO
 for i in 20:await physics_frame
 await walk(player,story.sites.raid.to_global(Vector3(-5,4.6,.3)),360)
 check(player.global_position.y>story.sites.raid.global_position.y+4.25,"controller reaches second floor by stairs")


 story.set_stage("collect")
 for invalid in ["bundle-1","bundle4","bundle99","bundlenonsense"]:
  check(not story.request(invalid,player),"invalid bundle rejected "+invalid)
 for i in 4:
  check(story.request("bundle%d"%i,player),"bundle collected %d"%i)
  if i<3:check(story.stage=="collect" and not story.can_request("rope"),"rope remains locked until all four bundles")
 check(story.stage=="rope" and story.collected.size()==4,"four bundles required")
 check(not story.request("bundle0",player),"duplicate reward prevented")
 var data: Dictionary=story.export_state();story.restore_state(data)
 check(story.stage=="rope" and story.collected.size()==4,"mission restore keeps bundles")
 check(story.request("rope",player),"rope action requires all bundles")
 for i in 60:story.update_cinematic(.1);await physics_frame
 print("ROPE PALM ERROR ",story.rope_contact_error)
 check(story.rope_contact_error<.05,"rope palms reach the actual rope")
 if OS.get_environment("TLM_REBELLION_NATIVE")=="1":await capture("rope",temporary)
 for i in 121:story.update_cinematic(.1);await physics_frame
 check(story.stage=="return" and story.sites.goods.rider==player,"rope and cart jump release driving gameplay")
 story.release_mount(story.sites.goods)

 story.restore_state({"stage":"bad","collected":[-1,0,0,9]})
 check(story.stage=="dormant" and story.collected==[0],"invalid state sanitised")
 # Verify an unsupported cinematic step cannot move the coach off the ground.
 var coach: Node3D=story.sites.coach
 var coach_start:=coach.global_transform
 coach.global_position+=Vector3.UP*12
 var unsupported_start:=coach.global_position
 story.move_cinematic_cart(coach,2.0,.2)
 check(coach.global_position.is_equal_approx(unsupported_start),"cinematic coach refuses steps without terrain support")
 coach.global_transform=coach_start
 # Rescue must use the real horse and carriage boarding contract.
 story.sites.set_enabled(true);story.set_stage("escape");story.sites.horse.global_position=story.ground(fort.to_global(Vector3(0,0,95)))
 story.sites.b.piece(world,"FixtureHorseSupport",story.sites.horse.global_position-Vector3.UP*.15,Vector3(100,.2,100),story.sites.b.stone)
 player.global_position=story.sites.horse.global_position+Vector3(1,.9,0)
 check(story.sites.horse.board(player),"superior horse boards")
 for i in 100:await physics_frame
 story._process(.01)
 check(story.active and story.cinematic=="rescue","approaching fort on horse begins rescue")
 for i in 300:
  story.update_cinematic(.1);await physics_frame
  if i==75 and OS.get_environment("TLM_REBELLION_NATIVE")=="1":await capture("rescue",temporary)
  if story.cinematic=="arrival":break
 check(story.active and story.cinematic=="arrival","rescue transitions to fort arrival")
 for i in 75:
  story.update_cinematic(.1);await physics_frame
 check(story.stage=="follow" and (player.get_meta("mounted_vehicle") if player.has_meta("mounted_vehicle") else null)==null,"fort arrival releases follow gameplay")
 # The broken flank walls should stop a lateral crossing and leave the centre open.
 var undercroft:Node3D=story.sites.cellar
 var space:=undercroft.get_world_3d().direct_space_state
 var flank_ray:=PhysicsRayQueryParameters3D.create(undercroft.to_global(Vector3(3,4,18.45)),undercroft.to_global(Vector3(4.3,4,18.45)),1)
 var flank_hit:=space.intersect_ray(flank_ray)
 check(not flank_hit.is_empty() and "BrokenTerraceParapet" in str(flank_hit.collider.get_parent().name),"broken terrace masonry has flank collision")
 for side in [-1.0,1.0]:
  var shoulder_x:float=side*11.6
  var shoulder_ray:=PhysicsRayQueryParameters3D.create(undercroft.to_global(Vector3(shoulder_x,5.0,0)),undercroft.to_global(Vector3(shoulder_x,1.0,0)),1)
  var shoulder_hit:=space.intersect_ray(shoulder_ray)
  check(not shoulder_hit.is_empty() and "EarthenShoulder" in str(shoulder_hit.collider.name) and shoulder_hit.normal.y>0.3,"earthen shoulder has upward support on side "+str(side))
 var screen_x:=4.42
 var screen_z:=27.13
 var screen_base:=preload("res://story/rebel_hideout_environment.gd").terrain_y(undercroft,Vector3(screen_x,0,screen_z))
 var screen_from:=undercroft.to_global(Vector3(screen_x,screen_base+1.0,screen_z+1.0))
 var screen_to:=undercroft.to_global(Vector3(screen_x,screen_base+1.0,screen_z-1.0))
 var screen_hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(screen_from,screen_to,1))
 check(not screen_hit.is_empty() and "BreachedCurtainRemnant" in str(screen_hit.collider.get_parent().name),"breach remnant blocks a flank sightline")
 var center_from:=undercroft.to_global(Vector3(0,5,28))
 var center_to:=undercroft.to_global(Vector3(0,5,26))
 check(space.intersect_ray(PhysicsRayQueryParameters3D.create(center_from,center_to,1)).is_empty(),"breach remnants leave the center approach open")
 var prior_follow:Dictionary=story.export_state()
 var legacy_follow:=prior_follow.duplicate(true)
 legacy_follow["hideout_route_version"]=2
 legacy_follow["follow_index"]=4
 legacy_follow.actors[1]["position"]=[10,20,30]
 player.velocity=Vector3.ONE
 story.restore_state(legacy_follow)
 var migrated_start:Vector3=story.ground(story.sites.cellar.to_global(Vector3(0,0,34)))
 check(story.stage=="follow" and story.follow_index==0 and story.sites.mangal.global_position.is_equal_approx(migrated_start),"breach save restarts at the current supported follow entry")
 check(player.global_position.is_equal_approx(migrated_start+Vector3(2,.9,2)) and player.velocity==Vector3.ZERO,"breach save relocates Arjun alongside Mangal")
 prior_follow["follow_index"]=2
 story.restore_state(prior_follow)
 check(story.follow_index==2,"current follow checkpoint retains its waypoint")
 # Traverse the terrace and descending passage with normal controller physics.
 var approach: Vector3=story.ground(story.sites.cellar.to_global(Vector3(0,0,34)))
 story.sites.b.piece(world,"FixtureCellarGround",approach+Vector3(0,-.1,2),Vector3(12,.2,6),story.sites.b.stone)
 player.global_position=approach+Vector3.UP*.96
 player.velocity=Vector3.ZERO
 for frame in 5:await physics_frame
 for goal in [Vector3(0,4.6,24),Vector3(0,4.6,18),Vector3(0,1.1,7),Vector3(0,1.1,3)]:
  await walk(player,story.sites.cellar.to_global(goal),420)
  print("UNDERCROFT ROUTE ",goal," -> ",story.sites.cellar.to_local(player.global_position))
 check(absf(player.global_position.y-story.sites.cellar.global_position.y-1.1)<.4,"controller descends into undercroft")
 story.set_stage("inspect")
 check(story.request("weapons",player),"taking the rack rifle grants Enfield and cartridges")
 check(not story.sites.rack_rifle.visible and story.stage=="load","one rifle disappears and the lesson waits for equip")
 check(not story.can_request("raid"),"raid locked before the target hit")
 var equip:=InputEventKey.new()
 equip.physical_keycode=KEY_2
 equip.pressed=true
 hero._unhandled_input(equip)
 await process_frame
 story._process(.01)
 check(story.active and story.cinematic=="range_entry","equipping starts the mandatory fade")
 if story.cinematic!="range_entry":
  await preload("res://tools/test_audio_cleanup.gd").finish(self,1)
  return
 story.skip_cinematic()
 check(story.active and story.cinematic=="range_entry","range fade cannot be skipped")
 story.update_cinematic(.55)
 check(story.shade.color.a>.99 and player.global_position.distance_to(story.sites.firing_line.global_position)<1.2,"player is transferred while black")
 story.update_cinematic(.7)
 check(story.stage=="shoot" and player.get_meta("rifle_lesson",false),"fade ends in the locked range")
 for frame in 20:await physics_frame
 var lock_start:=player.global_position
 Input.action_press("move_forward")
 Input.action_press("jump")
 for frame in 36:await physics_frame
 Input.action_release("move_forward")
 Input.action_release("jump")
 check(player.global_position.distance_to(lock_start)<.1,"movement and jumping cannot leave the firing line")
 var gun:Node=player.get_node("RifleCombat")
 var fire:=InputEventAction.new()
 fire.action="attack"
 fire.pressed=true
 var shots:int=gun.shots_fired
 player.get_node("CombatInput")._unhandled_input(fire)
 check(gun.shots_fired==shots,"fire input without aiming cannot discharge")
 Input.action_press("aim")
 await process_frame
 gun._process(.01)
 var view:Camera3D=player.get_node("CameraPivot/SpringArm3D/Camera3D")
 player.camera_pivot.global_rotation=Vector3(.62,PI,0)
 view.rotation=Vector3.ZERO
 player.camera_pivot.force_update_transform()
 view.force_update_transform()
 fire.pressed=true
 player.get_node("CombatInput")._unhandled_input(fire)
 story._process(.01)
 print("HIDEOUT ENVIRONMENT RIFLE MISS shots=",gun.shots_fired-shots," stage=",story.stage," hit=",story.target_hits," remaining=",gun.reload_remaining," rounds=",gun.rounds," aiming=",gun.aiming," input=",Input.is_action_pressed("aim"))
 check(gun.shots_fired==shots+1 and story.stage=="shoot" and gun.reload_remaining>0,"missing keeps the player locked and reloads automatically")
 gun._process(gun.reload_remaining+.01)
 gun._process(.01)
 view.look_at(story.sites.target.global_position)
 view.force_update_transform()
 fire.pressed=true
 player.get_node("CombatInput")._unhandled_input(fire)
 print("RIFLE LESSON retry shots=",gun.shots_fired," rounds=",gun.rounds," impacts=",gun.impacts.size())
 story._process(.01)
 Input.action_release("aim")
 check(story.target_hits==1 and story.stage=="raid_ready" and not player.get_meta("rifle_lesson",false),"one aimed hit on the log releases the lesson")
 var release_start:=player.global_position
 Input.action_press("move_forward")
 for frame in 24:await physics_frame
 Input.action_release("move_forward")
 check(Vector2(player.global_position.x-release_start.x,player.global_position.z-release_start.z).length()>.25,"normal movement returns after the hit")
 var input_settings:Node=root.get_node("SaveManager")
 input_settings._set_active_input_device("controller")
 check(story.input_label("aim","")=="Left trigger" and story.input_label("attack","")=="Right trigger","controller instruction follows trigger bindings")
 input_settings._set_active_input_device("keyboard_mouse")
 check(story.input_label("aim","")=="Right click" and story.input_label("attack","")=="Left click","mouse instruction follows click bindings")


 var saves: Node=root.get_node("SaveManager")
 police.complete_custody(player);story.set_stage("collect");story.collected.assign([0,1])
 check(saves.save_game(world,1),"SaveManager saves partial rifle collection")
 story.stage="raid_ready";story.collected.clear();saves.pending_slot=1;saves.apply_pending(world)
 for i in 3:await physics_frame
 check(story.stage=="collect" and story.collected==[0,1],"SaveManager restores exact collection checkpoint")
 for i in [2,3]:check(story.request("bundle%d"%i,player),"remaining saved bundles collected")
 check(story.request("rope",player),"saved collection unlocks rope")
 story.skip_cinematic()
 for i in 100:await physics_frame
 check(saves.save_game(world,1),"driving return checkpoint saves")
 story.release_mount(story.sites.goods);story.stage="collect";saves.pending_slot=1;saves.apply_pending(world)
 for i in 100:await physics_frame
 check(story.stage=="return" and story.sites.goods.rider==player,"saved goods cart restores driving rider")
 story.sites.goods.global_position=story.sites.return_bay.global_position+Vector3(7,0,0);story._process(.01)
 check(not story.active,"cart outside bay cannot complete delivery")
 story.sites.goods.global_position=story.sites.return_bay.global_position;story.sites.goods.rotation.y=story.sites.return_bay.rotation.y;story.sites.goods.boarding.speed=2;story._process(.01)
 check(not story.active,"moving cart cannot complete delivery")
 story.sites.goods.boarding.speed=0;story._process(.01)
 check(story.active and story.cinematic=="delivery","stopped whole cart inside bay begins completion")
 check(not saves.save_game(world,2),"delivery cinematic cannot be saved")
 story.skip_cinematic()
 check(story.stage=="complete" and story.captured_rifles==12 and not story.sites.return_bay.visible,"delivery records twelve rifles and retires rectangle")
 var reward_count: int=player.inventory.get_item_count("paper_cartridges");story._process(1)
 check(player.inventory.get_item_count("paper_cartridges")==reward_count,"delivery reward cannot repeat")
 check(saves.save_game(world,2),"completed continuation saves")
 saves.pending_slot=2;saves.apply_pending(world)
 check(story.stage=="complete" and story.captured_rifles==12,"completed continuation restores without reward replay")

 # Early skips still resolve the actual connected rescue/arrival and rope endpoints.
 story.release_mount(player.get_meta("mounted_vehicle") if player.has_meta("mounted_vehicle") else null)
 story.sites.set_enabled(true)
 player.global_position=story.sites.horse.global_position+Vector3(1,.9,0)
 check(story.sites.horse.board(player),"skip fixture boards real rescue horse")
 for i in 100:await physics_frame
 check(story.begin_cinematic("rescue"),"rescue skip fixture starts")
 story.update_cinematic(.1)
 check(story.dialogue_voice.playing and story.dialogue_voice.stream!=null,"Mangal rescue line plays on the authored caption")
 var spoken_age: float=story.age
 story.update_cinematic(.1)
 check(story.age-spoken_age<.1,"long rescue voice extends its caption interval")
 story.skip_cinematic()
 check(not story.dialogue_voice.playing,"skipping connected shots stops Mangal's voice")
 var arrival: Vector3=story.sites.mangal.global_position+Vector3(2,.9,2)
 check(not story.active and story.stage=="follow" and player.global_position.distance_to(arrival)<.01,"rescue skip resolves linked arrival at hideout")
 check((player.get_meta("mounted_vehicle") if player.has_meta("mounted_vehicle") else null)==null,"rescue skip restores dismounted player")
 check(story.begin_cinematic("briefing"),"briefing skip fixture starts")
 story.skip_cinematic()
 check(not story.active and story.stage=="inspect","briefing skip reaches inspect objective")
 story.set_stage("rope")
 check(story.begin_cinematic("rope"),"rope skip fixture starts")
 story.skip_cinematic()
 check(not story.active and story.stage=="return" and story.sites.goods.rider==player,"rope skip puts player on cart at return objective")

 # Actual mission-owned camp population is staged after arriving at the hideout.
 story.release_mount(story.sites.goods);story.set_stage("complete")
 var daily:Node=story.sites.cellar.get_node("HideoutDailyLife")
 player.global_position=story.sites.cellar.to_global(Vector3(0,1.0,4))
 player.velocity=Vector3.ZERO
 for frame in 240:await physics_frame
 check(daily.records.size()==daily.JOBS.size(),"all stable hideout daily assignments are spawned")
 var roles:Array=[]
 for record in daily.records:roles.append(record.job)
 check(roles.has("watch_roof_left") and roles.has("gate_watch") and roles.has("seated_talk") and roles.has("relax") and roles.has("sleep") and roles.has("carry_supplies") and roles.has("mangal_listener"),"watch, talk, rest, sleeping, carrying and Mangal discussion roles exist")
 check(story.sites.trainees.all(func(t):return not t.visible),"training sentries are not left standing inside at idle")
 print("HIDEOUT MANGAL stage=",story.stage," active=",story.active," cinematic=",player.get_meta("story_cinematic",false)," seat_owned=",daily.seat_owned," socket=",story.sites.mangal.riding_socket)
 check(daily.seat_owned and story.sites.mangal.riding_socket==daily.mangal_seat,"original Mangal sits for off-mission discussion")
 var sleeper:Node3D=daily.get_node("Camp_sleep")
 check(sleeper.visible and absf(sleeper.rotation.x-PI*.5)<.01 and daily.get_node("Camp_sleep_right").visible,"two sleeping residents lie on interior bedrolls")
 var talker:Node3D=daily.get_node("Camp_seated_talk")
 check(talker.visible and talker.get_meta("activity","")=="read","conversation participant uses seated activity graph")
 var carrier:Node3D=daily.get_node("Camp_carry_supplies")
 check(carrier.visible and is_instance_valid(carrier.get_meta("carried_load",null)),"worker carries actual load on terrace")
 var terrace_top:float=story.sites.cellar.to_global(Vector3(0,3.7,0)).y
 check(absf(float(carrier.foot_plant.ankle_height["l"])-terrace_top)<.4 and absf(float(carrier.foot_plant.ankle_height["r"])-terrace_top)<.4,"carrier foot plant is rebased to terrace, not cellar floor")
 var carrier_travel_before:float=daily.records[7].travelled
 for frame in 300:
  await physics_frame
  if daily.records[7].travelled-carrier_travel_before>.3:break
 var carrier_travel:float=daily.records[7].travelled-carrier_travel_before
 print("HIDEOUT CARRIER walked=",carrier_travel," progress=",daily.records[7].distance," direction=",daily.records[7].direction)
 check(carrier_travel>.25,"carrier actually walks while holding supplies")
 for side in ["l","r"]:
  var hand_bone:int=carrier._skeleton.find_bone("hand_"+side)
  var rest_hand:Vector3=carrier.to_local(carrier._skeleton.to_global(carrier._skeleton.get_bone_global_rest(hand_bone).origin))
  var target:Vector3=carrier.to_local(carrier.get_meta("camp_grip_target_"+side,Vector3.ZERO))
  check(rest_hand.x*target.x>0,"carrier "+side+" hand grips on its own side")
 var saved_daily:Dictionary=daily.export_state()
 check(daily.JOBS.all(func(role):return saved_daily.has(role)) and saved_daily.has("_routine_clock") and story.export_state().get("hideout_daily",{}).has("_routine_clock"),"individual camp roles and routine clock are saved")
 daily.set_process(false)
 var carrier_record:Dictionary=daily.records[7]
 carrier_record.distance=1.25;carrier_record.direction=-1
 var carry_state:Dictionary=daily.export_state()
 carrier_record.distance=0.0;carrier_record.direction=1
 daily.restore_state(carry_state)
 check(is_equal_approx(carrier_record.distance,1.25) and carrier_record.direction==-1 and absf(carrier.position.z-21.25)<.01,"carrier identity and progress restore without route jump")
 var carrier_vitality:Node=carrier.get_node("Vitality")
 carrier_vitality.health=20.0;carrier.set_meta("knocked_out",true)
 var injured_state:Dictionary=daily.export_state()
 carrier_vitality.health=5.0;carrier.set_meta("knocked_out",false)
 daily.restore_state(injured_state)
 check(is_equal_approx(carrier_vitality.health,20.0) and carrier.get_meta("knocked_out",false),"camp member health and knockout restore")
 daily.restore_state(saved_daily)
 daily.set_process(true)
 story.set_stage("inspect")
 for frame in 4:await process_frame
 check(story.sites.trainees.all(func(t):return t.visible),"weapon lesson restores actual training participants")
 story.set_stage("complete")
 for frame in 3:await physics_frame
 check(story.sites.trainees.all(func(t):return not t.visible),"training participants return to ordinary camp outside lesson")

 print("REBELLION STORY: "+("PASS" if failures.is_empty() else "FAIL "+str(failures)))
 world.queue_free();await process_frame;root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)

class SnapshotPose:
 extends Node
 var director: Node
 func _process(_delta: float) -> void:
  if director.active:director.update_cinematic(0)
  director.camera.make_current()
func capture(label: String,directory: String) -> void:
 var director: Node=current_scene.get_node("RebellionStory");var processing:=director.is_processing()
 director.set_process(false)
 var snapshot:=SnapshotPose.new();snapshot.director=director;snapshot.process_priority=200;current_scene.add_child(snapshot)
 for i in 8:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(directory.path_join(label+".png"))
 snapshot.queue_free();director.set_process(processing)

func walk(actor: CharacterBody3D,goal: Vector3,frames: int) -> void:
 var button:=InputEventAction.new();button.action="move_forward";button.pressed=true;Input.parse_input_event(button)
 for i in frames:
  var direction:=goal-actor.global_position;direction.y=0
  if direction.length()<.35:break
  actor.camera_pivot.global_rotation=Vector3(0,atan2(-direction.x,-direction.z),0)
  actor.visual_root.global_rotation=Vector3(0,atan2(direction.x,direction.z),0)
  await physics_frame
 button.pressed=false;Input.parse_input_event(button)
 for i in 10:await physics_frame

func fixture_ground(world: Node3D,region: Rect2) -> void:
 # The production cart now has gravity/fatal-fall support and Q requires grounded
 # control. Supply the same terrain sampler in this otherwise isolated fixture.
 var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
 var columns:=ceili(region.size.x/4);var rows:=ceili(region.size.y/4)
 for x in columns:
  for z in rows:
   var a:=region.position+Vector2(x*4,z*4);var b:=a+Vector2(4,0);var c:=a+Vector2(0,4);var d:=a+Vector2(4,4)
   for point: Vector2 in [a,c,b,b,c,d]:surface.add_vertex(Vector3(point.x,world.layout.height(point.x,point.y),point.y))
 var mesh:=surface.commit();var body:=StaticBody3D.new();body.name="FixtureTerrain";world.add_child(body)
 var collision:=CollisionShape3D.new();var shape:=mesh.create_trimesh_shape();shape.backface_collision=true;collision.shape=shape;body.add_child(collision)
 preload("res://world/suryagarh/tree_trunk_collision.gd").register_terrain_support(world,body)
