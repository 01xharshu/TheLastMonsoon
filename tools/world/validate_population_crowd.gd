extends SceneTree
## Production MPFB rigs, real capsule physics, mutual talk and obstacle/yield recovery.
const Actor=preload("res://characters/npcs/indian/indian_street_actor.gd")
const Journey=preload("res://world/suryagarh/city_street_journey.gd")
const Crowd=preload("res://world/suryagarh/population_social.gd")
class Clock extends Node:
 var current_hour:=10
class FlatLayout extends "res://world/suryagarh/landscape_layout.gd":
 func height(_x:float,_z:float) -> float:return 0.0
 func road_distance(_x:float,_z:float) -> float:return 1.8
var errors:Array[String]=[]
var world:Node3D
var crowd:Node
var viewer:Node3D
var journeys:Array[Node]=[]
func _initialize() -> void:run.call_deferred()
func check(ok:bool,message:String) -> void:
 if not ok:errors.append(message)
func person(label:String,at:Vector3,points:Array[Vector2],identity:int) -> Node:
 var actor:=Actor.new();actor.name=label;actor.movement_enabled=false;actor.position=at
 actor.set_meta("street_identity",identity);actor.set_meta("population_index",identity)
 actor.add_child(preload("res://characters/human_scene.gd").instantiate("res://characters/npcs/street_residents/male_01.glb",false));world.add_child(actor)
 var journey:=Journey.new();journey.name="CityStreetJourney";journey.configure(actor,points,0);journey.layout=FlatLayout.new();journey.viewer=viewer;journey.crowd=crowd;journey.speed=1.1;actor.add_child(journey)
 journeys.append(journey);return journey
func wall(at:Vector3,size:Vector3) -> StaticBody3D:
 var body:=StaticBody3D.new();body.position=at;world.add_child(body)
 var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size;shape.shape=box;body.add_child(shape);return body
func run() -> void:
 world=Node3D.new();root.add_child(world)
 var clock:=Clock.new();clock.name="GameTimeSystem";world.add_child(clock)
 viewer=Node3D.new();viewer.name="Player";viewer.position=Vector3(10,0,8);world.add_child(viewer)
 var floor:=wall(Vector3(0,-.1,0),Vector3(100,.2,100));floor.name="GroundCollision"
 crowd=Crowd.new();world.add_child(crowd)
 await physics_frame
 var first:=person("First",Vector3(-.8,0,0),[Vector2(-10,0),Vector2(10,0)],0)
 var second:=person("Second",Vector3(.8,0,0),[Vector2(10,0),Vector2(-10,0)],4)
 first.social_enabled=true;second.social_enabled=true
 first.social_cooldown=0;second.social_cooldown=0
 # Hold destinations only until the real coordinator negotiates the pair.
 first.set_physics_process(false);second.set_physics_process(false)
 await create_timer(.4).timeout
 check(first.social_partner==second and second.social_partner==first,"Mutual conversation failed")
 first.set_physics_process(true);second.set_physics_process(true)
 await create_timer(1.0).timeout
 check(first.actor.get_meta("street_action","") in ["talking","listening"],"Talk/listen state missing")
 check(first.actor.global_position.distance_to(second.actor.global_position)>1.3,"Conversation bodies overlap")
 first.actor.set_meta("mission_active",true)
 await create_timer(.4).timeout
 check(first.social_partner==null and second.social_partner==null,"Mission did not release both conversation participants")
 first.actor.set_meta("mission_active",false)
 first.social_enabled=false;second.social_enabled=false
 var before:float=first.distance_walked
 await create_timer(5).timeout
 check(first.distance_walked>before+1,"Conversation did not resume destination walking")
 var obstacle:=wall(Vector3(0,1,12),Vector3(.05,2,2))
 await physics_frame
 var walker:=person("ObstacleWalker",Vector3(-3,0,12),[Vector2(-3,12),Vector2(6,12)],2)
 walker.social_enabled=false
 await create_timer(10).timeout
 check(walker.detours>0 and walker.actor.global_position.x>1,"Walker did not pass a thin wall with a swept detour")
 # A cached cart ahead requires yielding; removal releases the destination.
 var cart:=Node3D.new();world.add_child(cart);cart.position=Vector3(20,0,4);cart.add_to_group("live_travel_carts")
 var yielding:=person("TrafficWalker",Vector3(20,0,0),[Vector2(20,0),Vector2(20,10)],3)
 yielding.social_enabled=false
 await create_timer(.8).timeout
 check(yielding.actor.get_meta("street_action","")=="yielding_to_traffic","Cart look-ahead did not yield")
 cart.queue_free();await create_timer(4).timeout
 check(yielding.distance_walked>1,"Walker failed to resume after cart cleared")
 # Real ground loss cannot be stepped over even at remote cadence.
 viewer.position=Vector3(1000,0,1000)
 var old:float=walker.distance_walked
 await create_timer(1).timeout
 check(walker.distance_walked>=old,"Remote cadence reset walking state")
 viewer.global_position=walker.actor.global_position+Vector3(1,0,2)
 for frame in 3:await physics_frame
 check(walker.simulation_interval==0,"Approach failed to wake full cadence")
 print("CROWD RESULT ",JSON.stringify({"passed":errors.is_empty(),"conversations":crowd.conversations_started,"released":crowd.conversations_finished,"detours":walker.detours,"walker":{"at":str(walker.actor.global_position),"distance":walker.distance_walked,"blocked":walker.last_obstacle,"frames":walker.blocked_frames,"action":walker.actor.get_meta("street_action",""),"combat":walker.actor.get_meta("combat_action",""),"interval":walker.simulation_interval,"detour":str(walker.detour)},"errors":errors}))
 world.queue_free();await process_frame
 root.get_node("SaveManager").quit_game(0 if errors.is_empty() else 1)
