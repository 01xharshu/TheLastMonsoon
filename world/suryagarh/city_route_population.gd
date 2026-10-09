extends Node3D
## Additive street traffic spread along existing surveyed roads.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const Actor = preload("res://characters/npcs/indian/indian_street_actor.gd")
const ROUTE_COUNTS := {"village_spine":8,"village_market_lane":10,"village_west_lane":6,"civil_lines_avenue":10,"administrative_approach":8,"cantonment_bazaar_lane":10,"government_house_road":6,"town_hall":6,"port_approach":8}
const POLICE_ROUTES := ["village_spine","village_market_lane","civil_lines_avenue","civil_lines_avenue","administrative_approach","cantonment_bazaar_lane","cantonment_approach","government_house_road","town_hall","port_approach"]
const CART_ROUTES := ["village_west_lane","village_north_lane","government_house_road","civil_lines_avenue","cantonment_bazaar_lane","administrative_approach","port_approach","police_to_compound"]
var layout := Layout.new()
var pending: Array[Dictionary] = []
var pedestrians: Array[Node3D] = []
var carts: Array[Node3D] = []
var patrols: Array[Node3D] = []
var spawn_wait := 0.0
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
  for index in int(ROUTE_COUNTS[route_name]):
   pending.append({"kind":"person","route":route_name,"index":index,"count":int(ROUTE_COUNTS[route_name])})
 for index in POLICE_ROUTES.size():
  pending.append({"kind":"police","route":POLICE_ROUTES[index],"index":index,"count":3})
 for index in CART_ROUTES.size():
  pending.append({"kind":"cart","route":CART_ROUTES[index],"index":index,"count":2})
 # Populate the current neighbourhood first while amortising expensive actor setup.
 if is_instance_valid(player):
  pending.sort_custom(func(a:Dictionary,b:Dictionary)->bool:
   var pa:Vector2=Layout.ROUTES[a.route][0];var pb:Vector2=Layout.ROUTES[b.route][0]
   var here:=Vector2(player.global_position.x,player.global_position.z)
   return pa.distance_squared_to(here)<pb.distance_squared_to(here))

 prepared=true
 set_process(true)

func _process(delta: float) -> void:
 if not prepared:return
 if pending.is_empty():
  ready_population = true
  set_process(false)
  return
 spawn_wait -= delta
 if spawn_wait > 0: return
 spawn_wait = .06
 spawn_record(pending.pop_front())

func route_points(label: String, index: int, lane: float) -> Array[Vector2]:
 var result: Array[Vector2] = []
 var source: Array = Layout.ROUTES[label]
 for i in source.size():
  var direction:Vector2=(source[mini(i+1,source.size()-1)]-source[maxi(0,i-1)]).normalized()
  result.append(source[i]+Vector2(-direction.y,direction.x)*lane*(-1.0 if index%2==1 else 1.0))
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
 var points := route_points(record.route,index,1.65 if record.kind=="person" else (2.2 if record.kind=="police" else 0.0))
 var phase := phase_on_route(points,(float(index%record.count)+.25)/float(record.count))
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
  actor.set_meta("population_route",record.route);actor.set_meta("human_source",source)
  actor.set_meta("street_identity",identity);actor.set_meta("stature",stature)
  var vocation: String="vendor" if "market" in record.route or "bazaar" in record.route else ("porter" if record.route=="port_approach" else ("clerk" if record.route in ["administrative_approach","government_house_road","town_hall"] else "villager"))
  actor.set_meta("social_role",vocation);actor.set_meta("assigned_workplace",points[-1]);actor.set_meta("daily_activity","travel")
  var journey:=preload("res://world/suryagarh/city_street_journey.gd").new()
  journey.name="CityStreetJourney";journey.configure(actor,points,0);journey.goal=phase.goal
  journey.speed=.78+float(index%4)*.08;journey.viewer=player;actor.add_child(journey)
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
  at=a.lerp(b,.25 if index%2==0 else .65)
  var cart:Node3D=preload("res://vehicles/bullock_cart.gd").new() if index%2==0 else preload("res://vehicles/family_carriage_candidate.gd").new()
  cart.name="CityCart_%s"%record.route;cart.position=Vector3(at.x,layout.height(at.x,at.y),at.y);cart.rotation.y=atan2(-unit.x,-unit.y)
  add_child(cart);cart.add_to_group("live_travel_carts");cart.add_to_group("city_route_carts");cart.set_meta("booking_status","public");cart.set_meta("population_route",record.route)
  var journey:=preload("res://world/suryagarh/city_cart_journey.gd").new();journey.name="CityRoadJourney";journey.configure(cart);journey.route=[a,b];cart.add_child(journey)
  carts.append(cart)
  if index in [0,1,3,6]:_passenger.call_deferred(cart,index)
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
