extends "res://world/suryagarh/city_route_population.gd"
## One independent resident per non-city human, using the original complete MPFB export.
## Original story/service owners stay unique. Counterparts are regional colleagues.
const Human = preload("res://characters/human_scene.gd")
const HouseholdActor = preload("res://characters/npcs/households/household_npc_actor.gd")
var originals: Dictionary = {}
var inactive_states:Dictionary={}
var source_keys:Dictionary={}
var unresolved: Dictionary = {}
var discovery: Array[Node] = []
var discovery_age := 0.0
var discovered_count := 0
var materialized_count := 0
var census_finished := false
var census_age := 0.0

func _ready() -> void:
 name="PopulationExpansion"
 add_to_group("population_expansion")
 prepare.call_deferred()

func prepare() -> void:
 await get_tree().process_frame
 player=get_parent().get_node_or_null("Player")
 encounters=get_parent().get_node_or_null("CombatEncounters")
 population_clock=get_parent().get_node_or_null("GameTimeSystem")
 # Observe late village, story, roadside and lazy fort actors without rescanning the world.
 get_tree().node_added.connect(_node_added)
 for skeleton:Node in get_parent().find_children("*","Skeleton3D",true,false):discovery.append(skeleton)
 prepared=true

func _node_added(node:Node) -> void:
 if node is Skeleton3D:discovery.append(node)

func _process(delta:float) -> void:
 census_age+=delta
 # Amortise source discovery and spawning independently; no per-frame global searches.
 var started:=Time.get_ticks_usec()
 var inspected:=0
 while not discovery.is_empty() and inspected<8 and Time.get_ticks_usec()-started<2000:
  var candidate:Variant=discovery.pop_front()
  if is_instance_valid(candidate) and candidate.is_inside_tree():discover(candidate as Node)
  inspected+=1
 census_finished=discovery.is_empty() and census_age>4
 super._process(delta)
 # The base manager stops when its queue is empty. Keep listening for late additions.
 set_process(true)

func discover(skeleton:Node) -> void:
 var world:=get_parent()
 if not world.is_ancestor_of(skeleton) or is_ancestor_of(skeleton) or (is_instance_valid(player) and player.is_ancestor_of(skeleton)):return
 var branch:Node=skeleton
 while branch!=world:
  if branch.is_in_group("city_route_population") or branch.is_in_group("population_expansion"):return
  branch=branch.get_parent()
 var figure:Node=skeleton
 while figure!=world and not (figure.scene_file_path.begins_with("res://characters/npcs/") and figure.scene_file_path.ends_with(".glb")):
  figure=figure.get_parent()
 if figure==world:return
 var original:=figure.get_parent() as Node3D
 if original==null:return
 if original.get_meta("population_expansion_exempt",false):return
 # City officers live under CombatEncounters, not the city manager. That cohort
 # already doubled its records; discovering it here would double it a second time.
 if original.is_in_group("city_route_patrols") or original.is_in_group("city_route_pedestrians"):return
 var key:=str(world.get_path_to(original))
 if originals.has(key):return
 # Reuse existing ranges; add the standard human range only where none existed.
 for mesh:GeometryInstance3D in figure.find_children("*","GeometryInstance3D",true,false):
  if mesh.visibility_range_end==0:
   mesh.visibility_range_end=190;mesh.visibility_range_end_margin=15
 var source:=figure.scene_file_path
 if not ResourceLoader.exists(source):unresolved[key]="missing MPFB source";return
 var origin:=Vector2(original.global_position.x,original.global_position.z)
 var faction:String=str(original.get_meta("combat_faction","british" if "/british/" in source else "indian"))
 var index:=posmod(key.hash(),2147483647)
 var label:=distributed_route(origin,index,faction in ["police","british"] or original.is_in_group("thana_officers"))
 if label.is_empty():unresolved[key]="no surveyed road in this region";return
 originals[key]=source;discovered_count+=1
 original.tree_exiting.connect(func():remove_colleague(key),CONNECT_ONE_SHOT)
 var points:=route_points(label,index,1.7)
 # Keep the regional road, but spread colleagues over its full length.
 # Projecting every station/service source to its nearest road produced a crowd at one gate.
 var phase:=phase_on_route(points,fposmod(float(index)*.61803398875,1.0))
 var profile:String="female" if "woman" in source or "/female_" in source else "male"
 var record:Dictionary={"kind":"person","route":label,"index":index,"count":1,"points":points,"phase":phase,"direction":1,"wait":0.0,"source":source,"source_id":key,"profile":profile,"faction":faction,"role":str(original.get_meta("social_role",original.name)),"police":original.is_in_group("thana_officers") or faction=="police"}
 source_keys[key]=record_key(record)
 inactive_states.erase(record_key(record))
 apply_record_state(record)
 pending.append(record)
 ready_population=false

func nearest_route(point:Vector2, avoid_hideout:bool=false) -> String:
 var best:=INF
 var label:=""
 for route_name:String in Layout.ROUTES:
  # Only story actors and the player use the abandoned fort approaches.
  if route_name in ["fort_trail","fort_access"]:continue
  # Colleagues use public streets; reserved coach drives stay clear.
  if route_name in ["consignment_wilderness","port_village_road","port_approach","village_estate_approach","merchant_city_drive","collector_bungalow_drive","officer_bungalow_drive","government_house_avenue","compound_court","compound_stores"]:continue
  var points:Array=Layout.ROUTES[route_name]
  if avoid_hideout and (not preload("res://world/suryagarh/settlement_police_routes.gd").allows_route(route_name) or route_near_hideout(points)):continue
  for index in points.size()-1:
   var on_road:=Geometry2D.get_closest_point_to_segment(point,points[index],points[index+1])
   var distance:=point.distance_squared_to(on_road)
   if distance<best:best=distance;label=route_name
 return label


# Select a stable nearby public route per identity rather than putting every
# colleague from the same institution on the same nearest road. Restrict the
# choice to the local area and retain the existing authority exclusions.
func distributed_route(point:Vector2,identity:int,avoid_hideout:bool=false) -> String:
 var nearest:=nearest_route(point,avoid_hideout)
 if nearest.is_empty():return nearest
 var distances:Dictionary={}
 var nearest_distance:=INF
 for label:String in Layout.ROUTES:
  if label in ["fort_trail","fort_access","consignment_wilderness","port_village_road","port_approach","village_estate_approach","merchant_city_drive","collector_bungalow_drive","officer_bungalow_drive","government_house_avenue","compound_court","compound_stores"]:continue
  var points:Array=Layout.ROUTES[label]
  if avoid_hideout and (not preload("res://world/suryagarh/settlement_police_routes.gd").allows_route(label) or route_near_hideout(points)):continue
  var distance:=INF
  for i in points.size()-1:
   distance=minf(distance,point.distance_to(Geometry2D.get_closest_point_to_segment(point,points[i],points[i+1])))
  distances[label]=distance;nearest_distance=minf(nearest_distance,distance)
 var selected:=nearest;var best:=INF
 for label:String in distances:
  var distance:float=distances[label]
  if distance>nearest_distance+65.0:continue
  # Rendezvous hashing is stable when actors are discovered in a different order.
  var rank:float=float(posmod((str(identity)+":"+label).hash(),100000))/100000.0
  var score:float=rank+(distance-nearest_distance)/130.0
  if score<best:best=score;selected=label
 return selected

# Route names were historically part of the save key. Move legacy state to the
# selected route without carrying an old road position or waypoint onto it.
func migrate_route_state(states:Dictionary,record:Dictionary) -> void:
 var key:=record_key(record)
 if states.has(key):return
 for label:String in Layout.ROUTES:
  var old_key:="%s:%d"%[label,int(record.index)]
  if old_key==key or not states.get(old_key) is Dictionary:continue
  var state:Dictionary=states[old_key].duplicate(true)
  state["point"]=[record.phase.point.x,record.phase.point.y]
  state["goal"]=record.phase.goal
  state["direction"]=1;state["wait"]=0.0
  states[key]=state;states.erase(old_key)
  return

# Keep routine uniformed counterparts away from the actual undercroft, including
# whole route segments and a margin for lane offsets and obstacle detours.
const HIDEOUT_CENTER := Layout.FORT_CENTER+Vector2(-56,48)
const HIDEOUT_PATROL_BUFFER := 160.0
func route_near_hideout(points:Array) -> bool:
 for i in range(points.size()-1):
  if layout.segment_distance(HIDEOUT_CENTER,points[i],points[i+1])<HIDEOUT_PATROL_BUFFER:return true
 return false

func safe_authority_save(states:Dictionary,key:String,index:int,point:Vector2,goal:int) -> Dictionary:
 var state:Dictionary=states.get(key,{}).duplicate(true)
 if state.is_empty():
  for old_route: String in Layout.ROUTES:
   if preload("res://world/suryagarh/settlement_police_routes.gd").allows_route(old_route):continue
   var old_key:="%s:%d"%[old_route,index]
   if states.get(old_key) is Dictionary:
    state=states[old_key].duplicate(true)
    # A new route must never inherit the former route's coordinate/waypoint.
    state["point"]=[point.x,point.y];state["goal"]=goal
    break
 if state.get("point") is Array and state.point.size()==2:
  var old:=Vector2(float(state.point[0]),float(state.point[1]))
  if old.distance_to(HIDEOUT_CENTER)<HIDEOUT_PATROL_BUFFER or not preload("res://world/suryagarh/settlement_police_routes.gd").inhabited(old):
   state["point"]=[point.x,point.y];state["goal"]=goal
 return state

func reset_private_fort_position(states:Dictionary,key:String,point:Vector2,goal:int) -> void:
 var state:Variant=states.get(key)
 if not state is Dictionary or not state.get("point") is Array or state.point.size()!=2:return
 var old:=Vector2(float(state.point[0]),float(state.point[1]))
 if old.distance_to(Layout.FORT_CENTER)<140.0:
  states[key]=state.duplicate(true)
  states[key]["point"]=[point.x,point.y]
  states[key]["goal"]=goal

func apply_record_state(record:Dictionary) -> void:
 migrate_route_state(restored_states,record)
 reset_private_fort_position(restored_states,record_key(record),record.phase.point,int(record.phase.goal))
 if record.get("faction","") in ["police","british"] or record.get("police",false):
  var key:=record_key(record)
  var safe:Dictionary=safe_authority_save(restored_states,key,int(record.index),record.phase.point,int(record.phase.goal))
  if not safe.is_empty():restored_states[key]=safe
 super.apply_record_state(record)

func restore_route_state(states:Dictionary) -> void:
 var repaired:=states.duplicate(true)
 for record in pending:
  migrate_route_state(repaired,record)
  reset_private_fort_position(repaired,record_key(record),record.phase.point,int(record.phase.goal))
  if record.get("faction","") in ["police","british"] or record.get("police",false):
   var key:=record_key(record)
   var safe:=safe_authority_save(repaired,key,int(record.index),record.phase.point,int(record.phase.goal))
   if not safe.is_empty():repaired[key]=safe
 for actor in pedestrians:
  if not is_instance_valid(actor):continue
  var journey:Node=actor.get_node_or_null("CityStreetJourney")
  if journey==null:continue
  var key:="%s:%d"%[actor.get_meta("population_route"),actor.get_meta("population_index")]
  var migrated:Dictionary={"route":actor.get_meta("population_route"),"index":actor.get_meta("population_index"),"phase":{"point":Vector2(actor.global_position.x,actor.global_position.z),"goal":journey.goal}}
  migrate_route_state(repaired,migrated)
  reset_private_fort_position(repaired,key,Vector2(actor.global_position.x,actor.global_position.z),int(journey.goal))
  if actor.get_meta("combat_faction","") not in ["police","british"]:continue
  var safe:=safe_authority_save(repaired,key,int(actor.get_meta("population_index")),Vector2(actor.global_position.x,actor.global_position.z),int(journey.goal))
  if not safe.is_empty():repaired[key]=safe
 super.restore_route_state(repaired)

func closest_phase(points:Array[Vector2],point:Vector2,salt:int=0) -> Dictionary:
 var best:=INF;var phase:Dictionary={"point":points[0],"goal":1}
 for index in points.size()-1:
  var candidate:=Geometry2D.get_closest_point_to_segment(point,points[index],points[index+1])
  if point.distance_squared_to(candidate)<best:
   best=point.distance_squared_to(candidate);phase={"point":candidate,"goal":index+1}
 var segment:int=int(phase.goal)-1
 var along:Vector2=(points[segment+1]-points[segment]).normalized()
 phase.point=Geometry2D.get_closest_point_to_segment(phase.point+along*float(salt%13-6)*1.8,points[segment],points[segment+1])
 return phase

func record_key(record:Dictionary) -> String:
 return "%s:%d"%[record.route,int(record.index)]

func spawn_record(record:Dictionary) -> void:
 var at:Vector2=record.phase.point
 var position:Vector3=clear_spawn(at)
 if not position.is_finite():
  unresolved[record.source_id]="no clear supported spawn yet"
  pending.append(record);spawn_wait=.15;return
 var actor:Node3D
 if record.police:actor=preload("res://characters/npcs/thana/thana_officer.gd").new()
 elif record.faction=="british" and record.profile=="female" and record.source.get_file() in ["private_woman.glb","corporal_woman.glb","sergeant_woman.glb"]:
  actor=preload("res://world/suryagarh/regional_uniform_actor.gd").new()
 elif record.faction=="british":actor=HouseholdActor.new()
 else:actor=Actor.new()
 var figure:=Human.instantiate(record.source,false)
 if figure==null:
  actor.free();unresolved[record.source_id]="failed source import";return
 actor.name="Colleague_%s_%d"%[record.route,int(record.index)]
 actor.movement_enabled=false;actor.movement_profile=StringName(record.profile)
 actor.set_meta("combat_faction",record.faction)
 if record.police:actor.set_meta("external_combat_motion",true)
 actor.set_meta("human_source",record.source)
 actor.set_meta("counterpart_of",record.source_id)
 actor.set_meta("population_route",record.route);actor.set_meta("population_index",record.index)
 actor.set_meta("street_identity",int(record.index)%8)
 actor.set_meta("social_role",record.role)
 actor.set_meta("assigned_workplace",record.points[-1])
 actor.add_child(figure);actor.position=position;add_child(actor)
 unresolved.erase(record.source_id)
 actor.add_to_group("expanded_population_residents")
 var journey:=preload("res://world/suryagarh/city_street_journey.gd").new()
 journey.name="CityStreetJourney";journey.configure(actor,record.points,0)
 journey.viewer=player;journey.crowd=world_social();journey.goal=record.phase.goal;journey.direction=record.direction;journey.wait=record.wait
 journey.speed=.88+float(int(record.index)%5)*.075
 actor.add_child(journey)
 if record.has("saved"):
  journey.distance_walked=float(record.saved.get("distance",0));journey.visits=int(record.saved.get("visits",0))
  if is_instance_valid(journey.crowd):journey.social_cooldown=journey.crowd.age+float(record.saved.get("social_cooldown",5))
  restore_health.call_deferred(actor,record.saved)
  actor.set_meta("dead",record.saved.get("dead",false));actor.set_meta("knocked_out",record.saved.get("knocked_out",false))
 if record.police and is_instance_valid(encounters):
  # Actual police use the existing crime/pursuit/custody owner; no decorative patrols.
  var points:=PackedVector3Array()
  for point:Vector2 in record.points:points.append(encounters.ground(Vector3(point.x,0,point.y)))
  var marker:=Label3D.new();marker.name="AlertMarker";marker.text="!";marker.position.y=2.05;marker.visible=false;actor.add_child(marker)
  encounters.ground_exclusions.append(actor.body_collider.get_rid())
  encounters.patrols.append({"actor":actor,"points":points,"index":record.phase.goal,"step":1,"state":"patrol","sense":0.0,"attack_age":0.0,"hit":false,"marker":marker,"seen":false})
  journey.paused=true;actor.set_process(true)
 pedestrians.append(actor);materialized_count+=1
 for mesh:GeometryInstance3D in actor.find_children("*","GeometryInstance3D",true,false):mesh.visibility_range_end=190;mesh.visibility_range_end_margin=15

func world_social() -> Node:
 return get_parent().get_node_or_null("PopulationSocial")

func _exit_tree() -> void:
 if get_tree()!=null and get_tree().node_added.is_connected(_node_added):get_tree().node_added.disconnect(_node_added)

func remove_colleague(source_id:String) -> void:
 # Roadside callers can leave. Their colleagues must not accumulate each day.
 if not is_inside_tree() or not originals.has(source_id):return
 var state_key:String=source_keys.get(source_id,"")
 var state:Dictionary=super.export_route_state().get(state_key,{})
 if not state.is_empty():
  inactive_states[state_key]=state;restored_states[state_key]=state
 for index in range(pending.size()-1,-1,-1):
  if pending[index].get("source_id","")==source_id:pending.remove_at(index)
 for index in range(pedestrians.size()-1,-1,-1):
  var person:Node3D=pedestrians[index]
  if is_instance_valid(person) and person.get_meta("counterpart_of","")==source_id:
   pedestrians.remove_at(index);materialized_count-=1;person.queue_free()
 originals.erase(source_id);source_keys.erase(source_id);unresolved.erase(source_id);discovered_count-=1

func export_route_state() -> Dictionary:
 var result:Dictionary=super.export_route_state()
 result.merge(inactive_states,false)
 result.merge(restored_states,false)
 return result

