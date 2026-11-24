extends Node3D
## Independent second mission after Mangal's first twelve-rifle delivery.
const Startup=preload("res://systems/world_startup.gd")
const Route=preload("res://story/consignment_route.gd")
const Sight=preload("res://systems/visual_perception.gd")
const Actions=preload("res://systems/action_permissions.gd")
const WitnessActor=preload("res://characters/npcs/british/british_npc_actor.gd")
const Identity=preload("res://systems/entity_identity.gd")
const WAVE_ENDS := [3,5,7]
const STAGES=["dormant","assigned","outbound","loading","chase","celebration","complete","failed"]
var player: CharacterBody3D
var first: Node
var configured=false
var stage="dormant"
var pending: Dictionary={}
var restore_waiting=false
var route:=PackedVector3Array()
var road_supports: Array[CollisionObject3D]=[]
var cart: Node3D
var driver: Node3D
var companion: Node3D
var cargo: Node3D
var pursuers: Array[Node3D]=[]
var riders: Array[Node3D]=[]
var chase_checkpoint: Dictionary={}
var chase_deaths:=0
var mission_skipped:=false
var wave=0
var defeated: Array[int]=[]
var route_index=0
var paid=false
var recognition_age=0.0
var reported: Dictionary={}
var observers: Array[Node3D]=[]
var observer_ids: Dictionary={}
var traffic: Array[Node]=[]
var journey_ids: Dictionary={}
const TRAFFIC_SCRIPTS=["res://world/suryagarh/city_street_journey.gd","res://world/suryagarh/settlements/street_journey.gd","res://world/suryagarh/city_cart_journey.gd","res://vehicles/bullock_road_journey.gd"]
var paused_traffic: Dictionary={}
var traffic_age=0.0
var speed=0.0
var celebration_arrived:=false
var celebration_player_physics:=true
var celebration_age=0.0
var celebration_duration=14.0
var dialogue_voice: AudioStreamPlayer
var dialogue_queue: Array[AudioStream]=[]
var celebration_mangal_voice: AudioStream
var celebration_fighter_voice: AudioStream
var celebration_errand_layers: Dictionary = {}
var celebration_face_actor: Node3D
var celebration_face: RefCounted
var cinematic_lease=-1
var service: Node
var curtain: ColorRect
var caption: Label
var discussion_camera: Camera3D
var prior_camera: Camera3D
var prior_ui_visible=true
var prior_weapon_stowed=true
var posters: Array[Node3D]=[]
var startup_task=-1
var public_route_end=-1
var holding_start=-1
var holding_end=-1
var holding_laps=0
func _ready() -> void:
 dialogue_voice=AudioStreamPlayer.new();dialogue_voice.name="DialogueVoice";add_child(dialogue_voice)
 dialogue_voice.finished.connect(play_next_voice)
 name="ConsignmentStory";process_priority=105;get_tree().node_added.connect(witness_added);startup_task=Startup.begin("Preparing the consignment route…");call_deferred("configure")
func configure() -> void:
 first=get_parent().get_node("RebellionStory");player=get_parent().get_node("Player")
 if not player.has_node("ConsignmentDamageFeedback"):
  var feedback=preload("res://story/consignment_damage_feedback.gd").new();feedback.name="ConsignmentDamageFeedback";player.add_child(feedback)
 while not first.configured:await get_tree().process_frame
 service=Actions.install(player);preload("res://world/suryagarh/tree_trunk_collision.gd").configure_terrain_support(self);route=Route.points(get_parent().layout,get_world_3d().direct_space_state);public_route_end=Route.shared_end_index(route);road_supports=Route.build(self,route)
 for index in route.size():
  if Vector2(route[index].x,route[index].z).distance_to(Route.Data.HOLDING_ANCHOR)<.01:
   if holding_start<0:holding_start=index
   else:holding_end=index
 assert(holding_start>=0 and holding_end>holding_start,"Continuous chase circuit must close physically")
 cart=preload("res://vehicles/horse_cart_candidate.gd").new();cart.variant=1;cart.name="ConsignmentTroopCart";cart.set_meta("player_owned",true);cart.set_meta("consignment_cart",true);cart.set_meta("npc_occupied_seats",["DriverSeat"]);add_child(cart);cart.add_to_group("live_travel_carts")
 cart.boarding.set_physics_process(false);cart.global_position=route[-1]
 var socket=Node3D.new();socket.name="ConsignmentRearSeat";socket.position=Vector3(0,1.36,3.45);socket.rotation.y=PI;cart.add_child(socket);cart.seat_sockets["ConsignmentRearSeat"]=socket
 cargo=Node3D.new();cargo.name="ImportantPortConsignment";cart.add_child(cargo)
 var builder=preload("res://world/suryagarh/settlements/settlement_builder.gd").new();builder.wood=builder.material(Color(.34,.23,.13))
 for i in 3:builder.piece(cargo,"SealedShipmentCrate",Vector3(-.5+i*.5,1.6,2.25),Vector3(.48,.9,1.1),builder.wood)
 builder.piece(cart,"RearPassengerFootrest",Vector3(0,.925,4.10),Vector3(1.5,.11,.55),builder.wood)
 builder.piece(cart,"RearBoardingStep",Vector3(0,.45,4.55),Vector3(.8,.10,.40),builder.wood)
 cart.boarding._add_clearance(Vector3(0,.45,4.55),Vector3(.8,.10,.40))
 cart.set_meta("consignment_step_clearance",cart.boarding.clearance_shapes[-1])
 cart.boarding._cart_handle_exclusions()
 for name in ["RearPassengerFootrest","RearBoardingStep"]:
  for body in cart.get_node(name).find_children("*","CollisionObject3D",true,false):cart.boarding.cart_handle_rids.append(body.get_rid())
 cargo.hide()
 for body in cargo.find_children("*","CollisionObject3D",true,false):cart.boarding.cart_handle_rids.append(body.get_rid())
 builder.free()
 var cover=preload("res://story/consignment_cart_cover.gd").new();cover.director=self;cart.add_child(cover)
 driver=make_fighter("ConsignmentDriver");companion=make_fighter("ConsignmentCompanion")
 driver.body_collider.collision_layer=8;companion.body_collider.collision_layer=8
 driver.riding_cart=cart;driver.riding_socket=cart.seat_sockets.DriverSeat;driver.driving=true
 var second=Node3D.new();second.name="ConsignmentCompanionSeat";second.position=Vector3(.65,1.4,1.9);cart.add_child(second);companion.riding_cart=cart;companion.riding_socket=second
 driver.seated_foot_drop=.38;driver.seated_foot_forward=-.48;companion.seated_foot_drop=.31;companion.seated_foot_forward=-.48
 builder=preload("res://world/suryagarh/settlements/settlement_builder.gd").new();builder.wood=builder.material(Color(.34,.23,.13))
 builder.piece(cart,"EscortSeatBench",Vector3(.65,1.30,1.9),Vector3(.68,.10,.65),builder.wood)
 for crew in [driver,companion]:
  var rest:Vector3=crew.riding_socket.position+Vector3(0,-crew.seated_foot_drop,crew.seated_foot_forward)
  var board:Node3D=builder.piece(cart,"CrewFootboard",rest-Vector3.UP*.035,Vector3(.72,.07,.42),builder.wood)
  for body in board.find_children("*","CollisionObject3D",true,false):cart.boarding.cart_handle_rids.append(body.get_rid())
 for body in cart.get_node("EscortSeatBench").find_children("*","CollisionObject3D",true,false):cart.boarding.cart_handle_rids.append(body.get_rid())
 builder.free()
 for i in 7:
  await Startup.checkpoint(self,"Preparing mounted pursuers…")
  install_pursuer(i)
 var prompt=preload("res://story/rebellion_prompt.gd").new();prompt.director=self;prompt.action_id="consignment";prompt.interaction_text="Mangal · Escort the ship consignment";prompt.interaction_icon="vehicle";add_child(prompt);prompt.global_position=first.sites.prompts.briefing.global_position+Vector3(0,0,1)
 var col=CollisionShape3D.new();var shape=SphereShape3D.new();shape.radius=.35;col.shape=shape;prompt.add_child(col)
 for at in [Vector2(-340,-305),Vector2(-300,232),Vector2(320,147),Vector2(-194,625)]:
  var board=Node3D.new();add_child(board);board.position=Vector3(at.x,get_parent().layout.height(at.x,at.y)+1.8,at.y);posters.append(board)
  var paper=MeshInstance3D.new();var sheet=QuadMesh.new();sheet.size=Vector2(1.3,2.1);paper.mesh=sheet;var stock=StandardMaterial3D.new();stock.albedo_color=Color(.82,.72,.52);stock.roughness=1;paper.material_override=stock;board.add_child(paper)
  var wood=StandardMaterial3D.new();wood.albedo_color=Color(.22,.12,.06);wood.roughness=1
  for x in [-.56,.56]:
   var leg=MeshInstance3D.new();var timber=BoxMesh.new();timber.size=Vector3(.08,1.8,.08);leg.mesh=timber;leg.position=Vector3(x,-.9,-.08);leg.material_override=wood;leg.visibility_range_end=90;board.add_child(leg)
  var backing=MeshInstance3D.new();var frame=BoxMesh.new();frame.size=Vector3(1.42,2.2,.06);backing.mesh=frame;backing.position.z=-.06;backing.material_override=wood;backing.visibility_range_end=90;board.add_child(backing)
  var portrait=MeshInstance3D.new();var likeness=QuadMesh.new();likeness.size=Vector2(.56,.7);portrait.mesh=likeness;portrait.position=Vector3(0,.05,.009);var ink=StandardMaterial3D.new();ink.albedo_texture=preload("res://assets/story/wanted_arjun.png");ink.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;portrait.material_override=ink;portrait.visibility_range_end=90;board.add_child(portrait)
  for part in ["title","body"]:
   var text=Label3D.new();text.position=Vector3(0,.74 if part=="title" else -.65,.012);text.text="WANTED\nARJUN" if part=="title" else "Rebel associate\nReport sightings\nto the thana";text.font_size=40 if part=="title" else 28;text.pixel_size=.0045;text.outline_size=0;text.modulate=Color(.13,.10,.07);text.no_depth_test=false;text.visibility_range_end=90;board.add_child(text)
  paper.visibility_range_end=90;board.hide()
 var layer=CanvasLayer.new();layer.layer=86;add_child(layer);curtain=ColorRect.new();layer.add_child(curtain);curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);curtain.color=Color(0,0,0,0);curtain.mouse_filter=Control.MOUSE_FILTER_IGNORE
 caption=Label.new();layer.add_child(caption);caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);caption.offset_left=70;caption.offset_right=-70;caption.offset_top=-115;caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;caption.add_theme_font_size_override("font_size",22);caption.add_theme_constant_override("outline_size",5);caption.hide()
 discussion_camera=Camera3D.new();discussion_camera.fov=60;add_child(discussion_camera)
 for actor in get_tree().get_nodes_in_group("combat_actors"):register_witness(actor)
 for handle in cart.get_children():
  if handle is CollisionObject3D and handle.is_in_group("cart_boarding_handles") and not cart.boarding.cart_handle_rids.has(handle.get_rid()):cart.boarding.cart_handle_rids.append(handle.get_rid())
 var presentation=preload("res://story/consignment_cart_presentation.gd").new();presentation.name="CartPresentation";add_child(presentation)
 collect_traffic(get_parent());configured=true;cart.hide();driver.hide();companion.hide()
 if restore_waiting:var saved=pending;pending={};restore_waiting=false;restore_state(saved)
 Startup.finish(startup_task)
func install_pursuer(index: int) -> void:
 if index<pursuers.size():
  enable_pursuer(index,false);var old_rider=riders[index];var old_horse=pursuers[index]
  remove_child(old_rider);old_rider.free();remove_child(old_horse);old_horse.free()
 var rider=preload("res://story/consignment_mounted_actor.gd").new();rider.name="ConsignmentPolice%d"%index;rider.movement_enabled=false;rider.set_meta("population_expansion_exempt",true);rider.set_meta("mission_police_owner","consignment");rider.set_meta("combat_faction","police");rider.set_meta("external_combat_motion",true);rider.add_child(preload("res://characters/human_scene.gd").instantiate("res://characters/npcs/thana/burkundaz_motion.glb"));add_child(rider);rider.remove_from_group("combat_actors")
 var horse=preload("res://horses/police_patrol_horse.gd").new();horse.name="ConsignmentPoliceHorse%d"%index;add_child(horse);horse.officer=rider;rider.patrol_mount=horse;rider.body_collider.collision_layer=8
 rider.set_meta("firearm_exclusions",[horse.get_rid(),horse.vitality.hit_body.get_rid(),rider.get_node("Vitality").hit_body.get_rid()])
 var gun=preload("res://story/consignment_mounted_firearm.gd").new();gun.target=player;gun.shot_damage=8;gun.aim_delay=1.3;gun.reload_seconds=4.5;gun.cartridges=20;rider.add_child(gun);gun.set_process(false);rider.firearm=gun
 horse.vitality.died.connect(pursuer_mount_fell.bind(index));rider.get_node("Vitality").died.connect(defeat.bind(index));
 if index>=pursuers.size():pursuers.append(horse);riders.append(rider)
 else:pursuers[index]=horse;riders[index]=rider
 enable_pursuer(index,false)
func make_fighter(label: String) -> Node3D:
 var actor=preload("res://story/rebellion_actor.gd").new();actor.name=label;actor.viewer=player;actor.movement_enabled=false;actor.set_meta("population_expansion_exempt",true);actor.set_meta("rebel_travel",true);actor.set_meta("combat_faction","indian");actor.add_child(preload("res://characters/human_scene.gd").instantiate("res://characters/npcs/mangal_rebels/mangal_rebel.glb"));add_child(actor)
 var rifle=preload("res://environment/weapons/enfield_p53/weapon_enfield_p53_01.glb").instantiate();actor.add_child(rifle);rifle.position=Vector3(.18,.55,-.22);rifle.rotation.z=PI*.5;rifle.scale=Vector3.ONE*.85
 var sling=BoneAttachment3D.new();sling.bone_name="spine_02";actor._skeleton.add_child(sling)
 var placement: Transform3D=actor._skeleton.global_transform.affine_inverse()*rifle.global_transform
 rifle.reparent(sling,false);rifle.transform=actor._skeleton.get_bone_global_rest(actor._skeleton.find_bone("spine_02")).affine_inverse()*placement
 return actor
func collect_traffic(node: Node) -> void:
 var script=node.get_script()
 if script!=null and script.resource_path in TRAFFIC_SCRIPTS:register_journey(node)
 for child in node.get_children():collect_traffic(child)
func enable_pursuer(index: int,enabled: bool) -> void:
 var horse=pursuers[index] if index<pursuers.size() else get_node("ConsignmentPoliceHorse%d"%index)
 var rider=riders[index] if index<riders.size() else get_node("ConsignmentPolice%d"%index)
 horse.visible=enabled;rider.visible=enabled;horse.set_physics_process(enabled);rider.set_process(enabled)
 horse.collision_layer=1 if enabled else 0;horse.vitality.hit_body.collision_layer=8 if enabled else 0;rider.body_collider.collision_layer=8 if enabled else 0;rider.get_node("Vitality").hit_body.collision_layer=8 if enabled else 0
 rider.firearm.hostile=enabled
func can_request(id: String) -> bool:return configured and id=="consignment" and stage in ["assigned","failed"] and first.stage=="complete" and player.health>0
func request(id: String,actor: CharacterBody3D) -> bool:
 if actor!=player or not can_request(id):return false
 if actor.global_position.distance_to(first.sites.prompts.briefing.global_position)>5:return false
 for i in pursuers.size():install_pursuer(i)
 first.release_mount((player.get_meta("mounted_vehicle") if player.has_meta("mounted_vehicle") else null));route_index=route.size()-1;cart.global_position=route[route_index].move_toward(route[route_index-1],2.0);cart.rotation.y=heading(route[route_index-1]-cart.global_position)
 cart.show();cargo.hide();driver.show();companion.show();cart.seat_sockets.ConsignmentRearSeat.position.z=2.9;player.global_position=cart.to_global(Vector3(0,.96,5.15))
 if not cart.board_at(player,"ConsignmentRearSeat","passenger"):return false
 driver.riding_cart=cart;driver.riding_socket=cart.seat_sockets.DriverSeat;driver.driving=true;driver.body_collider.collision_layer=8
 companion.riding_cart=cart;companion.riding_socket=cart.get_node("ConsignmentCompanionSeat");companion.body_collider.collision_layer=8
 cart.set_meta("consignment_locked",true);cart.boarding.set_physics_process(true);stage="outbound";player.set_meta("consignment_concealed",true);sync_guidance()
 var briefing:="Bring the sealed ship consignment to camp. Stay hidden at the rear; the others will drive."
 player.inventory.message_requested.emit("Mangal: "+briefing)
 dialogue_voice.stop();dialogue_queue.clear();queue_voice("Mangal",briefing);play_next_voice()
 return true
func objective() -> String:
 match stage:
  "assigned":return "Wanted posters circulated · Speak to Mangal about the next ship consignment."
  "outbound":return "Stay low behind the cart's rear sideboards · Your companion drives to the ship yard."
  "loading":return "Ship yard · E to load the important consignment and depart for camp."
  "chase":return "Rear passenger · Aim/fire · Auto reload. Defeat mounted pursuers · %d/7. Your companion drives."%defeated.size()
  "celebration":return "The consignment and fighters have escaped."
  "failed":return "Consignment interrupted · Return to Mangal to retry."
 return ""
func destination() -> Dictionary:
 if not configured or stage in ["dormant","complete","celebration"]:return {}
 var at: Vector3=first.sites.prompts.briefing.global_position if stage in ["assigned","failed"] else route[0] if stage in ["outbound","loading"] else route[-1]
 return {"position":at+Vector3.UP,"label":objective(),"endpoint":""}
func sync_guidance() -> void:
 player.set_meta("suppress_destination_marker",stage=="chase")
 var clock: Node=get_parent().get_node("GameTimeSystem")
 clock.set_mission_daylight_locked(&"consignment_escort",stage in ["outbound","loading","chase","celebration"])
 player.get_node("UI/WorldMap").follow_story_destination()
func _process(delta: float) -> void:
 if not configured or get_tree().paused:return
 if stage=="dormant" and first.stage=="complete":
  stage="assigned"
  for poster in posters:poster.show()
  player.inventory.message_requested.emit("Arjun's wanted notices have circulated.");sync_guidance()
 if stage not in ["dormant","outbound","loading","chase","celebration"]:
  recognition_age+=delta
  if recognition_age>=1:recognition_age=0;recognise()
 if stage=="chase" and defeated.size()==7:begin_celebration()
 if stage=="celebration":finish_celebration(delta)
func witness_added(node: Node) -> void:
 if node is CollisionObject3D and is_instance_valid(cart) and cart.is_ancestor_of(node):register_cart_handle.call_deferred(node)
 if node is WitnessActor and get_parent().is_ancestor_of(node):register_witness.call_deferred(node)
 var script=node.get_script()
 if script!=null and script.resource_path in TRAFFIC_SCRIPTS and get_parent().is_ancestor_of(node):register_journey.call_deferred(node)
func register_cart_handle(handle: Variant) -> void:
 if not is_instance_valid(handle) or not handle is CollisionObject3D or not is_instance_valid(cart):return
 if handle.is_in_group("cart_boarding_handles") and cart.is_ancestor_of(handle) and not cart.boarding.cart_handle_rids.has(handle.get_rid()):cart.boarding.cart_handle_rids.append(handle.get_rid())
func register_journey(journey: Variant) -> void:
 if not is_instance_valid(journey) or not journey is Node:return
 var id:int=journey.get_instance_id()
 if not journey_ids.has(id):journey_ids[id]=true;traffic.append(journey)
# Deferred callbacks can carry a freed object across a Continue scene change.
# Validate the Variant before Godot attempts a typed Node argument conversion.
func register_witness(actor: Variant) -> void:
 if not is_instance_valid(actor) or not actor is Node3D or not actor.is_in_group("combat_actors"):return
 if is_ancestor_of(actor) or (is_instance_valid(first) and first.is_ancestor_of(actor)) or actor.get_meta("training_partner",false):return
 var family=get_parent().get_node_or_null("ChachaHouse")
 if family!=null and family.is_ancestor_of(actor):return
 var id: int=actor.get_instance_id()
 if observer_ids.has(id):return
 observer_ids[id]=true;observers.append(actor)
func recognise() -> void:
 var time: Node=get_parent().get_node("GameTimeSystem")
 var now: float=time.total_game_minutes
 var range_m:=4.0 if first.disguise else 18.0
 for observer in observers:
  if not is_instance_valid(observer):continue
  if observer.global_position.distance_squared_to(player.global_position)>range_m*range_m:continue
  var id:=Identity.id_for(get_parent(),observer)
  var prior=reported.get(id,-INF)
  if typeof(prior) in [TYPE_INT,TYPE_FLOAT] and now-float(prior)<30:continue
  if not Sight.sees(observer,player,range_m):continue
  reported[id]=now
  var witnesses: Array[String]=[id];get_parent().get_node("CombatEncounters").record_incident("wanted_rebel_sighting",player.global_position,witnesses,3)
  player.inventory.message_requested.emit("A witness recognised Arjun from a wanted notice and reported him.");return
func _input(event: InputEvent) -> void:
 if configured and stage=="celebration" and event.is_action_pressed("jump") and not event.is_echo():
  player.set_meta("cinematic_jump_block_until_released",true)
  if celebration_arrived:
   player.global_position=first.sites.prompts.briefing.global_position+Vector3(1,0,1)
   player.velocity=Vector3.ZERO
  celebration_age=celebration_duration;dialogue_voice.stop();dialogue_queue.clear();finish_celebration(0.0);get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
 if configured and stage=="loading" and event.is_action_pressed("interact"):
  start_chase();get_viewport().set_input_as_handled()
func start_chase() -> bool:
 if stage!="loading" or cart.rider!=player:return false
 dialogue_voice.stop();dialogue_queue.clear()
 cargo.show();stage="chase";chase_deaths=0;mission_skipped=false;route_index=0;holding_laps=0;speed=maxf(speed,6.0);wave=0;defeated.clear();player.set_meta("consignment_concealed",false);player.set_meta("consignment_rear_combat",true);player.set_meta("mission_wanted_level",2);player.collision_layer=8
 player.inventory.add_item("paper_cartridges",32);var gear=player.get_node("VisualRoot/CharacterVisual").equipment;gear.select_weapon(1);gear.stowed=true;gear._refresh()
 var gun=player.get_node("RifleCombat");gun.cancel_reload()
 if gun.rounds==0 and player.inventory.remove_item("paper_cartridges",1):gun.rounds=1;gun.loaded=true
 spawn_wave();sync_guidance();return true
func pursuit_lane(index:int) -> float:
 return 2.0 if index<=public_route_end else 3.7
func pursuit_offset(officer:int,index:int) -> float:
 return 0.0 if officer==2 else (-pursuit_lane(index) if officer%2==0 else pursuit_lane(index))
func heading(direction: Vector3) -> float:return atan2(-direction.x,-direction.z)
func route_probe(at:Vector3,index:int,direction:int,distance:float) -> Vector3:
 # A short bounded arc-distance probe keeps heading/pacing continuous at markers.
 for sample in 32:
  if stage=="chase" and defeated.size()<7:
   if direction>0 and index>holding_end:index=holding_start+1
   elif direction<0 and holding_laps>0 and index<holding_start:index=holding_end-1
  if index<0 or index>=route.size():return at
  var next:Vector3=route[index];var length:float=at.distance_to(next)
  if length>=distance and length>.00001:return at.move_toward(next,distance)
  distance-=length;at=next;index+=direction
 return at
func route_frame(at:Vector3,index:int,direction:int) -> Basis:
 var ahead:=route_probe(at,index+direction,direction,4.0)
 var behind:=route_probe(at,index,-direction,4.0)
 var tangent:Vector3=ahead-behind
 if tangent.length_squared()<.0001:return cart.global_basis
 return Basis.from_euler(Vector3(atan2(tangent.y,Vector2(tangent.x,tangent.z).length()),heading(tangent),0))
func _physics_process(delta: float) -> void:
 if not configured or get_tree().paused or stage not in ["outbound","chase"]:return
 if player.health<=0:stage="failed";release_convoy();return
 if not cart.can_move():stage="failed";release_convoy();player.inventory.message_requested.emit("The convoy horse has fallen. Return to Mangal to retry the consignment.");return
 if cart.rider!=player:stage="failed";release_convoy();return
 if not cart.boarding.transition.is_empty():return
 if stage=="outbound" and cart.get_node("RebelCoveredWagon").openness>.01:return
 cart.boarding.set_physics_process(false)
 var travel_direction:int=-1 if stage=="outbound" else 1
 var ahead:=route_probe(cart.global_position,route_index+travel_direction,travel_direction,8.0)-cart.global_position
 var behind:=cart.global_position-route_probe(cart.global_position,route_index,-travel_direction,8.0)
 var bend:float=ahead.angle_to(behind) if ahead.length_squared()>.001 and behind.length_squared()>.001 else 0.0
 var corner_speed:float=lerpf(10.0,3.5,smoothstep(.15,1.8,bend))
 speed=move_toward(speed,corner_speed,delta*5)
 var remaining:float=speed*delta
 # Consume the same frame's distance across waypoints: no pauses at each marker.
 for segment in 16:
  if stage=="chase" and route_index==holding_end and defeated.size()<7:
   route_index=holding_start;holding_laps+=1
  var next_index:int=route_index+(-1 if stage=="outbound" else 1)
  if next_index<0:stage="loading";speed=0;sync_guidance();return
  if next_index>=route.size():
   if defeated.size()==7:begin_celebration()
   return
  var goal:Vector3=route[next_index];var offset:Vector3=goal-cart.global_position
  var distance:float=offset.length()
  if distance<.001:route_index=next_index;continue
  var used:float=minf(remaining,distance);var step:Vector3=offset/distance*used
  var old_rotation:Vector3=cart.rotation
  cart.basis=route_frame(cart.global_position+step,route_index,travel_direction)
  if not cart.boarding._clearance_at(cart.global_position+step):cart.rotation=old_rotation;speed=0;break
  cart.global_position+=step;remaining-=used
  if distance-used<.001:route_index=next_index
  if remaining<.001:break
 cart.set_forward_motion(speed,delta);cart.boarding._sync_rider();cart.boarding.collision_body.force_update_transform()
 if stage=="chase":
  for i in pursuers.size():
   if not pursuers[i].visible or i in defeated:continue
   var aim_index:=maxi(0,route_index-2);var direction: Vector3=route[mini(route.size()-1,aim_index+1)]-route[aim_index];var side: Vector3=direction.cross(Vector3.UP).normalized()*pursuit_offset(i,aim_index)
   # Follow the moving cart, pacing down before closing the rear gap.
   # A fixed trailing point made mounts overshoot it and turn away while braking.
   pursuers[i].goal=cart.global_position+side
   var forward:Vector3=-cart.global_basis.z;forward.y=0;forward=forward.normalized()
   var gap:float=(cart.global_position-pursuers[i].global_position).dot(forward)
   pursuers[i].commanded_speed=clampf(speed+(gap-12.0)*.65,0.0,13.0)
 traffic_age+=delta
 if traffic_age>=1:traffic_age=0;scope_traffic()
func spawn_wave() -> void:
 if wave>=WAVE_ENDS.size():return
 var start:int=0 if wave==0 else WAVE_ENDS[wave-1]
 var end:int=WAVE_ENDS[wave]
 for i in range(start,end):
  var index:=maxi(0,route_index-6);var point:=route[index];var direction:=route[mini(index+1,route.size()-1)]-point;var side:=direction.cross(Vector3.UP).normalized()*pursuit_offset(i,index)
  if route_index<6:point-=direction.normalized()*float(6-route_index)*2
  pursuers[i].global_position=point+side+Vector3.UP*.08;pursuers[i].rotation.y=heading(direction);pursuers[i].goal=cart.global_position+side;pursuers[i].commanded_speed=13;riders[i].set_meta("police_engaged",true);enable_pursuer(i,true)
 wave+=1
 capture_chase_checkpoint()
func capture_chase_checkpoint() -> void:
 if stage!="chase" or wave<=0:return
 chase_checkpoint={"story":export_state(),"health":maxf(player.health,60.0),"ammo":player.inventory.get_item_count("paper_cartridges"),"rounds":player.get_node("RifleCombat").rounds}
func register_chase_death() -> void:
 if can_retry_chase():chase_deaths+=1
func can_skip_chase() -> bool:
 return can_retry_chase() and chase_deaths>=3
func skip_chase_after_deaths() -> void:
 if not can_skip_chase():return
 retry_chase_checkpoint()
 await get_tree().physics_frame
 if not is_inside_tree():return
 mission_skipped=true;defeated.assign([0,1,2,3,4,5,6])
 begin_celebration()
func can_retry_chase() -> bool:
 return not chase_checkpoint.is_empty() and stage in ["chase","failed"]
func retry_chase_checkpoint() -> void:
 if not can_retry_chase():return
 var checkpoint:Dictionary=chase_checkpoint.duplicate(true)
 var gun:Node=player.get_node("RifleCombat");gun.cancel_reload()
 player.health=float(checkpoint.health);player.set_meta("dead",false);player.velocity=Vector3.ZERO
 player.inventory.items["paper_cartridges"]=int(checkpoint.ammo);player.inventory.inventory_changed.emit()
 gun.rounds=int(checkpoint.rounds);gun.loaded=gun.rounds>0
 restore_state(checkpoint.story)
func pursuer_mount_fell(index: int) -> void:
 if stage!="chase" or index in defeated or wave<=0 or index>=WAVE_ENDS[wave-1]:return
 # A fatal mounted crash also brings down its officer. Route this through the
 # real vitality owner so the officer dies and reacts before the wave advances.
 var vitality: Node=riders[index].get_node("Vitality")
 if not vitality.dead:vitality.receive_hit(vitality.health+1.0,player,"mounted_fall")
func defeat(index: int) -> void:
 if stage!="chase" or index in defeated or wave<=0 or index>=WAVE_ENDS[wave-1] or not riders[index].get_node("Vitality").dead:return
 defeated.append(index);riders[index].firearm.hostile=false;pursuers[index].commanded_speed=0
 if riders[index].patrol_mount!=null:riders[index].begin_dismount(pursuers[index].global_position+Vector3(1,0,0))
 if wave<WAVE_ENDS.size() and defeated.size()==WAVE_ENDS[wave-1]:spawn_wave()
 if defeated.size()==7:begin_celebration()
func scope_traffic() -> void:
 for journey in traffic:
  if not is_instance_valid(journey):continue
  var host:=journey.get_parent() as Node3D
  if host==null:continue
  var near:=host.global_position.distance_squared_to(cart.global_position)<900
  # Let solid road users clear the convoy corridor before pausing ambient motion.
  # A pedestrian on a bend or a public cart at the yard must retain its exit.
  if near:
   for index in range(maxi(0,route_index-8),mini(route.size()-1,route_index+8)):
    var a:=Vector2(route[index].x,route[index].z);var b:=Vector2(route[index+1].x,route[index+1].z)
    var at:=Vector2(host.global_position.x,host.global_position.z)
    if Geometry2D.get_closest_point_to_segment(at,a,b).distance_squared_to(at)<25:
     near=false;break
  if near and not paused_traffic.has(journey):
   paused_traffic[journey]={"physics":journey.is_physics_processing(),"process":journey.is_processing()};journey.set_physics_process(false);journey.set_process(false)
   if host is WitnessActor:paused_traffic[journey]["travel_speed"]=host.travel_speed;host.travel_speed=0
   elif host.has_method("set_forward_motion"):host.set_forward_motion(0,0)
  elif not near and paused_traffic.has(journey):restore_journey(journey)
func restore_journey(journey: Node) -> void:
 var saved: Dictionary=paused_traffic[journey];paused_traffic.erase(journey)
 if is_instance_valid(journey):journey.set_physics_process(saved.physics);journey.set_process(saved.process)
 if is_instance_valid(journey) and saved.has("travel_speed"):
  var host=journey.get_parent()
  if is_instance_valid(host):host.travel_speed=float(saved.travel_speed)
func release_convoy() -> void:
 if has_node("CartPresentation") and get_node("CartPresentation").active:get_node("CartPresentation").release()
 cart.set_meta("consignment_locked",false);player.set_meta("consignment_rear_combat",false);player.set_meta("mission_wanted_level",0);player.set_meta("consignment_concealed",false);first.release_mount(cart)
 player.set_meta("cart_role","");player.global_position=cart.global_position+Vector3(3,.9,0)
 for journey in paused_traffic.keys():restore_journey(journey)
 for i in riders.size():riders[i].firearm.hostile=false;riders[i].set_meta("police_engaged",false);pursuers[i].commanded_speed=0
 sync_guidance()
func queue_voice(speaker: String, spoken: String) -> AudioStream:
 var key: String=(speaker+"\n"+spoken).sha256_text()
 var path: String="res://assets/audio/dialogue/"+key+".wav"
 if not ResourceLoader.exists(path):return null
 var stream:=load(path) as AudioStream
 if stream!=null:dialogue_queue.append(stream)
 return stream

func play_next_voice() -> void:
 if dialogue_queue.is_empty():return
 dialogue_voice.stream=dialogue_queue.pop_front()
 dialogue_voice.play()

func begin_celebration() -> bool:
 if stage!="chase" or defeated.size()!=7:return false
 var domains: Array[StringName]=[&"move",&"attack",&"interact"]
 cinematic_lease=service.acquire(self,domains)
 if cinematic_lease<0:return false
 dialogue_voice.stop();dialogue_queue.clear()
 if mission_skipped:
  celebration_fighter_voice=queue_voice("Fighter","The shipment has reached camp.")
  celebration_mangal_voice=queue_voice("Mangal Pandey","We survived, Arjun. There is more work ahead.")
 else:
  celebration_fighter_voice=queue_voice("Fighter","A brave escape. The shipment is safe.")
  celebration_mangal_voice=queue_voice("Mangal Pandey","Shabash, Arjun. You kept our people and supplies safe. Take these 200 rupees.")
 var errands := get_parent().get_node_or_null("ErrandSystem")
 if is_instance_valid(errands):
  for layer in errands.find_children("*","CanvasLayer",true,false):
   celebration_errand_layers[layer]=layer.visible
   layer.hide()
 celebration_duration=14.0
 var speech_length:=0.0
 for stream in dialogue_queue:speech_length+=stream.get_length()
 celebration_duration=maxf(celebration_duration,speech_length+2.0)
 prior_camera=get_viewport().get_camera_3d();prior_ui_visible=player.get_node("UI").visible;player.get_node("UI").hide();var gear=player.get_node("VisualRoot/CharacterVisual").equipment;prior_weapon_stowed=gear.stowed;gear.stowed=true;gear._refresh();stage="celebration";celebration_age=0;celebration_arrived=false;celebration_player_physics=player.is_physics_processing();player.set_physics_process(false);player.velocity=Vector3.ZERO;player.set_meta("story_cinematic",true);caption.show();return true
func finish_celebration(delta: float) -> void:
 if stage!="celebration":return
 celebration_age+=delta
 if celebration_age<1.0:curtain.color.a=smoothstep(0.0,1.0,celebration_age)
 elif celebration_age<2.0:curtain.color.a=1.0
 elif celebration_age<3.0:curtain.color.a=1.0-smoothstep(2.0,3.0,celebration_age)
 else:curtain.color.a=smoothstep(celebration_duration-2.0,celebration_duration,celebration_age)
 if celebration_age>=1.0 and not celebration_arrived:
  celebration_arrived=true
  cart.global_position=route[-1];release_convoy();player.global_position=camp_player_position()
  camp_discussion_positions()
  if delta>0.0:play_next_voice()
  var focus: Vector3=first.sites.prompts.briefing.global_position
  discussion_camera.global_position=focus+Vector3(-3,1.2,3.8);discussion_camera.look_at(focus);discussion_camera.make_current()
 if celebration_arrived:
  var mangal: Node3D=first.sites.get("mangal")
  var fighter_speaking := celebration_fighter_voice != null and dialogue_voice.playing and dialogue_voice.stream == celebration_fighter_voice
  var speaker: Node3D=companion if fighter_speaking and is_instance_valid(companion) else mangal
  preload("res://story/conversation_facing.gd").pair(player,speaker)
  var recorded_speaker: Node3D=null
  if dialogue_voice.playing and (fighter_speaking or (celebration_mangal_voice != null and dialogue_voice.stream == celebration_mangal_voice)):
   recorded_speaker=speaker
  update_celebration_face(recorded_speaker)
  if is_instance_valid(mangal):
   var mangal_speaking := celebration_mangal_voice != null and dialogue_voice.playing and dialogue_voice.stream == celebration_mangal_voice
   if mangal_speaking:
    mangal.set_meta("celebration_voice_phase",dialogue_voice.get_playback_position())
   else:
    mangal.remove_meta("celebration_voice_phase")
  if is_instance_valid(speaker):
   var shot: Dictionary=preload("res://story/dialogue_camera.gd").shot(player,speaker,false,false)
   discussion_camera.global_position=shot.position
   discussion_camera.fov=52
   discussion_camera.look_at(shot.target)
 caption.text="The fighters: The shipment has reached camp.\nMangal Pandey: We survived, Arjun. There is more work ahead." if mission_skipped else "The fighters: A brave escape. The shipment is safe.\nMangal Pandey: Shabash, Arjun. You kept our people and supplies safe. Take these 200 rupees."
 if celebration_age<celebration_duration:return
 if not paid:
  paid=true
  if not mission_skipped:player.inventory.add_item("rupees",200)
 if is_instance_valid(prior_camera) and not prior_camera.is_queued_for_deletion():prior_camera.make_current()
 player.get_node("UI").visible=prior_ui_visible
 var gear=player.get_node("VisualRoot/CharacterVisual").equipment;gear.stowed=prior_weapon_stowed;gear._refresh()
 preload("res://story/conversation_facing.gd").release(player)
 clear_celebration_mangal_cue()
 preload("res://story/conversation_facing.gd").release(first.sites.get("mangal"))
 dialogue_voice.stop();dialogue_queue.clear()
 stage="complete";caption.hide();curtain.color.a=0;player.set_meta("story_cinematic",false);player.set_physics_process(celebration_player_physics);player.velocity=Vector3.ZERO;service.release(cinematic_lease);cinematic_lease=-1
 for i in pursuers.size():enable_pursuer(i,false)
 sync_guidance()
func camp_player_position() -> Vector3:
 var at: Vector3=first.sites.prompts.briefing.global_position+Vector3(1,0,1)
 var layer: int=preload("res://world/suryagarh/tree_trunk_collision.gd").TERRAIN_SUPPORT_LAYER
 var ray:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*2.0,at-Vector3.UP*5.0,layer)
 var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
 if not hit.is_empty():
  var capsule: CapsuleShape3D=player.get_node("CollisionShape3D").shape
  at.y=hit.position.y+capsule.height*.5
 return at

func camp_discussion_positions() -> void:
 var at: Vector3=first.sites.prompts.briefing.global_position-Vector3.UP*.9
 for index in 2:
  var actor: Node3D=driver if index==0 else companion
  actor.riding_socket=null;actor.riding_cart=null;actor.driving=false;actor.body_collider.collision_layer=1;actor.global_position=at+Vector3(-3 if index==0 else 4,0,-1 if index==0 else -.5)
  actor.rotation.y=atan2(at.x-actor.global_position.x,at.z-actor.global_position.z);actor.foot_plant.clear()
func export_state() -> Dictionary:
 if not configured:return pending.duplicate(true) if restore_waiting else {"stage":"dormant"}
 var health: Array=[]
 for horse in pursuers:health.append(horse.vitality.health)
 var rider_state: Array=[]
 for rider in riders:rider_state.append({"health":rider.get_node("Vitality").health,"cartridges":rider.firearm.cartridges,"cooldown":rider.firearm.cooldown,"chambered":rider.firearm.chambered,"reloading":rider.firearm.reloading})
 return {"stage":stage,"route_index":route_index,"route_version":Route.Data.VERSION,"route_anchor":[cart.global_position.x,cart.global_position.z],"wave":wave,"wave_version":2,"defeated":defeated.duplicate(),"paid":paid,"mission_skipped":mission_skipped,"chase_deaths":chase_deaths,"horse_health":health,"riders":rider_state,"reported":reported.duplicate()}
func update_celebration_face(speaker: Node3D) -> void:
 if speaker != celebration_face_actor:
  if celebration_face != null:celebration_face.restore()
  celebration_face=null
  celebration_face_actor=speaker
  if is_instance_valid(speaker):
   celebration_face=preload("res://story/dialogue_expression.gd").new()
   celebration_face.configure(speaker)
 if celebration_face != null:
  var time := dialogue_voice.get_playback_position()
  var expression = preload("res://story/dialogue_expression.gd")
  celebration_face.apply(.18,0.0,0.0,expression.speech_weight(time,dialogue_voice.stream.get_length()),expression.blink_weight(time))

func clear_celebration_mangal_cue() -> void:
 update_celebration_face(null)
 for layer in celebration_errand_layers:
  if is_instance_valid(layer):layer.visible=celebration_errand_layers[layer]
 celebration_errand_layers.clear()
 celebration_mangal_voice=null
 celebration_fighter_voice=null
 preload("res://story/conversation_facing.gd").release(companion)
 if not is_instance_valid(first) or not is_instance_valid(first.sites):return
 var mangal: Node3D=first.sites.get("mangal")
 if is_instance_valid(mangal):mangal.remove_meta("celebration_voice_phase")

func restore_state(data: Dictionary) -> void:
 clear_celebration_mangal_cue()
 if is_instance_valid(dialogue_voice):dialogue_voice.stop()
 dialogue_queue.clear()
 if not configured:pending=data.duplicate(true);restore_waiting=true;return
 stage=str(data.get("stage","dormant"));if stage not in STAGES:stage="dormant"
 if stage=="celebration":stage="chase"
 route_index=clampi(int(data.get("route_index",0)),0,route.size()-1)
 if int(data.get("route_version",0))!=Route.Data.VERSION:
  var anchor:Vector2
  var saved_anchor:Variant=data.get("route_anchor",[])
  if saved_anchor is Array and saved_anchor.size()==2:
   anchor=Vector2(float(saved_anchor[0]),float(saved_anchor[1]))
  else:
   var legacy:=Route.legacy_samples()
   anchor=legacy[clampi(int(data.get("route_index",0)),0,legacy.size()-1)]
  route_index=Route.nearest_anchor(route,anchor)
 wave=clampi(int(data.get("wave",0)),0,3);paid=bool(data.get("paid",stage=="complete"));mission_skipped=bool(data.get("mission_skipped",false));chase_deaths=maxi(chase_deaths,int(data.get("chase_deaths",0)));defeated.clear()
 for value in data.get("defeated",[]):
  if typeof(value)==TYPE_INT and value>=0 and value<7 and value not in defeated:defeated.append(value)
 if int(data.get("wave_version",0))<2 and stage=="chase" and wave>=2:
  var migrated:Array[int]=[]
  for old_index in defeated:migrated.append(old_index if old_index<2 else old_index+1)
  if 2 not in migrated:migrated.append(2)
  defeated.assign(migrated)
 reported=data.get("reported",{}).duplicate() if data.get("reported",{}) is Dictionary else {}
 for poster in posters:poster.visible=stage!="dormant"
 cargo.visible=stage in ["chase","complete"]
 cart.visible=stage in ["outbound","loading","chase","complete"];driver.visible=cart.visible;companion.visible=cart.visible
 if stage in ["outbound","loading","chase"]:
  # Reset relocation-sensitive fall history before physics can observe the loaded pose.
  var safety=player.get_node_or_null("PlayerSafety")
  if safety!=null:safety.tracked_vehicle=null;safety.peak=-INF
  cart.boarding.falling_speed=0.0
  cart.seat_sockets.ConsignmentRearSeat.position.z=3.60 if stage=="chase" else 2.9
  cart.global_position=route[route_index];cart.basis=route_frame(cart.global_position,route_index,-1 if stage=="outbound" else 1)
  resume_convoy.call_deferred()
 for i in pursuers.size():
  install_pursuer(i)
  enable_pursuer(i,stage=="chase" and wave>0 and i<WAVE_ENDS[wave-1] and i not in defeated)
  if pursuers[i].visible:
   var index:=maxi(0,route_index-4);var at:=route[index];var direction:=route[mini(index+1,route.size()-1)]-at
   var side:=direction.cross(Vector3.UP).normalized()*pursuit_offset(i,index)
   if route_index<4:at-=direction.normalized()*float(4-route_index)*3
   pursuers[i].global_position=at+side+Vector3.UP*.08;pursuers[i].rotation.y=heading(direction)
   var health: Array=data.get("horse_health",[]);pursuers[i].vitality.health=clampf(float(health[i]),1,90) if i<health.size() else 90
   var records: Array=data.get("riders",[])
   if i<records.size() and records[i] is Dictionary:
    riders[i].get_node("Vitality").health=clampf(float(records[i].get("health",75)),1,75);riders[i].firearm.cartridges=clampi(int(records[i].get("cartridges",20)),0,100);riders[i].firearm.cooldown=maxf(0,float(records[i].get("cooldown",0)));riders[i].firearm.chambered=clampi(int(records[i].get("chambered",5)),0,5);riders[i].firearm.reloading=bool(records[i].get("reloading",false))
 if stage=="complete":camp_discussion_positions()
 sync_guidance()
 if stage=="chase":capture_chase_checkpoint()
func resume_convoy() -> void:
 var presentation=get_node_or_null("CartPresentation")
 if presentation!=null:presentation.battle_armed=false
 var safety=player.get_node_or_null("PlayerSafety")
 if safety!=null:safety.tracked_vehicle=null;safety.peak=-INF
 if cart.rider!=player:
  first.release_mount((player.get_meta("mounted_vehicle") if player.has_meta("mounted_vehicle") else null));player.global_position=cart.to_global(Vector3(0,.96,5.15));cart.board_at(player,"ConsignmentRearSeat","passenger")
 driver.riding_cart=cart;driver.riding_socket=cart.seat_sockets.DriverSeat;driver.driving=true;driver.body_collider.collision_layer=8
 companion.riding_cart=cart;companion.riding_socket=cart.get_node("ConsignmentCompanionSeat");companion.body_collider.collision_layer=8
 cart.set_meta("consignment_locked",true);player.set_meta("consignment_rear_combat",stage=="chase");player.set_meta("consignment_concealed",stage!="chase")
 if stage=="chase":
  player.collision_layer=8;player.set_meta("mission_wanted_level",2);var gear=player.get_node("VisualRoot/CharacterVisual").equipment;gear.select_weapon(1);gear.stowed=true;gear._refresh()
 cart.boarding._sync_rider();cart.boarding.collision_body.force_update_transform()
 cart.boarding.set_physics_process(true)
func _exit_tree() -> void:
 clear_celebration_mangal_cue()
 if is_instance_valid(player):player.set_meta("suppress_destination_marker",false)
 var clock=get_parent().get_node_or_null("GameTimeSystem")
 if is_instance_valid(clock):clock.set_mission_daylight_locked(&"consignment_escort",false)
 for body in road_supports:
  if is_instance_valid(body):preload("res://world/suryagarh/tree_trunk_collision.gd").unregister_terrain_support(self,body)
 for journey in paused_traffic.keys():restore_journey(journey)
 if is_instance_valid(service):service.release(cinematic_lease)
 if is_instance_valid(player):
  player.set_meta("consignment_rear_combat",false);player.set_meta("mission_wanted_level",0);player.set_meta("consignment_concealed",false)
  if stage=="celebration":
   player.set_meta("story_cinematic",false);player.set_physics_process(celebration_player_physics)
   if is_instance_valid(prior_camera) and not prior_camera.is_queued_for_deletion():prior_camera.make_current()
