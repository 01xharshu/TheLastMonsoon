extends Node
## Daily road requests join the existing ledger; at most two callers are live.
const IDS := ["road_letter","road_office_bag","road_warehouse_crate","road_injured"]
var manager: Node3D
var locations: Dictionary = {}
var location_days: Dictionary = {}
var cargo: Node3D
var cargo_cart: Node3D
var cargo_job := ""
var tick := 0.0
var call_wait := 0.0
var spawn_wait := 0.0
var last_spawn := Vector3.INF
var placed_bag: Node3D
var graph: AStar2D

static func catalogue() -> Dictionary:
 var result: Dictionary = {}
 var specs := [
  ["road_letter","A letter for a family","money_receiver",8,"delivery","Please take this sealed letter to my family by the port.","Hand the sealed letter to the family receiver at the port."],
  ["road_office_bag","A bag for the dispatch office","road_office_desk",10,"delivery","Please leave my dispatch bag on the counting-house desk. The clerk is expecting it.","Place the dispatch bag on the counting-house dispatch desk."],
  ["road_warehouse_crate","A stranded warehouse consignment","port_cargo",16,"delivery","My goods cannot continue on foot. Bring a cart, load this sealed crate and take it to the port warehouse.","Bring the loaded cart beside the port warehouse and hand over the crate."],
  ["road_injured","An injured traveller needs the hospital","road_hospital",24,"escort","I hurt my leg and cannot walk to the hospital. Please bring a passenger cart and take me there. The relief fund pays for safe arrival.","Drive to the hospital, stop and help the injured traveller step down."]]
 for row in specs:
  result[row[0]]={"title":row[1],"offer":row[0]+"_caller","pickup":row[0]+"_caller","goal":row[2],"pay":row[3],"kind":row[4],"description":row[5],"roadside":true,"road_objective":row[6],"road_pickup":"Bring a passenger cart beside the injured traveller and stop." if row[4]=="escort" else "Collect the entrusted item from the caller."}
 return result

func configure(owner: Node3D, saved: Dictionary) -> void:
 manager=owner;graph=preload("res://vehicles/coach_routes.gd").build()
 # Actual existing counting-house desk and hospital entrance, not new buildings.
 var desk:=preload("res://world/suryagarh/errands/errand_target.gd").new()
 desk.manager=manager;desk.endpoint="road_office_desk";desk.position=manager.targets.parcel.global_position
 manager.add_child(desk);manager.targets[desk.endpoint]=desk
 desk.interaction_text="Place dispatch bag on desk";desk.hold_duration=1.2
 var hospital:=manager.get_parent().get_node_or_null("Settlement/BritishCantonment/MilitaryHospital") as Node3D
 if hospital!=null:
  var at:Vector3=hospital.to_global(Vector3(0,.24,7))
  manager._person("road_hospital","HospitalReceivingOrderly",at,"village_farmer")
  manager.targets.road_hospital.interaction_text="Help passenger into hospital care"
  _ground_hospital.call_deferred()
 restore_state(saved);restore_active()

func _ground_hospital() -> void:
 await get_tree().physics_frame
 if not manager.targets.has("road_hospital"):return
 var target:Node3D=manager.targets.road_hospital
 var actor:Node3D=target.person
 var query:=PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*2,actor.global_position-Vector3.UP*3,1)
 query.exclude=[target.get_rid(),actor.get_node("BodyCollider").get_rid()]
 var hit:=manager.get_world_3d().direct_space_state.intersect_ray(query)
 if not hit.is_empty():actor.global_position.y=hit.position.y
 manager.floor_levels.road_hospital=actor.global_position.y

func export_state() -> Dictionary:
 var positions:Dictionary={}
 for id in locations:
  var p:Vector3=locations[id];positions[id]=[p.x,p.y,p.z]
 return {"locations":positions,"days":location_days.duplicate(),"cargo_vehicle":manager.expanded._vehicle_state(cargo_cart) if is_instance_valid(cargo_cart) else {},"cargo_cart":str(manager.get_parent().get_path_to(cargo_cart)) if is_instance_valid(cargo_cart) else ""}

func restore_state(saved: Dictionary) -> void:
 if cargo!=null:cargo.queue_free();cargo=null
 cargo_job=""
 if is_instance_valid(cargo_cart):cargo_cart.remove_meta("errand_cargo")
 cargo_cart=null
 for request in IDS:_despawn(request)
 locations.clear();location_days.clear()
 var positions:Dictionary=saved.get("locations",{}) if saved.get("locations",{}) is Dictionary else {}
 var days:Dictionary=saved.get("days",{}) if saved.get("days",{}) is Dictionary else {}
 for id in IDS:
  var p=positions.get(id,[])
  if p is Array and p.size()==3:
   var valid:=true
   for value in p:
    if not (value is float or value is int) or not is_finite(float(value)):valid=false
   if valid and absf(float(p[0]))<1800 and absf(float(p[2]))<1800 and absf(float(p[1]))<200:
    locations[id]=Vector3(float(p[0]),float(p[1]),float(p[2]));location_days[id]=int(days[id]) if days.get(id) is int or days.get(id) is float else 1
 var path:String=str(saved.get("cargo_cart",""))
 if not path.is_empty() and not path.begins_with("/") and not ".." in path:
  cargo_cart=manager.get_parent().get_node_or_null(NodePath(path)) as Node3D
 if saved.get("cargo_vehicle",{}) is Dictionary and not saved.get("cargo_vehicle",{}).is_empty():
  cargo_cart=manager.expanded._restore_vehicle(saved.cargo_vehicle,false)

func restore_active() -> void:
 var id:String=manager.active
 if not id in IDS:return
 if not locations.has(id):
  # Old/malformed saves cannot invent delivery progress or a pickup.
  manager.stages.erase(id);manager.active="";return
 _spawn(id)
 if id=="road_injured":manager.expanded.bind_passenger(id,id+"_caller","road_hospital")
 if manager.stages.get(id,"")=="carrying" and id!="road_injured":
  if id=="road_warehouse_crate" and is_instance_valid(cargo_cart):cargo_cart.set_meta("errand_cargo",true)
  _make_cargo(id)

func accepted(id: String) -> void:
 if not id in IDS:return
 if id=="road_injured":manager.expanded.bind_passenger(id,id+"_caller","road_hospital")
 manager.targets[id+"_caller"].interaction_text="Help traveller board" if id=="road_injured" else "Collect entrusted item"

func completed(id: String) -> void:
 if not id in IDS:return
 if is_instance_valid(cargo):
  if id=="road_office_bag":
   if is_instance_valid(placed_bag):placed_bag.queue_free()
   placed_bag=cargo;cargo.global_position=manager.targets.road_office_desk.global_position
  else:cargo.queue_free()
 if is_instance_valid(cargo_cart):cargo_cart.remove_meta("errand_cargo")
 cargo=null;cargo_job="";cargo_cart=null;spawn_wait=35
 if id=="road_injured":manager.player.get_node("FameComponent").award_help()

func cancelled(id: String) -> void:
 if not id in IDS:return
 if is_instance_valid(cargo):cargo.queue_free()
 if is_instance_valid(cargo_cart):cargo_cart.remove_meta("errand_cargo")
 cargo=null;cargo_job="";cargo_cart=null;spawn_wait=20
 if manager.targets.has(id+"_caller"):manager.targets[id+"_caller"].interaction_text="Talk about work"

func use_endpoint(endpoint: String) -> bool:
 if manager.active in ["road_letter","road_office_bag"] and endpoint==manager.active+"_caller" and manager.stages.get(manager.active,"")=="accepted":
  var equipment:Node=manager.player.get_node("VisualRoot/CharacterVisual").equipment
  if not equipment.stowed:
   manager._message("Put away your weapon before collecting the entrusted item.");return true
 if manager.active!="road_warehouse_crate":return false
 var id:String=manager.active
 if endpoint==id+"_caller" and manager.stages.get(id,"")=="accepted":
  for handle in get_tree().get_nodes_in_group("cart_boarding_handles"):
   var vehicle:Node3D=handle.get_parent()
   if not vehicle.seat_sockets.has("PassengerSeat") and vehicle.get_node_or_null("CartVisual/ProduceBundle")==null:continue
   if vehicle.boarding.role=="passenger" and vehicle.boarding.rider!=null:continue
   if not vehicle.boarding.transition.is_empty():continue
   if vehicle.global_position.distance_to(manager.targets[endpoint].global_position)>5 or absf(vehicle.boarding.speed)>.15:continue
   if vehicle.boarding.travel.payer!=null or vehicle.has_meta("errand_passenger"):continue
   cargo_cart=vehicle;cargo_cart.set_meta("errand_cargo",true);manager.stages[id]="carrying";_make_cargo(id)
   manager._clear_job_waypoint();manager._message("Crate loaded. Take this cart to the port warehouse.");return true
  manager._message("Bring a cart beside the crate and stop to load it.");return true
 if endpoint=="port_cargo" and manager.stages.get(id,"")=="carrying":
  if not is_instance_valid(cargo_cart) or cargo_cart.global_position.distance_to(manager.targets.port_cargo.global_position)>8 or absf(cargo_cart.boarding.speed)>.15:
   manager._message("Bring the cart carrying the crate beside the warehouse and stop.");return true
  manager._finish(id);return true
 return false

func _physics_process(delta: float) -> void:
 if manager==null or get_tree().paused:return
 call_wait=maxf(0,call_wait-delta);spawn_wait=maxf(0,spawn_wait-delta)
 var id:String=manager.active
 if id in IDS and manager.stages.get(id,"")=="carrying" and id!="road_injured":
  if cargo_job!=id:_make_cargo(id)
  _update_cargo()
 if id=="road_injured":
  var mounted=manager.player.get_meta("mounted_vehicle") if manager.player.has_meta("mounted_vehicle") else null
  if mounted!=null and mounted.role=="driver" and absf(mounted.speed)<.15 and mounted.transition=="":
   if manager.stages.get(id,"")=="accepted" and mounted.cart.global_position.distance_to(manager.targets[id+"_caller"].global_position)<5:manager.expanded.use_endpoint(id+"_caller")
   elif manager.stages.get(id,"")=="carrying" and mounted.cart.global_position.distance_to(manager.targets.road_hospital.global_position)<7:manager.expanded.use_endpoint("road_hospital")
 tick+=delta
 if tick<2:return
 tick=0
 if manager.player.health<=0 or manager.player.get_meta("map_open",false) or manager.player.get_meta("scroll_open",false) or manager.player.get_meta("document_busy",false) or manager.player.get_meta("weapon_wheel_open",false) or manager.player.inventory_ui.is_open():return
 for request in IDS:
  var endpoint:String=request+"_caller"
  if manager.targets.has(endpoint):
   var person:Node3D=manager.targets[endpoint].person
   if request!=id and person.global_position.distance_to(manager.player.global_position)>220:_despawn(request)
   elif call_wait<=0 and id.is_empty() and manager.job_available(request) and not person.get_meta("dead",false) and person.global_position.distance_to(manager.player.global_position)<24:
    manager._message({"road_injured":"Please help! I need a cart to reach the hospital.","road_letter":"Traveller! Could you deliver a letter for me?","road_office_bag":"Could someone take my bag to the dispatch office?","road_warehouse_crate":"My consignment is stranded. Can you help with a cart?"}[request]+" Stop and speak to the caller.");call_wait=30
 if not id.is_empty() or spawn_wait>0:return
 var live:=0
 for request in IDS:
  if manager.targets.has(request+"_caller"):live+=1
 if live>=2:return
 if last_spawn.is_finite() and manager.player.global_position.distance_to(last_spawn)<100:return
 var rng:=RandomNumberGenerator.new();rng.seed=1857+manager.current_job_day()*7919+int(manager.player.global_position.x)*31+int(manager.player.global_position.z)*17
 var available:Array=[]
 for request in IDS:
  if manager.job_available(request) and not manager.targets.has(request+"_caller"):available.append(request)
 if available.is_empty():return
 var request:String=available[rng.randi_range(0,available.size()-1)]
 var candidates:Array[Vector2]=[]
 var at:=Vector2(manager.player.global_position.x,manager.player.global_position.z)
 for point in graph.get_point_ids():
  var p:Vector2=graph.get_point_position(point);var distance:=p.distance_to(at)
  if distance>45 and distance<120:
   var links:=graph.get_point_connections(point)
   if links.is_empty():continue
   var direction:Vector2=(graph.get_point_position(links[0])-p).normalized()
   var shoulder:Vector2=p+Vector2(-direction.y,direction.x)*4.5
   if not manager.get_parent().layout.built_area(shoulder.x,shoulder.y):candidates.append(shoulder)
 if candidates.is_empty():return
 for attempt in mini(12,candidates.size()):
  var p:Vector2=candidates[rng.randi_range(0,candidates.size()-1)]
  var grounded:=_safe_ground(p)
  if not grounded.is_finite():continue
  locations[request]=grounded;location_days[request]=manager.current_job_day();_spawn(request)
  last_spawn=manager.player.global_position;spawn_wait=45;break

func _safe_ground(point: Vector2) -> Vector3:
 var y:float=manager.get_parent().layout.height(point.x,point.y)
 var space:=manager.get_world_3d().direct_space_state
 var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(point.x,y+4,point.y),Vector3(point.x,y-3,point.y),1))
 if hit.is_empty() or hit.normal.y<.85:return Vector3.INF
 var shape:=CapsuleShape3D.new();shape.radius=.38;shape.height=1.85
 var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.transform.origin=hit.position+Vector3.UP*.96;query.collision_mask=1
 if not space.intersect_shape(query,1).is_empty():return Vector3.INF
 return hit.position

func _spawn(id: String) -> void:
 var endpoint:String=id+"_caller"
 if manager.targets.has(endpoint) or not locations.has(id):return
 manager._person(endpoint,id.capitalize()+"Caller",locations[id],"errand_passenger" if id=="road_injured" else "village_farmer")
 var actor:Node3D=manager.targets[endpoint].person
 manager.floor_levels[endpoint]=actor.global_position.y
 actor.set_meta("road_request",id)
 if id=="road_injured":actor.set_meta("injured_traveller",true)

func _despawn(id: String) -> void:
 var endpoint:String=id+"_caller"
 if not manager.targets.has(endpoint):return
 var actor:Node3D=manager.targets[endpoint].person;manager.targets.erase(endpoint);manager.floor_levels.erase(endpoint);actor.queue_free()

func _make_cargo(id: String) -> void:
 if is_instance_valid(cargo):cargo.queue_free()
 var path:String="res://objects/household/storage/crate.tscn" if id=="road_warehouse_crate" else "res://objects/household/grain_sack.tscn" if id=="road_office_bag" else "res://objects/household/supplies/supply_parcel.tscn"
 cargo=load(path).instantiate();manager.add_child(cargo);cargo_job=id
 cargo.scale=Vector3.ONE*(.55 if id in ["road_warehouse_crate","road_office_bag"] else .65)
 for body in cargo.find_children("*","CollisionObject3D",true,false):body.collision_layer=0
 if cargo is CollisionObject3D:cargo.collision_layer=0
 _update_cargo()

func _update_cargo() -> void:
 if not is_instance_valid(cargo):return
 if cargo_job=="road_warehouse_crate":
  if is_instance_valid(cargo_cart):
   var support:Vector3=cargo_cart.seat_sockets.PassengerSeat.global_position if cargo_cart.seat_sockets.has("PassengerSeat") else cargo_cart.get_node("CartVisual/ProduceBundle").to_global(Vector3(0,.165,0))
   cargo.global_transform=Transform3D(cargo_cart.global_basis.scaled(Vector3.ONE*.55),support)
  return
 var visual:Node3D=manager.player.get_node("VisualRoot/CharacterVisual")
 var skeleton:Skeleton3D=visual.get("skeleton")
 if skeleton==null:return
 var bone:=skeleton.find_bone("hand_r")
 if bone>=0:
  var pose:Transform3D=skeleton.global_transform*skeleton.get_bone_global_pose(bone)
  var scale_amount:=.55 if cargo_job=="road_office_bag" else .65
  cargo.global_transform=Transform3D(visual.global_basis.scaled(Vector3.ONE*scale_amount),pose.origin-Vector3.UP*(.31 if cargo_job=="road_office_bag" else .06))
