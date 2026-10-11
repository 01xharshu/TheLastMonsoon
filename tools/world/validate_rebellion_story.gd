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
 story.follow_index=0
 story.set_process(false)
 prior.state="complete"
 var occupied_domains: Array[StringName]=[&"move"]
 var conflict=story.action_service.acquire(prior,occupied_domains)
 story._process(.1);check(not story.active and story.stage=="dormant","cinematic waits for an existing action lease")
 story.action_service.release(conflict);story._process(.1)
 check(story.active and story.cinematic=="days","training completion hands off")
 check(not root.get_node("SaveManager").save_game(world,1),"cinematic save blocked")
 story.update_cinematic(4.1)
 check(story.stage=="ambush" and player.is_physics_processing(),"days fade releases ambush")
 player.global_position=story.sites.tree.global_position+Vector3(0,.9,-1.5);story._process(.1)
 check(story.stage=="confront","tree ambush triggers official walk")
 story.sites.officer.get_node("Vitality").receive_hit(100,player,"sword")
 check(story.stage=="escape" and police.wanted_level>0,"real lethal contact starts wanted chase")
 check(not story.request("bundle0",player),"cannot loot before raid")
 police.complete_custody(player)
 story.set_stage("infiltrate")
 var guard: Node3D=story.sites.guards[0]
 guard.travel_speed=0;player.global_position=guard.global_position-guard.global_basis.z*.65+Vector3.UP*.9
 var grapple: Node=player.get_node("RearGrapple")
 check(story.rear_target()==guard,"Q rear eligibility")
 check(grapple.begin(),"real paired rear takedown begins")
 for i in 100:await physics_frame
 check(guard.get_meta("dead",false) and not grapple.active,"mission takedown is lethal and releases controls")
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
 for i in 4:check(story.request("bundle%d"%i,player),"bundle collected %d"%i)
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
 # Rescue must use the real horse and carriage boarding contract.
 story.sites.set_enabled(true);story.set_stage("escape");story.sites.horse.global_position=story.ground(fort.to_global(Vector3(0,0,95)))
 story.sites.b.piece(world,"FixtureHorseSupport",story.sites.horse.global_position-Vector3.UP*.15,Vector3(100,.2,100),story.sites.b.stone)
 player.global_position=story.sites.horse.global_position+Vector3(1,.9,0)
 check(story.sites.horse.board(player),"superior horse boards")
 for i in 100:await physics_frame
 story._process(.01)
 check(story.active and story.cinematic=="rescue","approaching fort on horse begins rescue")
 for i in 161:
  story.update_cinematic(.1);await physics_frame
  if i==75 and OS.get_environment("TLM_REBELLION_NATIVE")=="1":await capture("rescue",temporary)
 check(story.active and story.cinematic=="arrival","rescue transitions to fort arrival")
 for i in 75:
  story.update_cinematic(.1);await physics_frame
 check(story.stage=="follow" and (player.get_meta("mounted_vehicle") if player.has_meta("mounted_vehicle") else null)==null,"fort arrival releases follow gameplay")
 # Traverse the terrace and descending passage with normal controller physics.
 var approach: Vector3=story.ground(story.sites.cellar.to_global(Vector3(0,0,34)))
 story.sites.b.piece(world,"FixtureCellarGround",approach+Vector3(0,-.1,2),Vector3(12,.2,6),story.sites.b.stone)
 for goal in [Vector3(0,4.6,24),Vector3(0,4.6,18),Vector3(0,1.1,7),Vector3(0,1.1,3)]:
  await walk(player,story.sites.cellar.to_global(goal),420)
  print("UNDERCROFT ROUTE ",goal," -> ",story.sites.cellar.to_local(player.global_position))
 check(absf(player.global_position.y-story.sites.cellar.global_position.y-1.1)<.4,"controller descends into undercroft")
 story.set_stage("inspect");check(story.request("weapons",player),"weapons introduction grants usable rifle and cartridges")
 var gear: Node=hero.equipment;gear.select_weapon(1);gear.stowed=false;gear._refresh()
 player.global_position=story.sites.cellar.to_global(Vector3(0,1.1,3));player.velocity=Vector3.ZERO
 for i in 20:await physics_frame
 var gun: Node=player.get_node("RifleCombat")
 gun.start_reload();check(gun.reload_remaining>0,"real cartridge reload starts")
 story._process(.01)
 for i in 120:await physics_frame
 story._process(.01);check(story.stage=="shoot","reload completes first firearm lesson")
 for shot in 2:
  player.get_node("CameraPivot/SpringArm3D/Camera3D").look_at(story.sites.target.global_position)
  gun.aiming=true;gun.fire();story._process(.01)
  if shot==0:
   check(story.stage=="shoot","one target hit cannot finish two-hit lesson")
   gun.start_reload()
   for i in 120:await physics_frame
 print("RIFLE LESSON hits=",story.target_hits," shots=",gun.shots_fired," stage=",story.stage)
 check(story.target_hits==2 and story.stage=="raid_ready","two real target contacts complete firearm lesson")
 var saves: Node=root.get_node("SaveManager")
 police.complete_custody(player);story.set_stage("collect");story.collected.assign([0,1])
 check(saves.save_game(world,1),"SaveManager saves partial rifle collection")
 story.stage="raid_ready";story.collected.clear();saves.pending_slot=1;saves.apply_pending(world)
 for i in 3:await physics_frame
 check(story.stage=="collect" and story.collected==[0,1],"SaveManager restores exact collection checkpoint")
 for i in [2,3]:check(story.request("bundle%d"%i,player),"remaining saved bundles collected")
 check(story.request("rope",player),"saved collection unlocks rope")
 story.update_cinematic(18.1)
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
 story.update_cinematic(7.1)
 check(story.stage=="complete" and story.captured_rifles==12 and not story.sites.return_bay.visible,"delivery records twelve rifles and retires rectangle")
 var reward_count: int=player.inventory.get_item_count("paper_cartridges");story._process(1)
 check(player.inventory.get_item_count("paper_cartridges")==reward_count,"delivery reward cannot repeat")
 check(saves.save_game(world,2),"completed continuation saves")
 saves.pending_slot=2;saves.apply_pending(world)
 check(story.stage=="complete" and story.captured_rifles==12,"completed continuation restores without reward replay")


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
