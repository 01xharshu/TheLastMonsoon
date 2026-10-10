extends Node3D
## Additive street traffic spread along existing surveyed roads.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const Actor = preload("res://characters/npcs/indian/indian_street_actor.gd")
const POPULATION_MULTIPLIER := 2
const ROUTE_COUNTS := {"village_spine":8,"village_market_lane":10,"village_west_lane":6,"civil_lines_avenue":10,"administrative_approach":8,"cantonment_bazaar_lane":10,"government_house_road":6,"town_hall":6,"port_approach":8,"city_market_street":8,"city_front_street":8,"city_courtyard_lane":6}
const POLICE_ROUTES := ["village_spine","village_market_lane","civil_lines_avenue","civil_lines_avenue","administrative_approach","cantonment_bazaar_lane","cantonment_approach","government_house_road","town_hall","port_approach"]
const CART_ROUTES := ["village_west_lane","village_north_lane","government_house_road","civil_lines_avenue","cantonment_bazaar_lane","administrative_approach","port_approach","police_to_compound"]
var layout := Layout.new()
var pending: Array[Dictionary] = []
var pedestrians: Array[Node3D] = []
var carts: Array[Node3D] = []
var patrols: Array[Node3D] = []
var spawn_wait := 0.0
# Keep remote civilian identities/routes as records until approaching their region.
# Instantiated actors remain persistent because combat/quests may acquire them.
var eager_population := false:
 set(value):
  eager_population=value
  if value:ready_population=false
var logical_age := 0.0
var population_clock: Node
var restored_states: Dictionary = {}
const PREPARE_RADIUS_SQUARED := 160000.0
var ready_population := false
var prepared := false
var encounters: Node
var player: Node3D

func _ready() -> void:
 name = "CityRoutePopulation"
 add_to_group("city_route_population")
 prepare.call_deferred()

func prepare() -> void:
 await get_tree().process_frame
 encounters = get_parent().get_node_or_null("CombatEncounters")
 player = get_parent().get_node_or_null("Player")
 for route_name: String in ROUTE_COUNTS:
  for index in int(ROUTE_COUNTS[route_name])*POPULATION_MULTIPLIER:
   pending.append({"kind":"person","route":route_name,"index":index,"count":int(ROUTE_COUNTS[route_name])*POPULATION_MULTIPLIER})
 for index in POLICE_ROUTES.size()*POPULATION_MULTIPLIER:
  pending.append({"kind":"police","route":POLICE_ROUTES[index%POLICE_ROUTES.size()],"index":index,"count":6})
 for index in CART_ROUTES.size()*POPULATION_MULTIPLIER:
  pending.append({"kind":"cart","route":CART_ROUTES[index%CART_ROUTES.size()],"index":index,"count":4})
 # Populate the current neighbourhood first while amortising expensive actor setup.
 if is_instance_valid(player):
  pending.sort_custom(func(a:Dictionary,b:Dictionary)->bool:
   var pa:Vector2=Layout.ROUTES[a.route][0];var pb:Vector2=Layout.ROUTES[b.route][0]
   var here:=Vector2(player.global_position.x,player.global_position.z)
   return pa.distance_squared_to(here)<pb.distance_squared_to(here))

 population_clock=get_parent().get_node_or_null("GameTimeSystem")
 for record in pending:
  if record.kind!="person":continue
  var points:=route_points(record.route,record.index,1.65)
  var phase:=phase_on_route(points,(float(record.index%record.count)+.25)/float(record.count))
  record["points"]=points;record["phase"]=phase
  record["direction"]=1;record["wait"]=0.0
  apply_record_state(record)
 prepared=true
 set_process(true)

func _process(delta: float) -> void:
 if not prepared:return
 logical_age+=delta
 if logical_age>=.5:
  advance_remote(logical_age);logical_age=0
 if pending.is_empty():
  ready_population = true
  set_process(false)
  return
 spawn_wait -= delta
 if spawn_wait > 0: return
 spawn_wait = .06
 var candidate := -1
 var closest := INF
 for i in pending.size():
  var record:Dictionary=pending[i]
  if record.kind!="person" or eager_population or not is_instance_valid(player):
   candidate=i;break
  var at:Vector2=record.phase.point
  var here:=Vector2(player.global_position.x,player.global_position.z)
  var squared:=at.distance_squared_to(here)
  if squared<PREPARE_RADIUS_SQUARED and squared<closest:
   closest=squared;candidate=i
 if candidate<0:return
 var record:Dictionary=pending[candidate]
 pending.remove_at(candidate)
 spawn_record(record)
 # Delivery booking waits for carts/patrols, not invisible logical civilians.
 ready_population=pending.is_empty() if eager_population else pending.all(func(item:Dictionary)->bool:return item.kind=="person")

func route_points(label: String, index: int, lane: float) -> Array[Vector2]:
 var result: Array[Vector2] = []
 var source: Array = Layout.ROUTES[label]
 # Gentle personal lane changes follow the road rather than rigid straight files.
 for i in source.size():
  var direction:Vector2=(source[mini(i+1,source.size()-1)]-source[maxi(0,i-1)]).normalized()
  var personal_lane:float=lane+sin(float(index)*2.399+float(i)*.73)*.23
  result.append(source[i]+Vector2(-direction.y,direction.x)*personal_lane*(-1.0 if index%2==1 else 1.0))
 if index%2==1: result.reverse()
 return result

func phase_on_route(points: Array[Vector2], fraction: float) -> Dictionary:
 var total := 0.0
 for i in points.size()-1: total += points[i].distance_to(points[i+1])
 var distance := total*clampf(fraction,0,.95)
 for i in points.size()-1:
  var length := points[i].distance_to(points[i+1])
  if distance <= length:
   return {"point":points[i].lerp(points[i+1],distance/maxf(length,.001)),"goal":i+1}
  distance -= length
 return {"point":points[0],"goal":1}

func spawn_record(record: Dictionary) -> void:
 var index: int=record.index
 var points: Array[Vector2] = record.get("points",route_points(record.route,index,1.65 if record.kind=="person" else (2.2 if record.kind=="police" else 0.0)))
 var phase: Dictionary = record.get("phase",phase_on_route(points,(float(index%record.count)+.25)/float(record.count)))
 var at:Vector2=phase.point
 if record.kind=="person":
  var actor:=Actor.new()
  actor.name="Street_%s_%02d"%[record.route,index]
  actor.movement_enabled=false;actor.patrol_distance=0;actor.cycle_offset=float(index)*.37
  var route_index: int=ROUTE_COUNTS.keys().find(record.route)
  var identity: int=(index+route_index*3)%8
  var female: bool=identity%2==0
  var work_route:bool=record.route in ["village_spine","village_market_lane","village_west_lane","cantonment_bazaar_lane","port_approach"]
  var source:="res://characters/npcs/street_residents/%s_%02d.glb"%["female" if female else ("workman" if work_route else "male"),identity/2+1]
  actor.movement_profile=&"female" if female else &"male"
  actor.ground_height=layout.height
  var stature: float=[.97,1.02,1.03,.98,1.0,1.05,1.04,1.0][identity]
  actor.scale=Vector3.ONE*stature
  actor.add_child(preload("res://characters/human_scene.gd").instantiate(source))
  actor.position=Vector3(at.x,layout.height(at.x,at.y),at.y)
  add_child(actor);actor.add_to_group("city_route_pedestrians")
  actor.set_meta("population_route",record.route);actor.set_meta("population_index",index);actor.set_meta("human_source",source)
  actor.set_meta("street_identity",identity);actor.set_meta("stature",stature)
  var vocation: String="vendor" if "market" in record.route or "bazaar" in record.route else ("porter" if record.route=="port_approach" else ("clerk" if record.route in ["administrative_approach","government_house_road","town_hall"] else "villager"))
  actor.set_meta("social_role",vocation);actor.set_meta("assigned_workplace",points[-1]);actor.set_meta("daily_activity","travel")
  var journey:=preload("res://world/suryagarh/city_street_journey.gd").new()
  journey.name="CityStreetJourney";journey.configure(actor,points,0);journey.goal=phase.goal;journey.direction=record.get("direction",1);journey.wait=record.get("wait",0.0)
  journey.speed=.88+float(index%5)*.075;journey.viewer=player
  journey.crowd=get_parent().get_node_or_null("PopulationSocial")
  actor.add_child(journey)
  if record.has("saved"):
   var saved:Dictionary=record.saved
   journey.distance_walked=float(saved.get("distance",0));journey.visits=int(saved.get("visits",0))
   actor.set_meta("dead",saved.get("dead",false));actor.set_meta("knocked_out",saved.get("knocked_out",false))
   var vitality:Node=actor.get_node_or_null("Vitality")
   if vitality!=null and saved.has("health"):vitality.health=float(saved.health)
   restore_health.call_deferred(actor,saved)
  pedestrians.append(actor)
  for mesh:GeometryInstance3D in actor.find_children("*","GeometryInstance3D",true,false):
   mesh.visibility_range_end=190;mesh.visibility_range_end_margin=15
 elif record.kind=="police":
  if encounters==null or not encounters.has_method("spawn"):return
  var officer:Node3D=encounters.spawn("CityPatrol_%s_%02d"%[record.route,index],"res://characters/npcs/thana/%s_motion.glb"%("daroga" if index%4==0 else "burkundaz"),Vector3(at.x,layout.height(at.x,at.y),at.y),"police")
  officer.add_to_group("city_route_patrols");officer.set_meta("population_route",record.route)
  var grounded:=PackedVector3Array()
  for point in points:grounded.append(encounters.ground(Vector3(point.x,0,point.y)))
  var marker:=Label3D.new();marker.name="AlertMarker";marker.text="!";marker.position.y=2.05;marker.font_size=48;marker.billboard=BaseMaterial3D.BILLBOARD_ENABLED;marker.visible=false;officer.add_child(marker)
  encounters.patrols.append({"actor":officer,"points":grounded,"index":phase.goal,"step":1,"state":"patrol","sense":float(index%4)*.06,"attack_age":0.0,"hit":false,"marker":marker,"seen":false})
  patrols.append(officer)
  for mesh:GeometryInstance3D in officer.find_children("*","GeometryInstance3D",true,false):
   mesh.visibility_range_end=220;mesh.visibility_range_end_margin=15
 else:
  # Use the longest straight road section; avoid carriage U-turns inside alleys.
  var best:=0
  for i in points.size()-1:
   if points[i].distance_to(points[i+1])>points[best].distance_to(points[best+1]):best=i
  var a:=points[best];var b:=points[best+1]
  var unit:Vector2=(b-a).normalized();a+=unit*9;b-=unit*9
  at=a.lerp(b,.20+float(index/ CART_ROUTES.size())*.42)
  var cart:Node3D=preload("res://vehicles/bullock_cart.gd").new() if index%2==0 else preload("res://vehicles/family_carriage_candidate.gd").new()
  cart.name="CityCart_%s_%02d"%[record.route,index];cart.position=Vector3(at.x,layout.height(at.x,at.y),at.y);cart.rotation.y=atan2(-unit.x,-unit.y)
  add_child(cart);cart.add_to_group("live_travel_carts");cart.add_to_group("city_route_carts");cart.set_meta("booking_status","public");cart.set_meta("population_route",record.route)
  var journey:=preload("res://world/suryagarh/city_cart_journey.gd").new();journey.name="CityRoadJourney";journey.configure(cart);journey.viewer=player;journey.route=[a,b];cart.add_child(journey)
  carts.append(cart)
  if index%CART_ROUTES.size() in [0,1,3,6]:_passenger.call_deferred(cart,index)
  for mesh:GeometryInstance3D in cart.find_children("*","GeometryInstance3D",true,false):
   mesh.visibility_range_end=300;mesh.visibility_range_end_margin=20

func _passenger(cart:Node3D,index:int)->void:
 var socket:Node3D
 if cart.has_method("show_coachman_blockout"):
  socket=cart.seat_sockets.RearPassengerLeft
  cart.set_meta("npc_occupied_seats",["RearPassengerLeft"])
 else:
  socket=Node3D.new();socket.name="VillagePassengerSeat";socket.position=Vector3(0,1.50,2.95);cart.visual_root.add_child(socket)
  var bench:=MeshInstance3D.new();bench.name="VillagePassengerBench";var box:=BoxMesh.new();box.size=Vector3(1.2,.13,.45);bench.mesh=box
  bench.position=Vector3(0,1.425,2.95);var wood:=StandardMaterial3D.new();wood.albedo_color=Color(.25,.16,.09);bench.material_override=wood;cart.visual_root.add_child(bench)
  for node in cart.visual_root.get_children():
   if str(node.get_meta("part_label",node.name)).begins_with("ProduceBundle"):node.hide()
 var actor:=Actor.new();actor.name="VillageCartPassenger";actor.movement_enabled=false;actor.household_job="Traveller"
 actor.add_child(preload("res://characters/human_scene.gd").instantiate("res://characters/npcs/street_residents/male_%02d.glb"%(index%4+1),false))
 cart.visual_root.add_child(actor)
 var journey:=preload("res://world/suryagarh/city_cart_passenger.gd").new();journey.name="VillagePassengerJourney";journey.cart=cart;journey.actor=actor;journey.socket=socket;journey.viewer=player;actor.add_child(journey)

func advance_remote(delta: float) -> void:
 # Logical walkers preserve identity, route, endpoint pauses and night return.
 # No physics/rig is allocated until 400 m, beyond the 190 m visual range.
 for record in pending:
  if record.kind!="person":continue
  if record.has("saved") and (record.saved.get("dead",false) or record.saved.get("knocked_out",false)):continue
  var points:Array[Vector2]=record.points
  var phase:Dictionary=record.phase
  var night:bool=is_instance_valid(population_clock) and (population_clock.current_hour<6 or population_clock.current_hour>=18)
  if night and int(record.direction)>0:
   record.direction=-1;phase.goal=maxi(0,int(phase.goal)-1);record.wait=0.0
  if night and int(phase.goal)==0 and phase.point.distance_squared_to(points[0])<.001:continue
  if float(record.wait)>0:
   record.wait=maxf(0,float(record.wait)-delta);continue
  var target:Vector2=points[int(phase.goal)]
  var offset:Vector2=target-phase.point
  var pace:float=.88+float(int(record.index)%5)*.075
  phase.point=phase.point+offset.normalized()*minf(offset.length(),pace*delta)
  if phase.point.distance_squared_to(target)<.001:
   if int(phase.goal)==points.size()-1 or int(phase.goal)==0:
    if night and int(phase.goal)==0:continue
    record.direction=-int(record.direction);record.wait=6.0
   phase.goal=int(phase.goal)+int(record.direction)

func record_key(record: Dictionary) -> String:
 return "%s:%d"%[record.route,int(record.index)]

func export_route_state() -> Dictionary:
 var result:Dictionary={}
 for record in pending:
  if record.kind!="person" or not record.has("phase"):continue
  var at:Vector2=record.phase.point
  var state:Dictionary=record.get("saved",{}).duplicate()
  state.merge({"point":[at.x,at.y],"goal":record.phase.goal,"direction":record.direction,"wait":record.wait},true)
  result[record_key(record)]=state
 for actor in pedestrians:
  if not is_instance_valid(actor):continue
  var journey:Node=actor.get_node("CityStreetJourney")
  var at:=actor.global_position
  var state:Dictionary={"point":[at.x,at.z],"goal":journey.goal,"direction":journey.direction,"wait":journey.wait,"distance":journey.distance_walked,"visits":journey.visits,"dead":actor.get_meta("dead",false),"knocked_out":actor.get_meta("knocked_out",false)}
  var vitality:Node=actor.get_node_or_null("Vitality")
  if vitality!=null:state["health"]=vitality.health
  result["%s:%d"%[actor.get_meta("population_route"),actor.get_meta("population_index")]]=state
 return result

func apply_record_state(record: Dictionary) -> void:
 var saved:Dictionary=restored_states.get(record_key(record),{})
 if saved.is_empty() or not saved.get("point") is Array or saved.point.size()!=2:return
 record.phase.point=Vector2(float(saved.point[0]),float(saved.point[1]))
 record.phase.goal=clampi(int(saved.get("goal",1)),0,record.points.size()-1)
 record.direction=1 if int(saved.get("direction",1))>0 else -1
 record.wait=maxf(0,float(saved.get("wait",0)))
 record["saved"]=saved

func restore_route_state(states: Dictionary) -> void:
 restored_states=states.duplicate(true)
 for record in pending:
  if record.kind=="person" and record.has("phase"):apply_record_state(record)
 for actor in pedestrians:
  var key:="%s:%d"%[actor.get_meta("population_route"),actor.get_meta("population_index")]
  var saved:Dictionary=states.get(key,{})
  if saved.is_empty() or not saved.get("point") is Array or saved.point.size()!=2:continue
  var at:=Vector2(float(saved.point[0]),float(saved.point[1]))
  actor.global_position=Vector3(at.x,layout.height(at.x,at.y),at.y)
  var journey:Node=actor.get_node("CityStreetJourney")
  journey.goal=clampi(int(saved.get("goal",1)),0,journey.route.size()-1)
  journey.direction=1 if int(saved.get("direction",1))>0 else -1
  journey.wait=maxf(0,float(saved.get("wait",0)))
  journey.distance_walked=float(saved.get("distance",0));journey.visits=int(saved.get("visits",0))
  actor.set_meta("dead",saved.get("dead",false));actor.set_meta("knocked_out",saved.get("knocked_out",false))
  var vitality:Node=actor.get_node_or_null("Vitality")
  if vitality!=null and saved.has("health"):vitality.health=float(saved.health)
  restore_health.call_deferred(actor,saved)
  actor.get_node("BodyCollider").force_update_transform()

func restore_health(actor: Node3D, saved: Dictionary) -> void:
 if not is_instance_valid(actor):return
 var vitality:Node=actor.get_node_or_null("Vitality")
 if vitality!=null and saved.has("health"):vitality.health=float(saved.health)
 if vitality!=null:vitality.dead=bool(saved.get("dead",false))
 if saved.get("dead",false) or saved.get("knocked_out",false):
  actor.get_node("BodyCollider/BodyShape").set_deferred("disabled",true)
  actor.combat_react("down")
