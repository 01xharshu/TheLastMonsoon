extends Node3D
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
var cargo: Node3D
var cargo_seats: Array[Node3D]=[]
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
 officer=person("RevengeOfficer",parking,Vector3(-5,0,-6),"res://characters/npcs/british/official_man.glb","british")
 horse=preload("res://horses/stable_horse.gd").new();horse.name="SuperiorHorse";parking.add_child(horse);horse.position=Vector3(3,0,-4)
 coach=preload("res://vehicles/family_carriage_candidate.gd").new();coach.name="MangalCoveredCoach";coach.add_to_group("household_coach");add_child(coach)
 coach.set_meta("npc_occupied_seats",["CoachmanSeat"])
 coach.global_position=director.ground(fort.to_global(Vector3(0,0,66)))
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
 b.piece(cellar,"CellarFloor",Vector3(0,.1,0),Vector3(18,.2,14),b.stone)
 b.piece(cellar,"CellarRoof",Vector3(0,3.5,0),Vector3(18,.35,14),b.stone)
 for x in [-10,10]:b.piece(cellar,"EarthBank",Vector3(x,1.75,0),Vector3(2,3.5,15),b.stone)
 b.piece(cellar,"EarthenCap",Vector3(0,3.8,0),Vector3(21,.4,15),b.stone)
 var approach_start:=Vector3(0,.1,34);var approach_end:=Vector3(0,3.7,24)
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
 var lamp=OmniLight3D.new();lamp.position=Vector3(0,2.6,0);lamp.light_color=Color(1,.68,.35);lamp.omni_range=13;lamp.light_energy=1.5;cellar.add_child(lamp)
 mangal=person("MangalPandey",cellar,Vector3(-3,.2,2),"res://characters/npcs/motion/village_farmer/village_farmer_rigged_candidate.glb","indian")
 for i in 4:
  var member=person("Rebel%d"%i,cellar,Vector3(-6+i*4,.2,-2),"res://characters/npcs/households/merchant.glb","indian")
  trainees.append(member);equip(member)
 for i in 2:companions.append(person("RaidCompanion%d"%i,cellar,Vector3(-2+i*4,.2,4),"res://characters/npcs/households/merchant.glb","indian"));equip(companions[-1])
 prompt("briefing","Speak to Mangal Pandey",cellar,Vector3(-3,1.1,2))
 prompt("weapons","Inspect the stolen weapons",cellar,Vector3(5,1.1,-4))
 prompt("raid","Begin the cantonment weapons raid",cellar,Vector3(-3,1.1,3.5))
 for i in 8:
  var rifle=preload("res://environment/weapons/enfield_p53/weapon_enfield_p53_01.glb").instantiate();cellar.add_child(rifle);rifle.position=Vector3(3+i*.45,.8,-4);rifle.rotation.z=PI/2;rifle.scale=Vector3.ONE*.85
 b.piece(cellar,"CapturedWeaponsTable",Vector3(5,.7,-4),Vector3(5,.2,1.6),b.wood)
 target=StaticBody3D.new();target.name="TrainingTarget";cellar.add_child(target);target.position=Vector3(0,1.5,-5)
 var hit=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(1.2,1.5,.16);hit.shape=box;target.add_child(hit)
 var board=MeshInstance3D.new();var board_mesh=BoxMesh.new();board_mesh.size=box.size;board.mesh=board_mesh;board.material_override=b.wood;target.add_child(board)
 return_bay=site("HideoutDeliveryBay",fort.to_global(Vector3(13,0,64)))
 outline(return_bay,Vector2(6,12))
 # Independent two-storey magazine occupies a clear edge of the cantonment.
 raid=site("RaidMagazine",cantonment.to_global(Vector3(80,0,12)))
 b.piece(raid,"GroundFloor",Vector3(0,.1,0),Vector3(16,.2,20),b.stone)
 b.piece(raid,"SecondFloor",Vector3(0,3.6,-2),Vector3(16,.2,16),b.wood)
 b.piece(raid,"Roof",Vector3(0,7,0),Vector3(17,.2,21),b.tile)
 for x in [-8,8]:b.piece(raid,"MagazineSide",Vector3(x,3.5,0),Vector3(.35,7,20),b.plaster)
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
  var guard=person("MagazineGuard%d"%i,raid,Vector3(-2+i*2,0,4) if i<2 else Vector3(-3+(i-2)*6,3.7,-3),"res://characters/npcs/british/private_man.glb","british")
  guard.set_meta("rebellion_guard",true);guards.append(guard);equip(guard)
  prompt("uniform%d"%i,"Take the sentry’s uniform",guard,Vector3(0,.7,0))
 set_enabled(false)
func site(label: String,at: Vector3) -> Node3D:
 var node=Node3D.new();node.name=label;add_child(node);node.global_position=director.ground(at);return node
func person(label: String,parent: Node3D,at: Vector3,path: String,faction: String) -> Node3D:
 var actor=Actor.new();actor.name=label;actor.movement_enabled=false;actor.set_meta("combat_faction",faction);actor.set_meta("rebellion_guard",label.begins_with("MagazineGuard"));actor.set_meta("human_source",path);actor.add_child(Human.instantiate(path));parent.add_child(actor);actor.position=at;return actor
func equip(actor: Node3D) -> void:
 var gun=preload("res://environment/weapons/enfield_p53/weapon_enfield_p53_01.glb").instantiate();gun.name="RebelEnfield";actor.add_child(gun);gun.position=Vector3(.2,1,-.2);gun.rotation.z=.2;gun.scale=Vector3.ONE*.85
 # Non-human ammunition bandolier is worn over the retained complete MPFB body.
 var strap=b.piece(actor,"AmmunitionBelt",Vector3(0,1.15,.19),Vector3(.09,.66,.035),b.wood,false);strap.rotation.z=.45
 for i in 8:b.piece(strap,"Cartridge",Vector3(0,-.28+i*.08,.035),Vector3(.045,.05,.05),b.tile,false)
func prompt(id: String,label: String,parent: Node3D,at: Vector3) -> void:
 var node=Prompt.new();node.action_id=id;node.director=director;node.interaction_text=label;parent.add_child(node);node.position=at;prompts[id]=node
func outline(parent: Node3D,size: Vector2) -> void:
 var gold=b.material(Color(.9,.73,.2))
 for x in [-size.x*.5,size.x*.5]:b.piece(parent,"ParkingOutline",Vector3(x,.03,0),Vector3(.06,.025,size.y),gold,false)
 for z in [-size.y*.5,size.y*.5]:b.piece(parent,"ParkingOutline",Vector3(0,.03,z),Vector3(size.x,.025,.06),gold,false)
func set_enabled(enabled: bool) -> void:
 for actor in [officer,mangal]+companions+guards+trainees:
  actor.visible=enabled;actor.set_process(enabled);actor.get_node("BodyCollider").collision_layer=1 if enabled else 0;actor.get_node("Vitality").hit_body.collision_layer=8 if enabled else 0
 horse.visible=enabled;horse.set_physics_process(enabled)
 coach.visible=enabled;goods.visible=enabled;return_bay.visible=false
