extends Node3D
## Additive street traffic spread along existing surveyed roads.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const Actor = preload("res://characters/npcs/households/household_npc_actor.gd")
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
  var source:="res://characters/npcs/street_residents/%s.glb"%("merchant" if index%2==0 else "landowner")
  actor.add_child(preload("res://characters/human_scene.gd").instantiate(source))
  actor.position=Vector3(at.x,layout.height(at.x,at.y),at.y)
  add_child(actor);actor.add_to_group("city_route_pedestrians")
  actor.set_meta("population_route",record.route);actor.set_meta("human_source",source)
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
  for mesh:GeometryInstance3D in cart.find_children("*","GeometryInstance3D",true,false):
   mesh.visibility_range_end=300;mesh.visibility_range_end_margin=20
