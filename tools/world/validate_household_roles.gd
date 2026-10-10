extends SceneTree
class MapFixture extends Node:
 var waypoint:=Vector2(INF,INF)
 var selected_site:=""
 var follow_story:=true

class StoryFixture extends Node:
 var stage:="police"
 var active:=false
 var state:="awaiting_inquiry"
func _initialize() -> void:call_deferred("_run")
func _run() -> void:
 var world:=Node3D.new();root.add_child(world);current_scene=world
 var player:=CharacterBody3D.new();player.name="Player"
 # Reuse an existing complete MPFB export for this isolated player fixture.
 player.add_child(load("res://characters/npcs/households/merchant.glb").instantiate())
 var inv:Node=load("res://player/inventory_component.gd").new();inv.name="InventoryComponent";player.add_child(inv)
 var fame:Node=load("res://player/fame_component.gd").new();fame.name="FameComponent";player.add_child(fame);world.add_child(player)
 var clock:Node=load("res://world/suryagarh/systems/game_time_system.gd").new();world.add_child(clock);clock.current_hour=10;clock.current_day=1
 var ledger:Node=load("res://world/suryagarh/settlements/household_world_roles.gd").new();ledger.player=player;ledger.world=world;ledger.clock=clock;world.add_child(ledger)
 var resident:Node3D=load("res://characters/npcs/households/merchant.glb").instantiate();world.add_child(resident)
 var merchant:Node=ledger.bind(resident,"merchant","merchant_home")
 var host:Node=ledger.bind(resident,"host","british_home")
 var official:Node=ledger.bind(resident,"official","british_home")
 var water:Node=ledger.bind(resident,"water","british_home")
 var cook:Node=ledger.bind(resident,"cook","british_home")
 var lord:Node=ledger.bind(resident,"landowner","landowner_home")
 for index in 3:
  var plot:=Node3D.new();plot.name="CultivatedPlot"+str(index);plot.position=Vector3(index*4,0,0);world.add_child(plot);plot.add_to_group("bhairavpur_garden")
 inv.items={"mango":4,"roti":3,"rupees":0,"water_bag":1}
 for sale in 4:ledger.request(merchant,player)
 assert(inv.get_item_count("mango")==1 and inv.get_item_count("rupees")==6,"merchant daily quota")
 ledger.request(host,player);ledger.request(host,player)
 assert(inv.get_item_count("roti")==1 and fame.points==4,"host payment/help repeats")
 ledger.request(official,player)
 assert(not ledger.state[official.role_id].get("reviewed",false),"missing receipt accepted")
 inv.items.revenue_receipt=1;ledger.request(official,player)
 var balance:int=inv.get_item_count("rupees");ledger.request(official,player)
 assert(inv.get_item_count("rupees")==balance and inv.get_item_count("revenue_receipt")==1,"paperwork replay/consumption")
 for fill in 6:ledger.request(water,player)
 assert(is_equal_approx(inv.stored_water_liters,2.0),"water allowance/capacity")
 ledger.request(cook,player)
 assert(inv.get_item_count("roti")==2,"cook pantry meal")
 ledger.request(lord,player)
 assert(ledger.survey_active and ledger.fields.size()==3,"estate survey not offered")
 var map:=MapFixture.new();root.add_child(map);ledger.navigation_map=map
 map.waypoint=Vector2(20,30);ledger.mark_survey(true)
 assert(map.waypoint==Vector2(20,30),"survey replaced manual destination")
 map.waypoint=Vector2(INF,INF)
 for priority in ["opening_active","morning_tutorial_active"]:
  player.set_meta(priority,true);ledger.mark_survey(true)
  assert(not map.waypoint.is_finite(),"survey replaced onboarding guidance")
  player.set_meta(priority,false)
 var inquiry:=StoryFixture.new();root.add_child(inquiry);ledger.navigation_inquiry=inquiry
 ledger.mark_survey(true)
 assert(not map.waypoint.is_finite(),"survey replaced tracked inquiry")
 map.follow_story=false;ledger.mark_survey()
 assert(map.waypoint.is_finite(),"survey could not resume after player stopped story tracking")
 ledger.navigation_inquiry=null;map.follow_story=true
 ledger.mark_survey()
 assert(map.waypoint.is_finite(),"survey failed to resume after guidance cleared")
 # Actual field interactions require range; distant calls cannot finish a job.
 player.position=Vector3(100,0,100);ledger.fields[0].interact(player)
 assert(ledger.survey_checked.is_empty(),"distant field check accepted")
 for marker in ledger.fields:
  player.global_position=marker.global_position;marker.interact(player);marker.interact(player)
 assert(ledger.survey_checked.size()==3,"field progress/replay")
 balance=inv.get_item_count("rupees");ledger.request(lord,player);ledger.request(lord,player)
 assert(inv.get_item_count("rupees")==balance+5,"estate repeat reward")
 var saved:Dictionary=JSON.parse_string(JSON.stringify(ledger.export_state()));ledger.restore_state(saved)
 assert(ledger.survey_checked.size()==3,"JSON save discarded field indices")
 ledger.request(merchant,player);assert(inv.get_item_count("mango")==1,"save reset daily trade")
 clock.current_day=2;ledger.request(merchant,player)
 assert(inv.get_item_count("mango")==0,"next-day trade did not unlock")
 resident.set_meta("dead",true);assert(not merchant.interaction_available(),"dead resident serves player")
 ledger.survey_active=true;ledger.survey_checked.clear()
 assert(not ledger.fields[0].interaction_available(),"dead landowner still commissions field checks")
 ledger._process(.1);assert(not ledger.survey_active,"orphan survey stays active")
 resident.set_meta("dead",false);resident.set_meta("household_action","climb_step");assert(not merchant.interaction_available(),"boarding resident serves player")
 resident.set_meta("household_action","work");assert(merchant.interaction_available(),"office role unavailable")
 print("HOUSEHOLD_ROLES PASS: quotas, food stock, paperwork, water, survey range/replay, save state, day rollover, death and travel guards")
 quit()
