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
class Inquiry:
 extends Node
 var station: Node3D
 var configured:=true
 var stage:="released"
 var destination: Node3D
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
 var police=load("res://world/suryagarh/combat_encounters.gd").new();police.name="CombatEncounters";world.add_child(police)
 var story: Node=script.new();world.add_child(story)
 for i in 120:await physics_frame
 check(story.configured,"mission configured")
 if not story.configured:quit(1);return
 story.set_process(false)
 prior.state="complete";story._process(.1)
 check(story.active and story.cinematic=="days","training completion hands off")
 check(not root.get_node("SaveManager").save_game(world,1),"cinematic save blocked")
 story.update_cinematic(4.1)
 check(story.stage=="ambush" and player.is_physics_processing(),"days fade releases ambush")
 player.global_position=story.sites.tree.global_position+Vector3(0,.9,-1.5);story._process(.1)
 check(story.stage=="confront","tree ambush triggers official walk")
 story.sites.officer.get_node("Vitality").receive_hit(100,player,"sword")
 check(story.stage=="escape" and police.wanted_level>0,"real lethal contact starts wanted chase")
 check(not story.request("bundle0",player),"cannot loot before raid")
 story.set_stage("collect")
 for i in 4:check(story.request("bundle%d"%i,player),"bundle collected %d"%i)
 check(story.stage=="rope" and story.collected.size()==4,"four bundles required")
 check(not story.request("bundle0",player),"duplicate reward prevented")
 var data: Dictionary=story.export_state();story.restore_state(data)
 check(story.stage=="rope" and story.collected.size()==4,"mission restore keeps bundles")
 story.restore_state({"stage":"bad","collected":[-1,0,0,9]})
 check(story.stage=="dormant" and story.collected==[0],"invalid state sanitised")
 print("REBELLION STORY: "+("PASS" if failures.is_empty() else "FAIL "+str(failures)))
 world.queue_free();await process_frame;root.get_node("SaveManager").quit_game(0 if failures.is_empty() else 1)
