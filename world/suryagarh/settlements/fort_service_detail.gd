extends RefCounted
## Working service spaces, using existing reviewed household models and explicit support heights.
var lime: Material
var flags: Material
var timber: Material
var clay: Material
var soot: Material
var iron: Material

func configure() -> void:
	lime = _surface(Color(.66,.61,.48),0)
	flags = _surface(Color(.40,.39,.33),1)
	timber = ShaderMaterial.new()
	timber.shader = preload("res://objects/door_timber.gdshader")
	timber.set_shader_parameter("tint",Color(.29,.18,.095))
	clay = _plain(Color(.39,.20,.105))
	soot = _plain(Color(.055,.043,.031))
	iron = _plain(Color(.14,.13,.115))

func _plain(color: Color) -> Material:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = .85
	return m

func _surface(color: Color,kind: int) -> Material:
	var m := ShaderMaterial.new()
	m.shader = preload("res://world/suryagarh/settlements/fort_service_surface.gdshader")
	m.set_shader_parameter("tint",color)
	m.set_shader_parameter("kind",kind)
	return m

func shell(b,room: Node3D) -> void:
	b.piece(room,"Floor",Vector3(0,.12,0),Vector3(18,.24,14),flags)
	# Two genuine rear ventilation openings, with wrought bars and no glass.
	b.piece(room,"RearSillWall",Vector3(0,.65,-7),Vector3(18,1.3,.4),lime)
	b.piece(room,"RearHeadWall",Vector3(0,3.0,-7),Vector3(18,1.2,.4),lime)
	for x in [-8.0,0.0,8.0]:
		b.piece(room,"RearWindowPier",Vector3(x,1.85,-7),Vector3(2 if x != 0 else 10,1.1,.4),lime)
	# Apertures span -7..-5 and +5..+7, above standing counter height.
	for x in [-6.0,6.0]:
		b.piece(room,"WindowStoneSill",Vector3(x,1.29,-7),Vector3(2.2,.12,.65),b.stone)
		for bar in 9: b.piece(room,"VentilationBar",Vector3(x-.9+bar*.225,1.85,-7),Vector3(.035,1.1,.05),iron,false)
		for y in [1.37,2.32]: b.piece(room,"VentilationCrossRail",Vector3(x,y,-7),Vector3(2.0,.045,.05),iron,false)
		b.piece(room,"WindowCollision",Vector3(x,1.85,-7),Vector3(2,1.1,.08),iron,true).get_child(0).hide()
	for side in [-1.0,1.0]:
		b.piece(room,"SideWall",Vector3(side*9,1.8,0),Vector3(.4,3.6,14),lime)
		b.piece(room,"FrontPier",Vector3(side*5.15,1.8,7),Vector3(7.7,3.6,.4),lime)
		b.piece(room,"DoorStoneJamb",Vector3(side*1.33,1.5,7.15),Vector3(.17,2.5,.55),b.stone)
	b.piece(room,"DoorHeader",Vector3(0,3.0,7),Vector3(2.6,1.2,.4),lime)
	b.piece(room,"DoorStep",Vector3(0,.08,7.8),Vector3(2.8,.16,1.2),b.stone)
	# Visible supported gable roof; ridge runs across the width of each room.
	var rise := 1.45
	var run := 7.65
	var angle := atan2(rise,run)
	for side in [-1.0,1.0]:
		b.piece(room,"ClayRoofSlope",Vector3(0,3.7+rise*.5,side*run*.5),Vector3(19.2,.18,sqrt(run*run+rise*rise)),b.tile).rotation.x=side*angle
		var mesh := MeshInstance3D.new()
		mesh.name="LimewashedGable"
		mesh.mesh=preload("res://world/suryagarh/settlements/bhairavpur_house_detail.gd").new()._gable_mesh(14,rise,.35)
		mesh.material_override=lime
		mesh.position=Vector3(side*9,3.7,0)
		mesh.rotation.y=PI*.5
		room.add_child(mesh)
	b.piece(room,"RidgeBeam",Vector3(0,5.0,0),Vector3(18.4,.20,.18),timber,false)
	for x in [-8.0,-4.0,0.0,4.0,8.0]:
		b.piece(room,"RoofTieBeam",Vector3(x,3.55,0),Vector3(.18,.20,14.2),timber,false)
		for side in [-1.0,1.0]:
			b.piece(room,"RoofRafter",Vector3(x,3.65+rise*.5,side*run*.5),Vector3(.12,.16,sqrt(run*run+rise*rise)),timber,false).rotation.x=side*angle
		b.piece(room,"RoofKingPost",Vector3(x,4.30,0),Vector3(.14,1.30,.14),timber,false)
	for z in [-6.0,-4.0,-2.0,2.0,4.0,6.0]:
		b.piece(room,"TileSupportBatten",Vector3(0,3.65+rise*(1-absf(z)/run),z),Vector3(18.4,.055,.07),timber,false)

func furnish(b,room: Node3D,index: int) -> void:
	if index == 0: _kitchen(b,room)
	elif index == 1: _stores(b,room)
	else: _quarters(b,room)

func prop(parent: Node3D,label: String,slug: String,at: Vector3,yaw := 0.0) -> Node3D:
	var node := load("res://objects/household/storage/"+slug+".tscn").instantiate() as Node3D
	node.name=label
	node.position=at
	node.rotation.y=yaw
	parent.add_child(node)
	node.add_to_group("fort_supported_prop")
	node.set_meta("support_y",at.y)
	return node

func _pot(b,room: Node3D,label: String,at: Vector3) -> void:
	var model := preload("res://objects/household/water_pot_visual.tscn").instantiate()
	model.name=label
	model.position=at
	room.add_child(model)
	# The shell bottom sits on its platform; collision follows the visible pot.
	var body := StaticBody3D.new()
	body.position=at+Vector3(0,.40,0)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius=.29
	shape.height=.8
	collision.shape=shape
	body.add_child(collision)
	body.add_to_group("solid_period_prop")
	room.add_child(body)

func _kitchen(b,room: Node3D) -> void:
	# Two hearth cheeks and a recessed firebox replace the solid brick block.
	for x in [-6.85,-5.15]: b.piece(room,"HearthCheek",Vector3(x,.69,-4),Vector3(.4,.90,1.8),clay)
	b.piece(room,"HearthBack",Vector3(-6,.69,-4.8),Vector3(1.7,.90,.2),clay)
	b.piece(room,"FireboxBed",Vector3(-6,.31,-4),Vector3(1.4,.14,1.4),soot)
	b.piece(room,"HearthLintel",Vector3(-6,1.18,-4),Vector3(2.2,.16,1.8),clay)
	for x in [-6.6,-5.4]:
		b.piece(room,"PotStand",Vector3(x,1.31,-4),Vector3(.54,.07,.50),iron,false)
		prop(room,"HearthBrassPot","brass_pot",Vector3(x,1.345,-4))
	# Tall chimney draws above the ridge. Fire is contained in the firebox.
	b.piece(room,"ChimneyBreast",Vector3(-6,2.45,-4.75),Vector3(1.25,2.35,.38),lime)
	b.piece(room,"ChimneyStack",Vector3(-6,4.40,-4.75),Vector3(.70,2.25,.70),clay)
	b.piece(room,"ChimneyCap",Vector3(-6,5.60,-4.75),Vector3(.9,.14,.9),b.stone)
	var embers := _plain(Color(.22,.055,.012)) as StandardMaterial3D
	embers.emission_enabled=true
	embers.emission=Color(.45,.07,.008)
	embers.emission_energy_multiplier=1.8
	for log in 4:
		b.piece(room,"GlowingCoal",Vector3(-6.48+log*.30,.40,-3.65),Vector3(.23,.10,.43),embers,false)
	var fire := OmniLight3D.new()
	fire.name="HearthGlow"
	fire.position=Vector3(-6,.67,-3.55)
	fire.light_color=Color(1,.44,.18)
	fire.light_energy=.7
	fire.omni_range=3.0
	room.add_child(fire)
	b.piece(room,"PreparationTable",Vector3(4,.9,-3),Vector3(4,.18,1.2),timber)
	for x in [2.5,5.5]:
		for z in [-3.4,-2.6]: b.piece(room,"TableLeg",Vector3(x,.565,z),Vector3(.12,.65,.12),timber)
	b.piece(room,"TableLowerRail",Vector3(4,.40,-3),Vector3(3,.10,.12),timber,false)
	b.piece(room,"ChoppingBoard",Vector3(3.25,1.015,-3),Vector3(.7,.045,.48),timber,false)
	prop(room,"MixingVessel","brass_pot",Vector3(4,.99,-2.8))
	prop(room,"VegetableBasket","basket",Vector3(5.2,.99,-3))
	for x in [2.4,2.8]: prop(room,"CookingVessel","brass_pot",Vector3(x,.99,-3.25))
	for side in ["l","r"]:
		var marker := Marker3D.new()
		marker.name="CookContact"+side.to_upper()
		marker.position=Vector3(4.14 if side=="l" else 3.93,1.28,-2.80)
		room.add_child(marker)
	b.piece(room,"WaterPotStand",Vector3(-7,.36,2.2),Vector3(1.8,.24,1),b.stone)
	_pot(b,room,"KitchenWaterPot",Vector3(-7.45,.48,2.2))
	_pot(b,room,"KitchenWaterReserve",Vector3(-6.65,.48,2.2))
	prop(room,"WaterBucket","bucket",Vector3(-6.6,.24,3.5))
	prop(room,"KitchenStool","stool",Vector3(5.8,.24,-.8))
	for layer in 4:
		for log in 5:
			b.piece(room,"SplitFirewood",Vector3(-7.5+log*.17,.30+layer*.12,-1.5),Vector3(.13,.11,1.3),timber,false)
	_shelf(b,room,Vector3(1,0,-6.5),4.0)
	for x in [-.5,.3,1.1,1.9,2.7]: prop(room,"ShelfVessel","brass_pot",Vector3(x,1.91,-6.45))
	for x in [0.0,1.3,2.5]: prop(room,"ShelfBasket","basket",Vector3(x,1.12,-6.45))
	b.piece(room,"HangingUtensilRail",Vector3(-2,2.05,-6.70),Vector3(1.7,.08,.08),timber,false)
	for x in [-2.6,-2.2,-1.8]:
		b.piece(room,"HangingLadleHandle",Vector3(x,1.75,-6.6),Vector3(.035,.48,.035),timber,false)
		var scoop := MeshInstance3D.new()
		scoop.name="LadleBowl"
		var bowl := SphereMesh.new()
		bowl.radius=.07
		bowl.height=.05
		scoop.mesh=bowl
		scoop.material_override=iron
		scoop.position=Vector3(x,1.5,-6.6)
		room.add_child(scoop)

func _shelf(b,room: Node3D,at: Vector3,w: float) -> void:
	for y in [1.06,1.85,2.55]: b.piece(room,"StorageShelf",at+Vector3(0,y,0),Vector3(w,.12,.65),timber)
	for side in [-1.0,1.0]: b.piece(room,"ShelfUpright",at+Vector3(side*w*.48,1.4,0),Vector3(.10,2.32,.65),timber)

func _stores(b,room: Node3D) -> void:
	for x in [-7.0,-5.6,-4.2]:
		prop(room,"ProvisionBarrel","barrel",Vector3(x,.24,-4.6))
		prop(room,"SpareBarrel","barrel",Vector3(x,.24,-2.8))
	for x in [4.0,5.5,7.0]:
		prop(room,"ProvisionCrate","crate",Vector3(x,.24,-4.8))
		prop(room,"StackedCrate","crate",Vector3(x,.704,-4.8))
	_shelf(b,room,Vector3(0,0,-6.4),5.0)
	for x in [-2.0,-.8,.8,2.0]:
		prop(room,"StorageBasket","basket",Vector3(x,1.12,-6.4))
		prop(room,"StoreVessel","brass_pot",Vector3(x,1.91,-6.4))
	b.piece(room,"InventoryDesk",Vector3(4,.92,1),Vector3(2.1,.14,1.1),timber)
	for x in [3.1,4.9]: b.piece(room,"DeskLeg",Vector3(x,.55,1),Vector3(.12,.64,.85),timber)
	b.piece(room,"InventoryLedger",Vector3(4,1.02,1),Vector3(.48,.06,.34),b.carpet,false)
	b.piece(room,"LedgerPages",Vector3(4,1.055,1),Vector3(.44,.012,.31),b.plaster,false)
	prop(room,"StoreStool","stool",Vector3(4,.24,2.2))

func _quarters(b,room: Node3D) -> void:
	for x in [-5.0,0.0,5.0]:
		# Woven cots with individual rails and supporting legs.
		for side in [-1.0,1.0]:
			b.piece(room,"CotLongRail",Vector3(x+side*.88,.62,-3),Vector3(.12,.15,3.4),timber)
			b.piece(room,"CotShortRail",Vector3(x,.62,-3+side*1.66),Vector3(1.85,.15,.12),timber)
			for z in [-4.55,-1.45]: b.piece(room,"CotLeg",Vector3(x+side*.8,.42,z),Vector3(.12,.36,.12),timber)
		for cord in 29: b.piece(room,"CotRope",Vector3(x,.64,-4.55+cord*.11),Vector3(1.60,.025,.025),b.ochre,false)
		b.piece(room,"CotCollision",Vector3(x,.59,-3),Vector3(1.6,.13,3.2),timber).get_child(0).hide()
		b.piece(room,"FoldedBlanket",Vector3(x,.70,-3.4),Vector3(1.55,.10,1.5),b.carpet,false)
		b.piece(room,"CotPillow",Vector3(x,.77,-4.25),Vector3(.8,.18,.42),b.plaster,false)
		prop(room,"PersonalStorage","crate",Vector3(x-1.2,.24,-4.8))
		prop(room,"BedsideBrassPot","brass_pot",Vector3(x-1.25,.24,-1.5))
	prop(room,"StaffBench","bench",Vector3(-5,.24,2))
	_pot(b,room,"QuartersWaterPot",Vector3(7,.24,3.5))
	b.piece(room,"ClothesPegRail",Vector3(0,2.05,-6.72),Vector3(5,.08,.08),timber,false)
	for x in [-2.0,-1.0,0.0,1.0,2.0]: b.piece(room,"ClothesPeg",Vector3(x,2.05,-6.55),Vector3(.045,.045,.30),timber,false)
