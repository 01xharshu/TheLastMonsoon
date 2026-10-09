extends Node
## Fictional household services. One ledger owns stock, daily limits and survey progress.
var player:CharacterBody3D
var world:Node3D
var clock:Node
var services:Array[Node]=[]
var state:Dictionary={}
var stock:Dictionary={}
var stock_day:=0
var survey_active:=false
var survey_checked:Array[int]=[]
var survey_paid_day:=-1
var fields:Array[Node3D]=[]
var waypoint_at:=Vector2(INF,INF)
var navigation_seconds:=0.0
func day() -> int:return maxi(1,int(clock.current_day)) if is_instance_valid(clock) else 1
func message(text:String) -> void:player.get_node("InventoryComponent").message_requested.emit(text)
func bind(person:Node3D,role:String,home:String) -> Node:
 var service:=preload("res://world/suryagarh/settlements/household_role_service.gd").new()
 service.name="HouseholdConversation";service.ledger=self;service.person=person;service.role=role;service.home_id=home;service.role_id=home+":"+role
 person.set_meta("world_role",role);person.add_child(service);services.append(service)
 return service
func configure_fields() -> void:
 if not fields.is_empty():return
 var gardens:=get_tree().get_nodes_in_group("bhairavpur_garden")
 gardens.sort_custom(func(a,b):
  var origin:=Vector3(-321,7.2,344)
  var da:float=a.global_position.distance_squared_to(origin);var db:float=b.global_position.distance_squared_to(origin)
  return da<db if not is_equal_approx(da,db) else str(a.get_path())<str(b.get_path()))
 for i in mini(3,gardens.size()):
  var target:=preload("res://world/suryagarh/settlements/household_field_check.gd").new()
  target.name="EstateFieldCheck"+str(i);target.ledger=self;target.index=i
  world.add_child(target);target.global_position=gardens[i].global_position+Vector3(0,.65,2.0);fields.append(target)
func _stock_today(home:String) -> Dictionary:
 if not stock.has(home):stock[home]={"roti":2,"mango":0}
 if stock_day==0:stock_day=day()
 if day()>stock_day:
  var elapsed:=mini(6,day()-stock_day)
  for pantry in stock.values():pantry.roti=maxi(0,int(pantry.roti)-elapsed);pantry.mango=maxi(0,int(pantry.mango)-elapsed)
  stock_day=day()
 return stock[home]
func _record(id:String) -> Dictionary:
 if not state.has(id):state[id]={}
 return state[id]
func _business_open(service:Node) -> bool:
 if service.role not in ["merchant","official"]:return true
 return not is_instance_valid(clock) or (clock.current_hour>=9 and clock.current_hour<17)
func request(service:Node,actor:CharacterBody3D) -> void:
 if actor!=player or not service.interaction_available():return
 if not _business_open(service):message("Business hours are 9 in the morning to 5 in the afternoon.");return
 var inv=player.get_node("InventoryComponent");var record:=_record(service.role_id);var pantry:=_stock_today(service.home_id)
 match service.role:
  "landowner":
   configure_fields()
   if fields.size()!=3:message("The field survey is unavailable until three cultivated plots are ready.");return
   if survey_paid_day==day():message("Today's estate field work is already paid.");return
   if not survey_active:
    survey_active=true;survey_checked.clear();mark_survey(true);message("Check three marked cultivated field boundaries, then return to me for 5 rupees.")
   elif survey_checked.size()==3:
    survey_active=false;survey_paid_day=day();clear_survey_waypoint();inv.add_item("rupees",5);message("All three boundaries recorded. Estate work paid: 5 rupees.")
   else:
    mark_survey(true)
    message("Boundaries checked: %d of 3. Look for the active field markers."%survey_checked.size())
  "merchant":
   var count:int=int(record.get("sold",0)) if int(record.get("day",-1))==day() else 0
   if count>=3:message("I have bought today's three-mango order. Return tomorrow.");return
   if not inv.remove_item("mango",1):message("Bring one mango for the counting-house produce order.");return
   record.day=day();record.sold=count+1;pantry.mango=mini(12,int(pantry.mango)+1);inv.add_item("rupees",2);message("One mango received. Paid 2 rupees.")
  "official":
   if record.get("reviewed",false):message("Your revenue receipt is already acknowledged in this estate ledger.");return
   if not inv.has_item("revenue_receipt"):message("Bring the district Treasury's revenue receipt. This estate does not issue district clearances.");return
   record.reviewed=true;inv.add_item("rupees",2);message("Revenue receipt acknowledged. The estate reimburses your 2-rupee filing payment; keep the receipt.")
  "host":supply(service,actor,2,true)
  "cook":
   if int(pantry.roti)<=0:message("The pantry is empty. Use the supply interaction to bring roti.");return
   if not inv.remove_item("rupees",2):message("A kitchen roti costs 2 rupees.");return
   pantry.roti-=1;inv.add_item("roti",1);message("One roti supplied from the household pantry.")
  "water":
   var used:float=float(record.get("liters",0)) if int(record.get("day",-1))==day() else 0.0
   if used>=2:message("Today's two-litre household water allowance is used.");return
   var filled:float=inv.add_water(minf(.5,2-used))
   if filled<=0:message("Bring a water bag with free capacity.");return
   record.day=day();record.liters=used+filled;message("Water bearer filled %.1f litres."%filled)
  "coachman":explain(service,actor)
func supply(service:Node,actor:CharacterBody3D,quantity:int,help:bool) -> void:
 if actor!=player or not service.interaction_available():return
 var pantry:=_stock_today(service.home_id);var record:=_record(service.role_id)
 if help and int(record.get("help_day",-1))==day():message("Today's household pantry order is already filled.");return
 if int(pantry.roti)+quantity>12:message("The pantry has enough stored food.");return
 var inv=player.get_node("InventoryComponent")
 if not inv.remove_item("roti",quantity):message("Bring %d roti for the pantry."%quantity);return
 pantry.roti+=quantity;inv.add_item("rupees",quantity*2)
 if help:
  record.help_day=day()
  var fame=player.get_node_or_null("FameComponent")
  if fame!=null:fame.award_help()
 message("Pantry delivery received: %d roti. Paid %d rupees."%[quantity,quantity*2])
func explain(service:Node,actor:CharacterBody3D) -> void:
 if actor!=player:return
 message({"landowner":"I oversee the estate fields and accounts. My rent-office desk is where the coach takes me.","merchant":"I purchase produce here. Shipping and cloth deliveries are handled by the existing public dispatch clerk.","official":"I review this estate's accounts. District petitions, court registration and Treasury payments remain with those offices.","host":"I arrange this household's provisions. Pantry deliveries support the cook's food service.","cook":"I sell stored household meals and accept pantry supplies. Stock carries between visits.","water":"I carry household water. Bring a water bag; I can spare up to two litres per day.","coachman":"This coach is reserved for its household's home–office route. Public carts are available at the village cart stand."}.get(service.role,"I work for this household."))
func export_state() -> Dictionary:
 return {"roles":state.duplicate(true),"stock":stock.duplicate(true),"stock_day":stock_day,"survey_active":survey_active,"survey_checked":survey_checked.duplicate(),"survey_paid_day":survey_paid_day}
func restore_state(data:Dictionary) -> void:
 state=data.get("roles",{}).duplicate(true);stock=data.get("stock",{}).duplicate(true);stock_day=maxi(0,int(data.get("stock_day",0)))
 survey_active=bool(data.get("survey_active",false));survey_paid_day=int(data.get("survey_paid_day",-1));survey_checked.clear()
 for value in data.get("survey_checked",[]):
  if value in [0,1,2] and not int(value) in survey_checked:survey_checked.append(int(value))
 if survey_active:call_deferred("configure_fields")

func _process(delta:float) -> void:
 if not survey_active:return
 navigation_seconds+=delta
 if navigation_seconds<1:return
 navigation_seconds=0;mark_survey()
func mark_survey(force:bool=false) -> void:
 var map:=player.get_node_or_null("UI/WorldMap")
 if map==null:return
 var errands:=world.get_node_or_null("ErrandSystem")
 if errands!=null and not errands.active.is_empty():return
 if not force and map.waypoint.is_finite() and map.waypoint.distance_to(waypoint_at)>.1:return
 var target:Node3D
 for marker in fields:
  if not marker.index in survey_checked:target=marker;break
 if target==null:
  for service in services:
   if service.role=="landowner" and service.interaction_available():target=service;break
 if target==null:return
 waypoint_at=Vector2(target.global_position.x,target.global_position.z)
 map.selected_site="";map.waypoint=waypoint_at
func clear_survey_waypoint() -> void:
 var map:=player.get_node_or_null("UI/WorldMap")
 if map!=null and map.waypoint.distance_to(waypoint_at)<.1:map.waypoint=Vector2(INF,INF)
 waypoint_at=Vector2(INF,INF)
