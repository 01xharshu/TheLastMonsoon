extends Node3D
## Passenger fittings on the existing MPFB-driven village cart; no new human mesh.
const Actor = preload("res://characters/npcs/indian/indian_street_actor.gd")
var cart: Node3D
var lantern: Node3D
var lantern_pivot: Node3D
var caption: Label
var speech_remaining := 0.0
var speech_age := 0.0
var speech_duration := 4.2
var dialogue_voice: AudioStreamPlayer3D
var speech_started_ms := 0
var motion_age := 0.0
var last_inside := false
var clock:Node
var viewer:Node3D
var passengers:Array[Node]=[]

static func install(vehicle:Node3D) -> Node3D:
 var existing:=vehicle.get_node_or_null("PublicPassengerService")
 if existing!=null:return existing
 var service:=load("res://vehicles/public_passenger_service.gd").new() as Node3D
 service.name="PublicPassengerService";service.cart=vehicle;vehicle.add_child(service)
 return service

func _ready() -> void:
 process_priority=130
 dialogue_voice=AudioStreamPlayer3D.new();dialogue_voice.name="DriverVoice";dialogue_voice.max_distance=25;dialogue_voice.unit_size=6;add_child(dialogue_voice)
 _cache_world()
 cart.set_meta("public_passenger_service",true)
 cart.set_meta("booking_status","public")
 for part in cart.visual_root.get_children():
  var label:String=str(part.get_meta("part_label",part.name))
  if label.begins_with("ProduceBundle") or label.begins_with("LoadTie"):part.hide()
 var wood:=_build_open_body()
 for row in 2:
  var z:=2.40+row*.85
  for slat in [-1.0,0.0,1.0]:
   _box("SeatPlank",Vector3(0,1.46,z+slat*.175),Vector3(1.60,.14,.166),wood)
  for height in [1.65,1.91]:
   _box("BackrestRail",Vector3(0,height,z+.43),Vector3(1.60,.14,.065),wood)
  for side in [-1.0,1.0]:
   _box("BenchSupport",Vector3(side*.65,1.295,z),Vector3(.075,.28,.40),wood)
   _box("BackrestStile",Vector3(side*.69,1.71,z+.47),Vector3(.075,.54,.075),wood)
   var socket:=Node3D.new();socket.name="PublicPassenger_%d_%s"%[row,"Left" if side<0 else "Right"]
   socket.position=Vector3(side*.43,1.54,z);cart.visual_root.add_child(socket);cart.seat_sockets[socket.name]=socket
   var point:=preload("res://vehicles/cart_boarding_point.gd").new()
   point.name=socket.name+"Boarding";point.configure(cart,socket.name,"passenger");point.interaction_text="Board shared bullock cart";point.position=Vector3(side*1.1,1.45,z)
   var shape:=CollisionShape3D.new();var sphere:=SphereShape3D.new();sphere.radius=.18;shape.shape=sphere;point.add_child(shape);cart.add_child(point)
   point.add_to_group("cart_boarding_handles")
  _passenger(row,cart.seat_sockets["PublicPassenger_%d_Left"%row])
 var hull:CollisionShape3D=cart.boarding.clearance_shapes[0]
 hull.shape=hull.shape.duplicate();hull.shape.size=Vector3(1.8,1.95,2.5);hull.position=Vector3(0,2.05,2.75)
 _build_lantern()
 var captions:=CanvasLayer.new();captions.name="PassengerCaptions";captions.layer=8;add_child(captions)
 var canvas:=Control.new();canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);canvas.mouse_filter=Control.MOUSE_FILTER_IGNORE;captions.add_child(canvas)
 caption=Label.new();caption.name="DriverArrivalCaption";canvas.add_child(caption)
 caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);caption.anchor_top=.88
 caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;caption.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 caption.add_theme_font_size_override("font_size",24);caption.add_theme_color_override("font_shadow_color",Color.BLACK)
 caption.add_theme_constant_override("shadow_offset_x",2);caption.add_theme_constant_override("shadow_offset_y",2)
 caption.mouse_filter=Control.MOUSE_FILTER_IGNORE;caption.hide()

func _build_open_body() -> StandardMaterial3D:
 var wood:=StandardMaterial3D.new()
 wood.albedo_texture=preload("res://assets/architecture/materials/dark_wood_Diffuse.jpg")
 wood.roughness=.91
 var framing:=wood.duplicate() as StandardMaterial3D
 framing.albedo_color=Color(.68,.59,.49)
 for part in cart.visual_root.get_children():
  var label:=str(part.get_meta("part_label",part.name))
  if label.begins_with("SlattedSide") or label.begins_with("SideSlatGap") or label.begins_with("EndBoard"):
   part.hide()
  elif label.begins_with("PlankedDeck") or label.begins_with("DriverBench") or label.begins_with("DriverFootboard"):
   part.material_override=wood
 for side in [-1.0,1.0]:
  # Match the side transfer target, ahead of the wheel’s swept envelope.
  _box("PublicBoardingTreadLeft" if side<0 else "PublicBoardingTreadRight",Vector3(side*1.12,.55,1.40),Vector3(.38,.09,.44),wood)
  cart._beam("PublicTreadBrace",Vector3(side*1.12,.53,1.40),Vector3(side*.76,1.08,1.58),.055,framing)
  _box("LowerSideBoard",Vector3(side*.87,1.25,2.75),Vector3(.075,.15,2.45),wood)
  _box("HandRail",Vector3(side*.87,1.58,2.75),Vector3(.075,.09,2.46),wood)
  for z in [1.56,2.68,3.93]:
   _box("RailStake",Vector3(side*.87,1.40,z),Vector3(.09,.48,.09),framing)
 _box("RearSill",Vector3(0,1.28,3.94),Vector3(1.75,.22,.09),framing)
 return wood

func _cache_world() -> void:
 var world:Node=cart
 while world.get_parent()!=get_tree().root:world=world.get_parent()
 clock=world.get_node_or_null("GameTimeSystem")
 viewer=world.get_node_or_null("Player") as Node3D
 for journey in passengers:journey.viewer=viewer

func _box(label:String,at:Vector3,size:Vector3,material:Material) -> void:
 var node:=MeshInstance3D.new();node.name=label;var mesh:=BoxMesh.new();mesh.size=size;node.mesh=mesh;node.material_override=material;node.position=at;add_child(node)

func _passenger(index:int,socket:Node3D) -> void:
 var actor:=Actor.new();actor.name="PublicCartPassenger%d"%index;actor.movement_enabled=false
 actor.movement_profile=&"female" if index==0 else &"male"
 var source:="res://characters/npcs/street_residents/"+("female_01.glb" if index==0 else "male_02.glb")
 actor.set_meta("human_source",source);actor.add_child(preload("res://characters/human_scene.gd").instantiate(source));cart.visual_root.add_child(actor)
 var occupied:Array=cart.get_meta("npc_occupied_seats",[]);occupied.append(str(socket.name));cart.set_meta("npc_occupied_seats",occupied)
 var journey:=preload("res://world/suryagarh/city_cart_passenger.gd").new();journey.cart=cart;journey.actor=actor;journey.socket=socket;journey.viewer=viewer;actor.add_child(journey)
 passengers.append(journey)

func _build_lantern() -> void:
 var iron:=StandardMaterial3D.new();iron.albedo_color=Color(.12,.10,.08);iron.metallic=.6;iron.roughness=.65
 _box("LanternMountPlate",Vector3(.925,1.62,2.10),Vector3(.025,.14,.08),iron)
 _box("LanternMountUpright",Vector3(.925,1.71,2.10),Vector3(.018,.18,.018),iron)
 _box("LanternBracket",Vector3(1.04,1.79,2.10),Vector3(.25,.018,.018),iron)
 lantern_pivot=Node3D.new();lantern_pivot.name="ExteriorLanternHook";lantern_pivot.position=Vector3(1.15,1.77,2.10);add_child(lantern_pivot)
 lantern=preload("res://world/suryagarh/settlements/village_carried_lantern.gd").new()
 lantern.configure(lantern_pivot);lantern.name="ExteriorPassengerLantern";lantern.visible=true

func announce_arrival(place:String="Bhairavpur") -> void:
 speech_age=0; speech_duration=4.2; speech_remaining=speech_duration
 speech_started_ms=Time.get_ticks_msec()
 var text: String="We’re in %s. Mind your step!"%place
 caption.text="Driver: "+text
 dialogue_voice.stop()
 var key: String=("Driver\n"+text).sha256_text()
 var path: String="res://assets/audio/dialogue/"+key+".wav"
 if ResourceLoader.exists(path):
  var stream:=load(path) as AudioStream
  if stream!=null:
   dialogue_voice.stream=stream
   speech_duration=maxf(speech_duration,stream.get_length()+.2)
   speech_remaining=speech_duration
   if is_instance_valid(cart.driver):dialogue_voice.global_position=cart.driver.global_position+Vector3.UP*1.4
   dialogue_voice.play()
 caption.visible=not cart.get_meta("opening_cart_passage",false)

func cancel_announcement() -> void:
 speech_remaining=0;caption.hide();dialogue_voice.stop()
 if is_instance_valid(cart.driver):cart.driver.set_meta("driver_speaking",false)

func _process(delta:float) -> void:
 motion_age+=delta
 var cinematic:bool=cart.get_meta("opening_cart_passage",false)
 var inside:=Vector2(cart.global_position.x,cart.global_position.z).distance_to(Vector2(-250,230))<25
 if not cinematic and inside and not last_inside:announce_arrival()
 last_inside=inside
 if speech_remaining>0:
  speech_age=float(Time.get_ticks_msec()-speech_started_ms)/1000.0
  speech_remaining=maxf(0,speech_duration-speech_age)
 var camera:=get_viewport().get_camera_3d()
 caption.visible=speech_remaining>0 and not cinematic and camera!=null and camera.global_position.distance_squared_to(cart.global_position)<625
 var night:bool=cinematic or (is_instance_valid(clock) and (clock.current_hour<6 or clock.current_hour>=18))
 var nearby:bool=cinematic or (camera!=null and camera.global_position.distance_squared_to(cart.global_position)<6400)
 lantern.light.visible=night and nearby;lantern.get_node("OilFlame").visible=night
 lantern.light.light_energy=.65+.025*sin(motion_age*6.1)
 lantern_pivot.rotation.z=sin(motion_age*2.4)*.035*minf(absf(cart.boarding.speed),1.0)
 var driver:Node3D=cart.driver
 if not is_instance_valid(driver) or driver._skeleton==null:return
 driver.set_meta("driver_speaking",speech_remaining>0)
 if speech_remaining<=0:return
 var envelope:float=minf(1,speech_age/.35)*minf(1,speech_remaining/.35)
 var bone:int=driver._skeleton.find_bone("head")
 driver._skeleton.set_bone_pose_rotation(bone,driver._base_rotations["head"]*Quaternion(driver._yaw_axes["head"],-.75*envelope)*Quaternion(driver._pitch_axes["head"],sin(speech_age*8)*.025*envelope))
