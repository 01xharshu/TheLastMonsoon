extends Node3D
## Modest fictional courtyard home at the west end of the existing village spine.
const Builder = preload("res://world/suryagarh/settlements/settlement_builder.gd")
const Rack = preload("res://world/suryagarh/settlements/chacha_rack.gd")
var b = Builder.new()
func _ready() -> void:
	name = "ChachaHouse"
	position = Vector3(-425,7.2,214)
	add_to_group("chacha_house")
	b.wood=b.material(Color(.27,.16,.09));b.iron=b.material(Color(.15,.16,.15))
	var lime: Material=preload("res://world/suryagarh/settlements/arjun_house.gd").new().surface(Color(.72,.65,.50),0)
	var earth: Material=preload("res://world/suryagarh/settlements/arjun_house.gd").new().surface(Color(.42,.32,.22),3)
	p("Floor",Vector3(0,.1,0),Vector3(12,.2,10),earth)
	# South doorway opens onto the village spine at Z230.
	for x in [-3.65,3.65]:
		p("WindowSillWall",Vector3(x,.7,5),Vector3(4.7,1,.3),lime)
		p("WindowHeadWall",Vector3(x,2.7,5),Vector3(4.7,1,.3),lime)
		for dx in [-1.8,1.8]:p("WindowPier",Vector3(x+dx,1.7,5),Vector3(1.1,1,.3),lime)
		for dx in [-1.22,1.22]:p("WindowJamb",Vector3(x+dx,1.7,5.16),Vector3(.09,1.05,.13),b.wood,false)
		for y in [1.18,2.22]:p("WindowRail",Vector3(x,y,5.16),Vector3(2.5,.08,.13),b.wood,false)
		p("WindowShade",Vector3(x,2.28,5.4),Vector3(2.7,.1,.9),b.wood,false)
	p("DoorHead",Vector3(0,2.95,5),Vector3(2.6,.5,.3),b.wood)
	p("EntranceThreshold",Vector3(0,.08,5.25),Vector3(2.6,.16,.4),earth)
	var door=preload("res://objects/hinged_door.gd").new()
	door.name="EntranceDoor";door.width=2.6;door.height=2.45
	door.night_lock=false;door.outside_latch_access=true;door.label_name="Chacha’s door"
	door.position=Vector3(-1.3,.2,5.13);door.build(b.wood);add_child(door)
	p("BackWall",Vector3(0,1.7,-5),Vector3(12,3,.3),lime)
	for x in [-6,6]: p("SideWall",Vector3(x,1.7,0),Vector3(.3,3,10),lime)
	# Central passage, sleeping room west, kitchen east; rear weapons room.
	for x in [-2,2]:
		for z in [-1.9,3.9]: p("RoomPartition",Vector3(x,1.7,z),Vector3(.18,3,2.2),lime)
		p("RoomDoorHead",Vector3(x,2.95,1),Vector3(.18,.5,3.6),b.wood)
	p("InnerRoomWall",Vector3(-4,1.7,-2.9),Vector3(4,3,.18),lime)
	p("InnerRoomWall",Vector3(3,1.7,-2.9),Vector3(2,3,.18),lime)
	p("InnerDoorHead",Vector3(0,2.95,-2.9),Vector3(4,.5,.18),b.wood)
	# Roof cutout above east-side stair; no ceiling across the climb route.
	p("RoofMain",Vector3(-1,3.3,0),Vector3(10,.2,10),earth)
	p("RoofEastFront",Vector3(5,3.3,3.65),Vector3(2,.2,2.7),earth)
	p("RoofEastRear",Vector3(5,3.3,-4.4),Vector3(2,.2,1.2),earth)
	for x in [-6,6]:p("RoofParapet",Vector3(x,3.75,0),Vector3(.24,.7,10),lime)
	for z in [-5,5]:p("RoofParapet",Vector3(0,3.75,z),Vector3(12,.7,.24),lime)
	# Solid shallow treads plus smooth collision ramp for the normal controller.
	for i in 20:
		var rise: float=.16*(i+1)
		p("StairTread",Vector3(5,.2+rise*.5,2.15-i*.29),Vector3(1.65,rise,.29),earth,false)
	var ramp := StaticBody3D.new();ramp.name="StairRamp";add_child(ramp)
	var shape:=BoxShape3D.new();shape.size=Vector3(1.65,.12,6.9)
	var collider:=CollisionShape3D.new();collider.shape=shape;ramp.add_child(collider)
	ramp.position=Vector3(5,1.72,-.8);ramp.rotation.x=atan2(3.2,6.0)
	p("RoofLanding",Vector3(5,3.3,-4.1),Vector3(2,.2,.6),earth)
	p("StairInnerGuard",Vector3(4.05,3.75,-.5),Vector3(.12,.7,6.2),b.wood)
	p("SpineConnection",Vector3(1.5,.026,16),Vector3(3,.05,2.5),earth,false)
	p("LaneApproach",Vector3(0,.025,10.6),Vector3(2.5,.05,11),earth,false)
	for y in [1.05,1.6]:p("WeaponShelf",Vector3(0,y,-4.4),Vector3(4.9,.12,.7),b.wood)
	for x in [-2.4,2.4]:p("ShelfPost",Vector3(x,.95,-4.4),Vector3(.12,1.5,.7),b.wood)
	stock("talwar","talwar",Vector3(-1.55,1.15,-4.4),"res://environment/weapons/Talwar/weapon_talwar_01.glb",Vector3(PI/2,0,0))
	stock("utility_knife","knife",Vector3(-.35,1.15,-4.4),"res://environment/weapons/period_utility_knife/period_utility_knife.glb",Vector3(PI/2,0,0))
	stock("spear","spear",Vector3(3.3,.2,-4.5),"res://environment/weapons/period_spear/period_spear.glb",Vector3.ZERO)
	stock("smoke_bomb","smoke pouches",Vector3(.4,1.7,-4.4),"",Vector3.ZERO)
	for y in [1.0,1.55]:p("SpearKeeper",Vector3(3.3,y,-4.64),Vector3(.4,.09,.4),b.wood,false)
	for x in [-5.7,5.7]:
		if x>0:p("CourtyardWall",Vector3(x,.9,8),Vector3(.22,1.8,6),lime)
		else:
			for z in [5.9,10.1]:p("CourtyardWall",Vector3(x,.9,z),Vector3(.22,1.8,1.8),lime)
		p("VerandaPost",Vector3(x,1.6,6.8),Vector3(.18,2.8,.18),b.wood)
		p("VerandaFoot",Vector3(x,.3,6.8),Vector3(.35,.2,.35),earth)
	p("VerandaRoof",Vector3(0,3.06,6),Vector3(12,.14,2.2),earth)
	p("VerandaBeam",Vector3(0,2.9,6.8),Vector3(11.6,.18,.18),b.wood,false)
	for x in [-5.4,-3.6,-1.8,0.0,1.8,3.6,5.4]:
		p("VerandaRafter",Vector3(x,2.98,6),Vector3(.10,.12,2.3),b.wood,false)
	for x in [-2.25,2.25]:
		for y in [.91,1.46]:
			p("ShelfBracket",Vector3(x,y,-4.4),Vector3(.10,.14,.7),b.wood,false)
	# Shallow roof coping sheds water outside the plastered wall.
	for x in [-6,6]:p("ParapetCoping",Vector3(x,4.12,0),Vector3(.34,.08,10.3),earth,false)
	for z in [-5,5]:p("ParapetCoping",Vector3(0,4.12,z),Vector3(12.3,.08,.34),earth,false)
	# One continuous family boundary encloses the house and adjoining practice farm.
	for x in [-29,7]:p("FamilyBoundarySide",Vector3(x,.9,3.5),Vector3(.25,1.8,19),lime)
	p("FamilyBoundaryBack",Vector3(-11,.9,-6),Vector3(36,1.8,.25),lime)
	p("FamilyBoundaryFrontWest",Vector3(-15.1,.9,13),Vector3(27.8,1.8,.25),lime)
	p("FamilyBoundaryFrontEast",Vector3(4.1,.9,13),Vector3(5.8,1.8,.25),lime)
	var gate=preload("res://objects/hinged_door.gd").new();gate.name="FamilyCourtyardGate"
	gate.width=2.4;gate.height=1.8;gate.night_lock=false;gate.outside_latch_access=true;gate.label_name="Chacha’s courtyard gate"
	add_child(gate);gate.build(b.wood);gate.position=Vector3(0,0,13);gate.set_open(true)
	p("FarmConnection",Vector3(-7.7,.03,8),Vector3(4.4,.06,2.4),earth)

	var cot: Node3D=preload("res://objects/household/sets/rest_corner.tscn").instantiate();cot.name="RecoveryBed";add_child(cot);cot.position=Vector3(-4,.2,0)
	var kitchen: Node3D=preload("res://objects/household/sets/cooking_corner.tscn").instantiate();add_child(kitchen);kitchen.position=Vector3(3,.2,3.4)
	var chacha: Node3D=preload("res://world/suryagarh/settlements/chacha_actor.gd").new()
	chacha.name="Chacha";chacha.movement_enabled=false
	chacha.add_child(preload("res://characters/npcs/households/merchant.glb").instantiate())
	add_child(chacha);chacha.position=Vector3(-.85,.2,3.3)
	var talk=preload("res://world/suryagarh/settlements/chacha_advice.gd").new();talk.name="ChachaAdvice";add_child(talk);talk.position=Vector3(-.85,1.2,3.3)
	var hit:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.6,1.5,.6);hit.shape=box;talk.add_child(hit);talk.collision_layer=0;talk.set_collision_layer_value(8,true)
	var world: Node=get_parent()
	var actor: Node=world.get_node_or_null("Player")
	if actor != null and not actor.has_node("ChachaKit"):
		var kit=preload("res://player/chacha_kit.gd").new();kit.name="ChachaKit";actor.add_child(kit)
	preload("res://world/suryagarh/settlements/bhairavpur_village.gd").new()._merge_static_geometry(self)
func p(label: String, at: Vector3, size: Vector3, mat: Material, solid:=true) -> void:
	b.piece(self,label,at,size,mat,solid)
func stock(id: String, label: String, at: Vector3, path: String, angle: Vector3) -> void:
	var rack=Rack.new();rack.name=id.capitalize()+"Rack";rack.item_id=id;rack.display_name=label
	add_child(rack);rack.position=at
	var hit:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(.65,.4,.5);hit.shape=box;rack.add_child(hit)
	if path!="":
		var model: Node3D=load(path).instantiate();rack.add_child(model);model.rotation=angle
		var bottom:=INF
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			var bounds: AABB=(rack.global_transform.affine_inverse()*mesh.global_transform)*mesh.get_aabb()
			bottom=minf(bottom,bounds.position.y)
		if is_finite(bottom):model.position.y+=(0.0 if id=="spear" else -.04)-bottom
	else:
		var pouch: Node3D=preload("res://objects/household/water_pouch_visual.tscn").instantiate();rack.add_child(pouch);pouch.scale=Vector3.ONE*.45

func _exit_tree() -> void:
	b.free()
