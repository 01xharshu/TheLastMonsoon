extends Node3D
const GATE_COACH_PARK:=Vector3(21.5,0,94.0)
## Mission-owned additions. Existing MPFB people, vehicle systems and world terrain.
const Builder=preload("res://world/suryagarh/settlements/settlement_builder.gd")
const Human=preload("res://characters/human_scene.gd")
const Actor=preload("res://story/rebellion_actor.gd")
const Prompt=preload("res://story/rebellion_prompt.gd")
var b=Builder.new()
var director: Node
var station: Node3D
var fort: Node3D
var cantonment: Node3D
var parking: Node3D
var tree: Node3D
var cellar: Node3D
var raid: Node3D
var officer: Node3D
var horse: CharacterBody3D
var coach: Node3D
var goods: Node3D
var mangal: Node3D
var companions: Array[Node3D]=[]
var guards: Array[Node3D]=[]
var trainees: Array[Node3D]=[]
var bundles: Array[Node3D]=[]
var prompts: Dictionary={}
var return_bay: Node3D
var rope: MeshInstance3D
var target: StaticBody3D
var rack_rifle:Node3D
var firing_line: Node3D
var cargo: Node3D
var cargo_seats: Array[Node3D]=[]
var shared_officer=false
var parking_material: StandardMaterial3D
func _exit_tree()->void:
 if is_instance_valid(b):b.free()
func configure(owner: Node) -> void:
 director=owner
 b.wood=b.material(Color(.28,.16,.08));b.stone=b.material(Color(.39,.34,.27));b.plaster=b.material(Color(.70,.65,.52));b.tile=b.material(Color(.37,.21,.14))
 station=director.inquiry.station;fort=director.world.get_node("OldFort")
 cantonment=director.world.find_child("BritishCantonment",true,false)
 parking=site("SuperiorParking",station.to_global(Vector3(27,0,15)))
 b.piece(parking,"GravelStanding",Vector3(0,-.04,0),Vector3(12,.08,16),b.stone)
 for x in [-6,6]:b.piece(parking,"ParkingKerb",Vector3(x,.08,0),Vector3(.18,.16,16),b.stone)
 tree=site("AmbushTree",station.to_global(Vector3(19,0,23)))
 var foliage=load("res://environment/forest/assets/small_tree_lod0.glb").instantiate();tree.add_child(foliage)
 for mesh in foliage.find_children("*","GeometryInstance3D",true,false):mesh.visibility_range_end=130
 var trunk=StaticBody3D.new();tree.add_child(trunk);var shape=CollisionShape3D.new();var cylinder=CylinderShape3D.new();cylinder.radius=.45;cylinder.height=5;shape.shape=cylinder;shape.position.y=2.5;trunk.add_child(shape)
 if director.inquiry.get("officials") is Array and not director.inquiry.officials.is_empty():
  officer=director.inquiry.officials[0];shared_officer=true
 else:officer=person("RevengeOfficer",parking,Vector3(-5,0,-6),"res://characters/npcs/british/official_man.glb","british")
 horse=preload("res://horses/stable_horse.gd").new();horse.name="SuperiorHorse";parking.add_child(horse);horse.position=Vector3(3,0,-4)
 coach=preload("res://vehicles/family_carriage_candidate.gd").new();coach.name="MangalCoveredCoach";coach.add_to_group("household_coach");add_child(coach)
 coach.set_meta("npc_occupied_seats",["CoachmanSeat"])
 var coach_parking:=GATE_COACH_PARK if fort.get("embedded_in_world")==true else Vector3(0,0,66)
 coach.global_position=director.ground(fort.to_global(coach_parking))
 goods=preload("res://vehicles/horse_cart_candidate.gd").new();goods.variant=1;goods.name="RebellionGoodsCart";add_child(goods)
 goods.set_meta("player_owned",true)
 goods.global_position=director.ground(fort.to_global(Vector3(13,0,63)));goods.add_to_group("live_travel_carts")
 cargo=Node3D.new();cargo.name="CapturedRifleCargo";goods.add_child(cargo);cargo.hide()
 for i in 12:
  var rifle=preload("res://environment/weapons/enfield_p53/weapon_enfield_p53_01.glb").instantiate();cargo.add_child(rifle);rifle.position=Vector3(-.4+(i%3)*.4,1.3+float(i/3)*.08,2.3);rifle.rotation.y=PI/2;rifle.scale=Vector3.ONE*.85
 for side in [-1,1]:
  var socket:=Node3D.new();goods.add_child(socket);socket.position=Vector3(side*.65,1.35,3.1);cargo_seats.append(socket)
 # A covered vaulted magazine reached by a descending passage; top is fort ground.
 cellar=site("RebelUndercroft",fort.to_global(Vector3(-56,0,48)))
 # Extend the foundation down to terrain where the hillside falls away.
 var foundation_base:=0.0
 for x in [-9.0,0.0,9.0]:
  for z in [-7.0,0.0,7.0]:
   var sample:=cellar.to_global(Vector3(x,0,z))
   var terrain_height: Vector3=director.ground(sample)
   foundation_base=minf(foundation_base,cellar.to_local(terrain_height).y-.55)
 b.piece(cellar,"BuriedFoundation",Vector3(0,foundation_base*.5,0),Vector3(18,-foundation_base,14),b.stone)
 b.piece(cellar,"CellarFloor",Vector3(0,.1,0),Vector3(18,.2,14),b.stone)
 b.piece(cellar,"CellarRoof",Vector3(0,3.5,0),Vector3(18,.35,14),b.stone)
 for x in [-10,10]:b.piece(cellar,"EarthBank",Vector3(x,1.75,0),Vector3(2,3.5,15),b.stone)
 b.piece(cellar,"EarthenCap",Vector3(0,3.8,0),Vector3(21,.4,15),b.stone)
 var approach_start: Vector3=cellar.to_local(director.ground(cellar.to_global(Vector3(0,0,34))));var approach_end:=Vector3(0,3.7,24)
 var approach:=b.piece(cellar,"TerraceApproach",(approach_start+approach_end)*.5,Vector3(4,.18,approach_start.distance_to(approach_end)),b.stone);approach.rotation.x=-atan2(approach_end.y-approach_start.y,approach_end.z-approach_start.z)
 for x in [-9,9]:b.piece(cellar,"CellarWall",Vector3(x,1.8,0),Vector3(.4,3.6,14),b.stone)
 b.piece(cellar,"RearWall",Vector3(0,1.8,-7),Vector3(18,3.6,.4),b.stone)
 for x in [-5.4,5.4]:b.piece(cellar,"EntrancePier",Vector3(x,1.8,7),Vector3(7.2,3.6,.4),b.stone)
 # Stair/ramp connects the upper terrace to a lower chamber without jump-only gaps.
 var entry=Vector3(0,3.7,18);var end=Vector3(0,.2,7)
 var ramp=b.piece(cellar,"DescendingPassage",(entry+end)*.5,Vector3(3,.18,entry.distance_to(end)),b.stone);ramp.rotation.x=-atan2(end.y-entry.y,end.z-entry.z)
 b.piece(cellar,"UpperTerrace",Vector3(0,3.6,21),Vector3(8,.2,6),b.stone)
 for side in [-1,1]:
  b.piece(cellar,"PassageWall",Vector3(side*1.7,3.1,12.5),Vector3(.3,3.7,11),b.stone)
 # Ground chipped masonry along the verge outside the terrace approach.
 var chipped := preload("res://world/ruined_fort/fort_modules.gd").chipped_stone(1857)
 for index in 18:
  var side := -1.0 if index % 2 == 0 else 1.0
  var verge := Vector3(side * (2.5 + float(index % 3) * .35), 0, 25 + float(index) * .48)
  var terrain_point: Vector3 = director.ground(cellar.to_global(verge))
  var stone := MeshInstance3D.new()
  stone.name = "FallenApproachMasonry"
  stone.mesh = chipped
  stone.material_override = b.stone
  stone.position = cellar.to_local(terrain_point) + Vector3.UP * .16
  stone.scale = Vector3(.55, .32, .42)
  stone.rotation = Vector3(.12 * index, .73 * index, .09 * index)
  stone.visibility_range_end = 100
  cellar.add_child(stone)
 preload("res://story/rebel_hideout_environment.gd").build(b,cellar)
 var courtyard=site("RebelTrainingCourtyard",fort.to_global(Vector3(0,0,0)))
 firing_line=site("CourtyardFiringLine",fort.to_global(Vector3(0,0,10)))
 var lamp=OmniLight3D.new();lamp.position=Vector3(0,2.6,0);lamp.light_color=Color(1,.68,.35);lamp.omni_range=13;lamp.light_energy=1.5;cellar.add_child(lamp)
 mangal=person("MangalPandey",cellar,Vector3(-3,.2,2),"res://characters/npcs/mangal_rebels/mangal_rebel.glb","indian")
 for i in 4:
  await get_tree().process_frame
  var at:Vector3=director.ground(fort.to_global(Vector3(-8+i*5.4,0,13)))
  var member=person("Rebel%d"%i,courtyard,courtyard.to_local(at),"res://characters/npcs/mangal_rebels/mangal_rebel.glb","indian")
  trainees.append(member);equip(member)
 for i in 2:
  await get_tree().process_frame
  companions.append(person("RaidCompanion%d"%i,cellar,Vector3(-2+i*4,.2,4),"res://characters/npcs/mangal_rebels/mangal_rebel.glb","indian"));equip(companions[-1])
 prompt("briefing","Speak to Mangal Pandey",cellar,Vector3(-3,1.1,2))
 var rack:=Node3D.new()
 rack.name="CapturedRifleRack"
 rack.position=Vector3(5,.2,-5.45)
 cellar.add_child(rack)
 var iron:=StandardMaterial3D.new()
 iron.albedo_color=Color(.16,.145,.13)
 iron.roughness=.91
 iron.metallic=.72
 for side in [-1.0,1.0]:
  b.piece(rack,"WroughtIronUpright",Vector3(side*1.65,.85,0),Vector3(.075,1.7,.075),iron,false)
  b.piece(rack,"RackFoot",Vector3(side*1.65,.05,0),Vector3(.14,.1,.58),iron,false)
 b.piece(rack,"StockCradle",Vector3(0,.16,0),Vector3(3.4,.13,.36),b.wood,true)
 b.piece(rack,"IronBarrelRail",Vector3(0,1.34,-.07),Vector3(3.4,.085,.075),iron,false)
 for i in 8:
  var x:float=(float(i)-3.5)*.39
  for side in [-1.0,1.0]:
   b.piece(rack,"BarrelRest",Vector3(x+side*.075,1.33,.025),Vector3(.032,.075,.21),iron,false)
  var gun:Node3D=preload("res://environment/weapons/enfield_p53/weapon_enfield_p53_01.glb").instantiate()
  rack.add_child(gun)
  gun.position=Vector3(x,.43,.09)
  gun.rotation.z=PI*.5
  gun.scale=Vector3.ONE*.86
  if i==4:rack_rifle=gun
 prompt("weapons","Take an Enfield from the rack",rack,Vector3(.2,.92,.26))
 prompt("raid","Begin the cantonment weapons raid",cellar,Vector3(-3,1.1,3.5))
 target=StaticBody3D.new()
 target.name="TrainingTarget"
 courtyard.add_child(target)
 target.global_position=director.ground(fort.to_global(Vector3(0,0,-14)))+Vector3.UP*1.35
 var hit:=CollisionShape3D.new()
 var round_shape:=CylinderShape3D.new()
 round_shape.radius=.64
 round_shape.height=.29
 hit.shape=round_shape
 hit.rotation.x=PI*.5
 target.add_child(hit)
 var bark:=StandardMaterial3D.new()
 bark.albedo_color=Color(.31,.20,.11)
 bark.roughness=.91
 bark.albedo_texture=preload("res://assets/architecture/materials/dark_wood_Diffuse.jpg")
 var log_face:=CylinderMesh.new()
 log_face.top_radius=.64
 log_face.bottom_radius=.64
 log_face.height=.28
 var log_visual:=MeshInstance3D.new()
 log_visual.name="SplitLogRound"
 log_visual.mesh=log_face
 log_visual.rotation.x=PI*.5
 log_visual.material_override=bark
 target.add_child(log_visual)
 var paint_dark:=StandardMaterial3D.new()
 paint_dark.albedo_color=Color(.27,.16,.095)
 paint_dark.roughness=.91
 var paint_light:=StandardMaterial3D.new()
 paint_light.albedo_color=Color(.72,.59,.39)
 paint_light.roughness=.91
 for ring in 5:
  var disc:=CylinderMesh.new()
  disc.top_radius=.52-float(ring)*.095
  disc.bottom_radius=disc.top_radius
  disc.height=.008
  var mark:=MeshInstance3D.new()
  mark.name="PaintedTargetCircle"
  mark.mesh=disc
  mark.rotation.x=PI*.5
  mark.position.z=.143+float(ring)*.002
  mark.material_override=paint_light if ring%2==0 else paint_dark
  target.add_child(mark)
 for side in [-1.0,1.0]:
  b.piece(target,"TargetStanchion",Vector3(side*.48,-.64,-.1),Vector3(.12,1.46,.15),b.wood,false)
 for i in trainees.size():trainees[i].practice_target=target.global_position;trainees[i].practice_clock=i*2.5
 var daily=preload("res://story/hideout_daily_life.gd").new();daily.setup(self);cellar.add_child(daily)
 return_bay=site("HideoutDeliveryBay",fort.to_global(Vector3(13,0,64)))
 outline(return_bay,Vector2(6,12))
 # Independent two-storey magazine occupies a clear edge of the cantonment.
 raid=site("RaidMagazine",cantonment.to_global(Vector3(80,0,12)))
 b.piece(raid,"GroundFloor",Vector3(0,.1,0),Vector3(16,.2,20),b.stone)
 ground_ramp(raid,Vector3(0,.2,10.1),Vector3(0,0,17))
 b.piece(raid,"SecondFloorLeft",Vector3(-7.15,3.6,-2),Vector3(1.7,.2,16),b.wood)
 b.piece(raid,"SecondFloorRight",Vector3(2.15,3.6,-2),Vector3(11.7,.2,16),b.wood)
 b.piece(raid,"SecondFloorRear",Vector3(-5,3.6,-4.4),Vector3(2.6,.2,11.2),b.wood)
 b.piece(raid,"Roof",Vector3(0,7,0),Vector3(17,.2,21),b.tile)
 for side in [-1,1]:
  b.piece(raid,"SideLowerWall",Vector3(side*8,2.45,0),Vector3(.35,4.9,20),b.plaster)
  b.piece(raid,"SideHeader",Vector3(side*8,6.75,0),Vector3(.35,.5,20),b.plaster)
  for z in [-9.5,-5.5,-1.5,2.5,6.5,9.5]:b.piece(raid,"WindowPier",Vector3(side*8,5.7,z),Vector3(.35,1.6,1.2),b.plaster)
  for z in [-7.5,-3.5,.5,4.5,8.5]:
   for edge in [-1,1]:b.piece(raid,"WindowJamb",Vector3(side*8,5.7,z+edge*1.35),Vector3(.45,1.65,.12),b.wood)
   b.piece(raid,"WindowSill",Vector3(side*8,4.93,z),Vector3(.6,.12,2.8),b.stone)
   for edge in [-1,1]:b.piece(raid,"OpenShutter",Vector3(side*8.25,5.7,z+edge*1.6),Vector3(.12,1.5,.55),b.wood,false)
  for z in [-10,10]:b.piece(raid,"CornerQuoin",Vector3(side*8,3.45,z),Vector3(.6,6.9,.6),b.stone)
 for y in [.35,3.45,6.95]:b.piece(raid,"FacadeCourse",Vector3(0,y,10.25),Vector3(16.5,.16,.35),b.stone)

 
 for x in [-5,5]:b.piece(raid,"FrontPier",Vector3(x,3.5,10),Vector3(6,7,.35),b.plaster)
 b.piece(raid,"FrontHeader",Vector3(0,5,10),Vector3(4,4,.35),b.plaster)
 # Rear escape window has a real opening and no invisible full-wall collider.
 for x in [-5,5]:b.piece(raid,"RearPier",Vector3(x,3.5,-10),Vector3(6,7,.35),b.plaster)
 b.piece(raid,"WindowSill",Vector3(0,2.05,-10),Vector3(4,4.1,.35),b.plaster)
 b.piece(raid,"WindowHeader",Vector3(0,6.35,-10),Vector3(4,1.3,.35),b.plaster)
 for i in 24:b.piece(raid,"Stair",Vector3(-5,(i+1)*.15,8.5-i*.32),Vector3(2.2,.15,.38),b.stone)
 for x in [-6.2,-3.8]:b.piece(raid,"StairRail",Vector3(x,2.35,4.8),Vector3(.1,1,8),b.wood,false).rotation.x=.438
 for i in 4:
  var bundle=Node3D.new();bundle.name="WeaponBundle%d"%i;raid.add_child(bundle);bundle.position=Vector3(-5+i*3,3.7,-6);bundles.append(bundle)
  b.piece(bundle,"WeaponCrate",Vector3(0,.25,0),Vector3(2,.5,1),b.wood)
  for j in 3:
   var gun=preload("res://environment/weapons/enfield_p53/weapon_enfield_p53_01.glb").instantiate();bundle.add_child(gun);gun.position=Vector3(-.4+j*.4,.6,0);gun.scale=Vector3.ONE*.85;gun.rotation.z=PI/2
  prompt("bundle%d"%i,"Collect rifle bundle · 3 weapons",bundle,Vector3(0,1,0))
 prompt("rope","Rig the rope escape",raid,Vector3(0,4.6,-9.4))
 b.piece(raid,"BoundaryWall",Vector3(0,1.5,-22),Vector3(24,3,.6),b.stone)
 b.piece(raid,"RopeLanding",Vector3(0,2.9,-22),Vector3(3,.2,2),b.stone)
 for i in 20:b.piece(raid,"WallDescent",Vector3(0,2.85-i*.15,-23-i*.28),Vector3(2.4,.15,.34),b.stone)
 rope=MeshInstance3D.new();rope.name="EscapeRope";raid.add_child(rope);var line=CylinderMesh.new();line.top_radius=.025;line.bottom_radius=.025;var start=Vector3(0,5.5,-10);var finish=Vector3(0,4.5,-22);line.height=start.distance_to(finish);rope.mesh=line;rope.position=(start+finish)*.5;rope.quaternion=Quaternion(Vector3.UP,(finish-start).normalized());rope.material_override=b.wood;rope.hide()
 for i in 4:
  await get_tree().process_frame
  var guard=person("MagazineGuard%d"%i,raid,Vector3(-2+i*2,0,4) if i<2 else Vector3(-3+(i-2)*6,3.7,-3),"res://characters/npcs/british/private_man.glb","british")
  guard.set_meta("rebellion_guard",true);guards.append(guard);equip(guard)
  prompt("uniform%d"%i,"Take the sentry’s uniform",guard,Vector3(0,.7,0))
 for mesh in find_children("*","GeometryInstance3D",true,false):mesh.visibility_range_end=180;mesh.visibility_range_end_margin=15
 set_enabled(false)
func site(label: String,at: Vector3) -> Node3D:
 var node=Node3D.new();node.name=label;add_child(node);node.global_position=director.ground(at)
 if label in ["RaidMagazine","RebelUndercroft","SuperiorParking"]:
  var half=Vector2(8,10) if label=="RaidMagazine" else Vector2(10.5,7.5) if label=="RebelUndercroft" else Vector2(6,8)
  for x in [-half.x,half.x]:
   for z in [-half.y,half.y]:node.global_position.y=maxf(node.global_position.y,director.ground(at+Vector3(x,0,z)).y)
 return node
func person(label: String,parent: Node3D,at: Vector3,path: String,faction: String) -> Node3D:
 var actor=Actor.new();actor.name=label;actor.viewer=director.player;actor.movement_enabled=false;actor.set_meta("combat_faction",faction);actor.set_meta("external_combat_motion",true);actor.set_meta("rebellion_guard",label.begins_with("MagazineGuard"));actor.set_meta("human_source",path);actor.set_meta("rebel_travel","/mangal_rebels/" in path);actor.set_meta("mangal_leader",label=="MangalPandey");actor.set_meta("population_expansion_exempt",parent==cellar or label.begins_with("Rebel"));actor.add_child(Human.instantiate(path));parent.add_child(actor);actor.position=at;return actor
func equip(actor: Node3D) -> void:
 var gun=preload("res://environment/weapons/enfield_p53/weapon_enfield_p53_01.glb").instantiate();gun.name="RebelEnfield";actor.add_child(gun);actor.held_rifle=gun;gun.position=Vector3(.2,1,-.2);gun.rotation.z=.2;gun.scale=Vector3.ONE*.85
 # Non-human ammunition bandolier is worn over the retained complete MPFB body.
 var strap=b.piece(actor,"AmmunitionBelt",Vector3(0,1.15,.19),Vector3(.09,.66,.035),b.wood,false);strap.rotation.z=.45
 var socket:=BoneAttachment3D.new();socket.bone_name="spine_02";actor._skeleton.add_child(socket)
 var placement: Transform3D=actor._skeleton.global_transform.affine_inverse()*strap.global_transform
 strap.reparent(socket,false);strap.transform=actor._skeleton.get_bone_global_rest(actor._skeleton.find_bone("spine_02")).affine_inverse()*placement
 for i in 8:b.piece(strap,"Cartridge",Vector3(0,-.28+i*.08,.035),Vector3(.045,.05,.05),b.tile,false)
func prompt(id: String,label: String,parent: Node3D,at: Vector3) -> void:
 var node=Prompt.new();node.action_id=id;node.director=director;node.interaction_text=label;parent.add_child(node);node.position=at;prompts[id]=node
 if id.begins_with("bundle"):node.hold_duration=1.0;node.interaction_pose="low_reach"
func ground_ramp(parent: Node3D,start: Vector3,end: Vector3) -> void:
 end=parent.to_local(director.ground(parent.to_global(end)))
 var ramp=b.piece(parent,"GroundAccessRamp",(start+end)*.5,Vector3(3.2,.18,start.distance_to(end)),b.stone)
 ramp.rotation.x=-atan2(end.y-start.y,end.z-start.z)
func outline(parent: Node3D,size: Vector2) -> void:
 var gold=StandardMaterial3D.new();gold.albedo_color=Color(.9,.73,.2);gold.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;gold.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;parking_material=gold
 for x in [-size.x*.5,size.x*.5]:b.piece(parent,"ParkingOutline",Vector3(x,.03,0),Vector3(.06,.025,size.y),gold,false)
 for z in [-size.y*.5,size.y*.5]:b.piece(parent,"ParkingOutline",Vector3(0,.03,z),Vector3(size.x,.025,.06),gold,false)
func set_enabled(enabled: bool) -> void:
 for actor in [officer,mangal]+companions+guards+trainees:
  if actor==officer and shared_officer and not enabled:continue
  actor.visible=enabled;actor.set_process(enabled);actor.get_node("BodyCollider").collision_layer=1 if enabled else 0;actor.get_node("Vitality").hit_body.collision_layer=8 if enabled else 0
 horse.visible=enabled;horse.set_physics_process(enabled)
 coach.visible=enabled;goods.visible=enabled;return_bay.visible=false
