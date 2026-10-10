extends Node
## One world-scoped spatial index; mutual conversations and cached traffic awareness.
const CELL_SIZE := 5.0
var members: Array[Node] = []
var cells: Dictionary = {}
var carts: Array[Node3D] = []
var clock: Node
var viewer: Node3D
var age := 0.0
var index_age := 0.0
var traffic_age := 0.0
var conversations_started := 0
var conversations_finished := 0

func _ready() -> void:
 name="PopulationSocial"
 viewer=get_parent().get_node_or_null("Player")
 clock=get_parent().get_node_or_null("GameTimeSystem")

func register(journey:Node) -> void:
 if not members.has(journey):members.append(journey)

func cell(point:Vector3) -> Vector2i:
 return Vector2i(floori(point.x/CELL_SIZE),floori(point.z/CELL_SIZE))

func neighbours(point:Vector3) -> Array[Node]:
 var result:Array[Node]=[]
 var center:=cell(point)
 for x in range(-1,2):
  for z in range(-1,2):
   result.append_array(cells.get(center+Vector2i(x,z),[]))
 return result

func available(journey:Node) -> bool:
 if not is_instance_valid(journey) or not is_instance_valid(journey.actor):return false
 var person:Node3D=journey.actor
 return not journey.paused and not person.get_meta("dead",false) and not person.get_meta("knocked_out",false) and not person.get_meta("grappled",false) and person.get_meta("combat_action","")=="" and not person.get_meta("mission_active",false)

func _process(delta:float) -> void:
 age+=delta;index_age-=delta;traffic_age-=delta
 if traffic_age<=0:
  traffic_age=1.0;carts.clear()
  for cart:Node in get_tree().get_nodes_in_group("live_travel_carts"):
   if get_parent().is_ancestor_of(cart):carts.append(cart)
 if index_age>0:return
 index_age=.25;cells.clear()
 for index in range(members.size()-1,-1,-1):
  var journey:Node=members[index]
  if not is_instance_valid(journey):members.remove_at(index);continue
  if not available(journey):
   end_conversation(journey);continue
  # Distant residents keep their own schedule; no social/traffic frame scans.
  if is_instance_valid(viewer) and journey.actor.global_position.distance_squared_to(viewer.global_position)>40000:continue
  var key:=cell(journey.actor.global_position)
  if not cells.has(key):cells[key]=[]
  cells[key].append(journey)
 for journey:Node in members:
  if not available(journey) or journey.social_partner!=null or age<journey.social_cooldown:continue
  if clock!=null and (clock.current_hour<7 or clock.current_hour>=18):continue
  if is_instance_valid(viewer) and journey.actor.global_position.distance_squared_to(viewer.global_position)>6400:continue
  if journey.closing or journey.detour.is_finite():continue
  # Half continue straight to their destination. Social residents take short breaks.
  if not journey.social_enabled:continue
  if journey.layout.road_distance(journey.actor.global_position.x,journey.actor.global_position.z)<1.05:continue
  for other:Node in neighbours(journey.actor.global_position):
   if other==journey or not available(other) or not other.social_enabled or other.social_partner!=null or age<other.social_cooldown or other.closing:continue
   var distance:float=journey.actor.global_position.distance_to(other.actor.global_position)
   if distance<1.35 or distance>2.2:continue
   if absf(journey.actor.global_position.y-other.actor.global_position.y)>.25:continue
   if other.layout.road_distance(other.actor.global_position.x,other.actor.global_position.z)<1.05:continue
   if not journey.clear_sight(other.actor):continue
   var duration:float=8.0+float(journey.personal_seed%5)
   journey.social_partner=other;other.social_partner=journey
   journey.social_end=age+duration;other.social_end=age+duration
   journey.social_speaker=true;other.social_speaker=false
   conversations_started+=1
   break

func end_conversation(journey:Node) -> void:
 if not is_instance_valid(journey) or journey.social_partner==null:return
 var partner:Node=journey.social_partner
 journey.social_partner=null;journey.social_cooldown=age+35+float(journey.personal_seed%20)
 journey.current_speed=0
 if is_instance_valid(partner):
  partner.social_partner=null;partner.social_cooldown=age+35+float(partner.personal_seed%20);partner.current_speed=0
 conversations_finished+=1

func road_pace(journey:Node,forward:Vector2) -> float:
 var person:Node3D=journey.actor
 var pace:=1.0
 for other:Node in neighbours(person.global_position):
  if other==journey or not available(other):continue
  var offset3:Vector3=other.actor.global_position-person.global_position
  if absf(offset3.y)>.8:continue
  var offset:=Vector2(offset3.x,offset3.z)
  var along:=offset.dot(forward)
  var lateral:=absf(offset.cross(forward))
  if along>0 and along<2.4 and lateral<.72:
   pace=minf(pace,clampf((along-.8)/1.6,.0,1.0))
 for cart:Node3D in carts:
  if not is_instance_valid(cart) or cart.global_position.distance_squared_to(person.global_position)>225:continue
  var local:Vector3=cart.to_local(person.global_position)
  # Give long carts space before the capsule sweep needs to stop the walker.
  if absf(local.x)<2.1 and local.z>-9 and local.z<4 and absf(local.y)<3:
   pace=0;break
 if is_instance_valid(viewer):
  var offset:Vector3=viewer.global_position-person.global_position
  if absf(offset.y)<1.5 and Vector2(offset.x,offset.z).dot(forward)>0 and offset.length()<1.4:pace=0
 return pace
