extends "res://world/suryagarh/settlements/settlement_builder.gd"
## Fictional 1857 Government House, informed by the 1803 Calcutta precedent.
## Local north is +Z. Surveyed estate and route live in SuryagarhLayout.
const RESIDENCE := Vector3(0, 0, -35)
const STOREY := 4.6
var glass: Material
var brass: Material
var hedge: Material
var lawn: Material
var marble: Material
var carpet: Material
var flower_red: Material
var flower_gold: Material

func _ready() -> void:
	name = "GovernmentHouse"
	var plot: Dictionary = Layout.PLOTS["GovernmentHouse"]
	position = Vector3(plot.center.x, plot.grade, plot.center.y)
	plaster = textured("clay_plaster",Color(.88,.85,.76),.38)
	ochre = material(Color(.65,.55,.40))
	brick = material(Color(.51,.30,.21),true)
	wood = textured("dark_wood",Color(.68,.55,.42),.72)
	tile = material(Color(.42,.25,.18),true)
	stone = material(Color(.53,.49,.41),true)
	iron = material(Color(.14,.14,.13))
	glass = material(Color(.23,.34,.34))
	brass = material(Color(.57,.43,.19))
	hedge = material(Color(.22,.31,.19))
	lawn = material(Color(.32,.38,.23))
	marble = StandardMaterial3D.new()
	marble.albedo_color = Color(.77,.73,.65)
	marble.roughness = .36
	carpet = material(Color(.37,.16,.12))
	flower_red = material(Color(.54,.15,.12))
	flower_gold = material(Color(.71,.48,.16))
	build_estate()
	build_main_house()
	for side in [-1.0,1.0]: build_wing(side)
	merge_visuals(self)

func textured(asset: String, tint: Color, scale_value: float) -> Material:
	var mat := StandardMaterial3D.new()
	mat.albedo_color=tint
	# The source clay diffuse is much darker than period lime plaster. Retain its
	# normal/roughness relief while keeping the residence's pale mineral finish.
	if asset != "clay_plaster":
		mat.albedo_texture=load("res://assets/architecture/materials/"+asset+"_Diffuse.jpg")
	mat.normal_enabled=true
	mat.normal_texture=load("res://assets/architecture/materials/"+asset+"_nor_gl.jpg")
	mat.normal_scale=.38
	mat.roughness_texture=load("res://assets/architecture/materials/"+asset+"_Rough.jpg")
	mat.uv1_triplanar=true
	mat.uv1_world_triplanar=true
	mat.uv1_scale=Vector3.ONE*scale_value
	return mat

func box(label: String, center: Vector3, size: Vector3, mat: Material, solid := true) -> Node3D:
	return piece(self,label,center,size,mat,solid)

func piece(parent: Node3D, label: String, center: Vector3, size: Vector3, mat: Material, solid := true) -> Node3D:
	var result: Node3D = super.piece(parent,label,center,size,mat,solid)
	result.set_meta("part_label",label)
	return result

func orb(parent: Node3D, label: String, center: Vector3, radius: float, mat: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius=radius
	mesh.height=radius*1.65
	mesh.radial_segments=10
	mesh.rings=6
	var node := MeshInstance3D.new()
	node.name=label
	node.mesh=mesh
	node.material_override=mat
	node.position=center
	parent.add_child(node)

func build_estate() -> void:
	# A single level estate surface keeps paths, walls and doorsteps on one grade.
	box("EstateGround",Vector3(0,.02,0),Vector3(191.5,.04,183.5),lawn)
	box("NorthWallLeft",Vector3(-51,2.7,92),Vector3(90,5.4,1.2),brick)
	box("NorthWallRight",Vector3(51,2.7,92),Vector3(90,5.4,1.2),brick)
	box("SouthWall",Vector3(0,2.7,-92),Vector3(192,5.4,1.2),brick)
	for side in [-1.0,1.0]:
		box("PerimeterWall",Vector3(side*96,2.7,0),Vector3(1.2,5.4,184),brick)
		box("WallCoping",Vector3(side*96,5.47,0),Vector3(1.5,.16,184),stone,false)
		box("GatePier",Vector3(side*5.5,3.2,92),Vector3(1.8,6.4,2.0),stone)
		box("GateLeafOpen",Vector3(side*5.45,2.25,88.9),Vector3(.18,4.5,5.0),iron,false)
		for bar in 9:
			box("GateRail",Vector3(side*5.58,2.25,86.7+bar*.55),Vector3(.08,4.5,.08),brass,false)
	box("GateArchitrave",Vector3(0,6.5,92),Vector3(13,.45,2.0),stone)
	box("NorthCopingLeft",Vector3(-51,5.48,92),Vector3(90,.16,1.5),stone,false)
	box("NorthCopingRight",Vector3(51,5.48,92),Vector3(90,.16,1.5),stone,false)
	# Broad central carriage axis leaves a clear route from gate to portico.
	box("CarriageAvenue",Vector3(0,.075,42),Vector3(10,.11,101),stone)
	box("TurningCourt",Vector3(0,.09,2),Vector3(30,.13,29),ochre)
	for z in [11.0,85.0]: box("CrossGardenWalk",Vector3(0,.09,z),Vector3(115,.12,3),stone)
	for side in [-1.0,1.0]:
		for z in [20.0,39.0,58.0,77.0]:
			box("ParterreBed",Vector3(side*25,.13,z),Vector3(22,.24,13),ochre,false)
			box("ParterrePlanting",Vector3(side*25,.26,z),Vector3(20,.18,11),hedge,false)
			for row in [-1.0,1.0]:
				box("LowHedge",Vector3(side*25+row*10,.56,z),Vector3(.7,.7,12),hedge,false)
			for offset in [-6.0,0.0,6.0]:
				orb(self,"ClippedGardenShrub",Vector3(side*25+offset,.67,z),.9,hedge)
				for row in [-2.0,2.0]:
					orb(self,"GardenBloom",Vector3(side*25+offset,1.25,z+row*.22),.22,flower_red if row<0 else flower_gold)
		box("GardenWalk",Vector3(side*52,.085,41),Vector3(3,.09,95),stone)
		for z in [14.0,34.0,54.0,74.0]:
			box("ShadeTreeTrunk",Vector3(side*63,2.1,z),Vector3(.55,4.2,.55),wood,false)
			var crown := MeshInstance3D.new()
			var mesh := SphereMesh.new()
			mesh.radius=3.0
			mesh.height=5.6
			crown.mesh=mesh
			crown.material_override=hedge
			crown.position=Vector3(side*63,5.2,z)
			add_child(crown)
		box("FountainBase",Vector3(side*25,.28,1),Vector3(9,.48,9),stone)
		box("FountainBasin",Vector3(side*25,.58,1),Vector3(7.5,.12,7.5),glass,false)
		box("FountainPedestal",Vector3(side*25,1.1,1),Vector3(1.1,1.4,1.1),stone)
		box("FountainFinial",Vector3(side*25,1.9,1),Vector3(1.7,.2,1.7),brass,false)
		for z in [18.0,38.0,58.0,78.0]:
			box("PathBenchSeat",Vector3(side*50,.55,z),Vector3(2.8,.18,.7),wood)
			for dx in [-1.0,1.0]: box("PathBenchLeg",Vector3(side*50+dx, .32,z),Vector3(.13,.5,.55),iron,false)
	for x in [-81.0,-42.0,42.0,81.0]:
		box("EstateLampPost",Vector3(x,2.2,83),Vector3(.18,4.4,.18),iron,false)
		box("EstateLamp",Vector3(x,4.52,83),Vector3(.6,.55,.6),brass,false)

func build_main_house() -> void:
	var h := Node3D.new()
	h.name="MainHouse"
	h.position=RESIDENCE
	add_child(h)
	# All floor and wall coordinates below are local to the main house.
	# Use an explicit helper for child geometry so the estate remains one module.
	main_floor(h)
	for level in 3:
		var y := level*STOREY
		long_facade(h,y,20.0,true,level)
		long_facade(h,y,-20.0,false,level)
		for side in [-1.0,1.0]: side_facade(h,y,side,level)
		interior(h,level)
		for x in [-32.0,32.0]:
			piece(h,"CornerQuoin",Vector3(x,y+2.3,20.15),Vector3(1.15,4.6,.72),stone,false)
		for z in [-20.0,20.0]:
			piece(h,"Stringcourse",Vector3(0,y+4.49,z),Vector3(69,.23,.8),stone,false)
	staircase(h,0,20.0,true)
	staircase(h,1,28.0,false)
	piece(h,"RoofDeck",Vector3(0,13.94,0),Vector3(70,.34,43),tile)
	for side in [-1.0,1.0]:
		piece(h,"RoofBalustrade",Vector3(side*34,14.55,0),Vector3(.65,1.1,44),stone)
		piece(h,"RoofBalustrade",Vector3(0,14.55,side*20.8),Vector3(70,1.1,.65),stone)
	# Porte-cochere: real shaded threshold, large enough for the player capsule.
	piece(h,"PorticoFloor",Vector3(0,.24,24),Vector3(26,.42,10),stone)
	piece(h,"PorticoRoof",Vector3(0,5.0,24),Vector3(27,.5,10.5),stone)
	for x in [-11.0,-7.0,7.0,11.0]:
		for z in [19.5,28.5]:
			column(h,Vector3(x,2.6,z),4.7)
	piece(h,"PorticoPediment",Vector3(0,5.45,24),Vector3(27,.38,10.5),plaster,false)
	for side in [-1.0,1.0]:
		var rake := piece(h,"PedimentRake",Vector3(side*6.6,6.2,29),Vector3(13.5,.36,.8),stone,false)
		rake.rotation.z = -side*.14
	piece(h,"PorticoFrieze",Vector3(0,5.15,29.2),Vector3(25,.44,.28),brass,false)
	for step in 4:
		piece(h,"EntranceStep",Vector3(0,.05+step*.105,29.8-step*.85),Vector3(17,.21,1.0),stone)
	var sign := Label3D.new()
	sign.text="GOVERNMENT HOUSE"
	sign.font=preload("res://assets/ui/fonts/CormorantGaramond.ttf")
	sign.font_size=72
	sign.pixel_size=.009
	sign.position=Vector3(0,6.4,20.6)
	h.add_child(sign)

func main_floor(h: Node3D) -> void:
	piece(h,"GroundFloor",Vector3(0,.17,0),Vector3(68,.34,40),stone)
	piece(h,"MarbleHallInset",Vector3(0,.355,0),Vector3(27,.035,26),marble,false)
	for z in [-12.0,12.0]: piece(h,"HallFloorBorder",Vector3(0,.382,z),Vector3(27,.028,.18),brass,false)
	for x in [-13.5,13.5]: piece(h,"HallFloorBorder",Vector3(x,.382,0),Vector3(.18,.028,24),brass,false)
	for level in [1,2]:
		var y: float=level*STOREY
		piece(h,"UpperFloorMain",Vector3(-9,y-.14,0),Vector3(50,.28,40),wood)
		piece(h,"UpperFloorRight",Vector3(33,y-.14,0),Vector3(2,.28,40),wood)
		for z in [-16.0,16.0]:
			piece(h,"StairLanding",Vector3(24,y-.14,z),Vector3(16,.28,8),wood)
		piece(h,"CentralRunner",Vector3(0,y+.012,0),Vector3(7,.025,23),carpet,false)
		for x in [-3.55,3.55]: piece(h,"RunnerBorder",Vector3(x,y+.035,0),Vector3(.12,.018,23),brass,false)

func long_facade(h: Node3D, y: float, z: float, front: bool, level: int) -> void:
	for i in 9:
		var x: float = -34.0+i*8.5
		if front and level==0 and absf(x)<.1: continue
		piece(h,"MasonryPier",Vector3(x,y+2.35,z),Vector3(1.2,4.7,.62),plaster)
	for i in 8:
		var x: float = -29.75+i*8.5
		if front and level==0 and absf(x)<5.0:
			piece(h,"DoorHead",Vector3(x,y+4.15,z),Vector3(7.3,1.1,.62),plaster)
			continue
		piece(h,"WindowSillMasonry",Vector3(x,y+.6,z),Vector3(7.3,1.2,.62),plaster)
		piece(h,"WindowHeadMasonry",Vector3(x,y+4.18,z),Vector3(7.3,1.05,.62),plaster)
		window(h,Vector3(x,y+2.55,z+(0.36 if front else -0.36)),Vector2(5.4,2.4),true)
	for x in [-25.5,-17.0,-8.5,0.0,8.5,17.0,25.5]:
		if front and level==0 and absf(x)<.1: continue
		piece(h,"FacadePilaster",Vector3(x,y+2.35,z+(0.52 if front else -0.52)),Vector3(.36,4.7,.35),stone,false)
	for x in [-25.5,-17.0,-8.5,8.5,17.0,25.5]:
		piece(h,"PilasterCapital",Vector3(x,y+4.55,z+(0.58 if front else -0.58)),Vector3(.9,.18,.56),stone,false)

func side_facade(h: Node3D,y: float,side: float,level: int) -> void:
	for i in 6:
		var z: float = -20.0+i*8.0
		piece(h,"SidePier",Vector3(side*34,y+2.35,z),Vector3(.62,4.7,1.05),plaster)
	for i in 5:
		var z: float = -16.0+i*8.0
		if level==0 and absf(z)<.1:
			piece(h,"WingPassageLintel",Vector3(side*34,y+4.15,0),Vector3(.62,1.05,6.95),plaster)
			continue
		piece(h,"SideSill",Vector3(side*34,y+.6,z),Vector3(.62,1.2,6.95),plaster)
		piece(h,"SideHead",Vector3(side*34,y+4.18,z),Vector3(.62,1.05,6.95),plaster)
		window(h,Vector3(side*34.37,y+2.55,z),Vector2(5.4,2.4),false)

func window(h: Node3D,p: Vector3,extent: Vector2,along_x: bool) -> void:
	var size := Vector3(extent.x,extent.y,.06) if along_x else Vector3(.06,extent.y,extent.x)
	piece(h,"GlazedWindow",p,size,glass,false)
	for offset in [-1.0,1.0]:
		var rail := p+Vector3(offset*extent.x*.5,0,0) if along_x else p+Vector3(0,0,offset*extent.x*.5)
		piece(h,"WindowJamb",rail,Vector3(.12,extent.y+.2,.16) if along_x else Vector3(.16,extent.y+.2,.12),stone,false)
	var mullion := Vector3(.11,extent.y,.13) if along_x else Vector3(.13,extent.y,.11)
	for offset in [-.25,.25]:
		var mullion_at := p+Vector3(offset*extent.x,0,0) if along_x else p+Vector3(0,0,offset*extent.x)
		piece(h,"WindowMullion",mullion_at,mullion,wood,false)
	piece(h,"WindowTransom",p,Vector3(extent.x,.1,.13) if along_x else Vector3(.13,.1,extent.x),wood,false)
	var sill := p+Vector3(0,-extent.y*.5-.13,.16) if along_x else p+Vector3(.16,-extent.y*.5-.13,0)
	piece(h,"ProjectingWindowSill",sill,Vector3(extent.x+.45,.18,.45) if along_x else Vector3(.45,.18,extent.x+.45),stone,false)
	for side in [-1.0,1.0]:
		var offset: float=side*(extent.x*.5+.32)
		var shutter := p+Vector3(offset,0,.14) if along_x else p+Vector3(.14,0,offset)
		piece(h,"OpenTimberShutter",shutter,Vector3(.57,extent.y,.12) if along_x else Vector3(.12,extent.y,.57),wood,false)
		if along_x:
			for slat in 5:
				piece(h,"ShutterLouver",shutter+Vector3(0,-.82+slat*.4,.085),Vector3(.53,.065,.09),ochre,false)

func interior(h: Node3D,level: int) -> void:
	var y := level*STOREY
	for z in [-14.0,-7.0,7.0,14.0]:
		for side in [-1.0,1.0]:
			piece(h,"HallColumnShaft",Vector3(side*9.5,y+2.25,z),Vector3(.5,4.5,.5),marble)
			piece(h,"HallColumnBase",Vector3(side*9.5,y+.22,z),Vector3(.8,.35,.8),stone,false)
			piece(h,"HallColumnCapital",Vector3(side*9.5,y+4.52,z),Vector3(.95,.3,.95),brass,false)
	for z in [-19.55,19.55]:
		piece(h,"InteriorCornice",Vector3(0,y+4.36,z),Vector3(65,.23,.22),stone,false)
	for x in [-33.55,33.55]:
		piece(h,"InteriorCornice",Vector3(x,y+4.36,0),Vector3(.22,.23,39),stone,false)
	# Rooms open into a central cross hall; no partition seals its doorways.
	for side in [-1.0,1.0]:
		for row in [-1.0,1.0]:
			piece(h,"RoomPartitionInner",Vector3(side*17.5,y+2.2,row*5.75),Vector3(.35,4.4,3.5),plaster)
			piece(h,"RoomPartitionOuter",Vector3(side*17.5,y+2.2,row*15.5),Vector3(.35,4.4,5),plaster)
			piece(h,"RoomDoorLintel",Vector3(side*17.5,y+4.0,row*10.5),Vector3(.35,1.2,6),plaster)
			for edge in [-1.0,1.0]:
				piece(h,"RoomDoorJamb",Vector3(side*17.73,y+1.6,row*10.5+edge*3.0),Vector3(.12,3.2,.14),stone,false)
		# West rooms have their own connecting door. Keep the east stairwell
		# and both wing passage mouths clear at the building's midline.
		if side<0:
			piece(h,"CrossPartitionInner",Vector3(-21.5,y+2.2,0),Vector3(8,4.4,.35),plaster)
			piece(h,"CrossPartitionOuter",Vector3(-30,y+2.2,0),Vector3(3,4.4,.35),plaster)
			piece(h,"CrossDoorLintel",Vector3(-27,y+4.0,0),Vector3(3,1.2,.35),plaster)
	# Furniture follows function rather than filling the whole walkable floor.
	var table_mat: Material=stone if level==0 else wood
	for side in [-1.0,1.0]:
		for row in [-1.0,1.0]:
			var x: float = side*23.5
			var z: float = row*10.5
			piece(h,"RoomTable",Vector3(x,y+1.0,z),Vector3(3.2,.15,1.6),table_mat)
			for dx in [-1.0,1.0]:
				piece(h,"TableLeg",Vector3(x+dx*1.3,y+.53,z),Vector3(.12,.95,1.2),wood,false)
			piece(h,"ChairSeat",Vector3(x,y+.52,z+2.2),Vector3(.8,.12,.8),wood)
			piece(h,"ChairBack",Vector3(x,y+1.1,z+2.55),Vector3(.8,1.2,.12),wood,false)
			piece(h,"WallPanel",Vector3(x,y+2.7,-18.95),Vector3(3.4,2.2,.08),ochre,false)
			piece(h,"PanelFrameTop",Vector3(x,y+3.85,-18.86),Vector3(3.7,.12,.13),brass,false)
	for x in [-13.0,0.0,13.0]:
		var lamp := OmniLight3D.new()
		lamp.position=Vector3(x,y+3.8,0)
		lamp.light_color=Color(1,.78,.52)
		lamp.light_energy=1.25
		lamp.omni_range=20
		h.add_child(lamp)
		piece(h,"PendantStem",Vector3(x,y+4.2,0),Vector3(.07,.8,.07),brass,false)
		piece(h,"PendantLantern",Vector3(x,y+3.7,0),Vector3(.46,.6,.46),brass,false)
		for side in [-1.0,1.0]:
			piece(h,"LanternArm",Vector3(x+side*.42,y+3.62,0),Vector3(.85,.08,.08),brass,false)
			orb(h,"LanternGlobe",Vector3(x+side*.8,y+3.64,0),.2,plaster)
	if level==0:
		for x in [-8.0,8.0]: piece(h,"MarbleHallBench",Vector3(x,y+.5,8),Vector3(3,.35,.8),stone)
		for side in [-1.0,1.0]:
			piece(h,"ReceptionCabinet",Vector3(side*29,y+1.2,-7),Vector3(3.6,2.3,.75),wood)
			for shelf in [0.65,1.3,1.95]:
				piece(h,"CabinetShelf",Vector3(side*29,y+shelf,-6.55),Vector3(3.5,.08,.58),brass,false)
	if level==1:
		piece(h,"CouncilTable",Vector3(0,y+1.0,-8),Vector3(8,.2,2.4),wood)
		for x in [-5.0,5.0]: piece(h,"DrawingSofa",Vector3(x,y+.65,9),Vector3(3,1.1,1.4),wood)
		for side in [-1.0]:
			piece(h,"Bookcase",Vector3(side*29,y+1.9,-7),Vector3(4.4,3.7,.65),wood)
			for shelf in [1.0,1.85,2.7]:
				piece(h,"BookcaseShelf",Vector3(side*29,y+shelf,-6.55),Vector3(4.2,.1,.75),brass,false)
				for book in 9:
					piece(h,"BoundVolume",Vector3(side*29-1.8+book*.45,y+shelf+.35,-6.45),Vector3(.3,.6,.35),carpet if book%3==0 else ochre,false)
	if level==2:
		for x in [-23.0,23.0]:
			piece(h,"Bedframe",Vector3(x,y+.65,-11),Vector3(3,.7,5.2),wood)
			piece(h,"Bedding",Vector3(x,y+1.07,-11),Vector3(2.8,.2,4.8),plaster,false)

func staircase(h: Node3D,level: int,x: float,up_toward_back: bool) -> void:
	var y := level*STOREY
	var angle := atan2(STOREY,24.0)*(1.0 if up_toward_back else -1.0)
	var ramp := piece(h,"WalkableStairSlope",Vector3(x,y+STOREY*.5,0),Vector3(3.6,.27,sqrt(24.0*24.0+STOREY*STOREY)),stone)
	ramp.rotation.x=angle
	ramp.get_child(0).hide()
	for step in 24:
		var t := (step+.5)/24.0
		var z := 12.0-24.0*t if up_toward_back else -12.0+24.0*t
		piece(h,"StairTread",Vector3(x,y+STOREY*t,z),Vector3(3.6,.13,1.0),wood,false)
	for side in [-1.0,1.0]:
		var rail := piece(h,"StairRail",Vector3(x+side*1.9,y+STOREY*.5+1,0),Vector3(.12,.12,sqrt(24.0*24.0+STOREY*STOREY)),wood,false)
		rail.rotation.x=angle

func build_wing(side: float) -> void:
	var wing := Node3D.new()
	wing.name="WestWing" if side<0 else "EastWing"
	wing.position=Vector3(side*49,0,-35)
	add_child(wing)
	# Open loggia connects each wing to the central hall at ground level.
	piece(self,"WingCorridorFloor",Vector3(side*41,.16,-35),Vector3(16,.32,7),stone)
	piece(self,"WingCorridorRoof",Vector3(side*41,4.85,-35),Vector3(16,.25,7),tile)
	for z in [-38.0,-32.0]:
		for x in [37.0,45.0]: column(self,Vector3(side*x,2.5,z),4.4)
	for level in 2:
		var y := level*STOREY
		piece(wing,"WingFloor",Vector3(0,y+.13,0),Vector3(22,.26,24),stone if level==0 else wood)
		for edge in [-1.0,1.0]:
			if level==0 and edge==-side:
				for z in [-8.0,8.0]: piece(wing,"WingWindowSill",Vector3(edge*11,y+.6,z),Vector3(.45,1.2,8),plaster)
			else:
				piece(wing,"WingWindowSill",Vector3(edge*11,y+.6,0),Vector3(.45,1.2,24),plaster)
			piece(wing,"WingWindowHead",Vector3(edge*11,y+4.15,0),Vector3(.45,.9,24),plaster)
			for z in [-10.0,0.0,10.0]:
				if level==0 and edge==-side and z==0.0: continue
				piece(wing,"WingSidePier",Vector3(edge*11,y+2.4,z),Vector3(.45,2.4,4.4 if z != 0.0 else 8.5),plaster)
			piece(wing,"WingRearWall",Vector3(0,y+2.3,-12),Vector3(22,4.6,.45),plaster)
			piece(wing,"WingFrontPier",Vector3(edge*8,y+2.3,12),Vector3(6,4.6,.45),plaster)
		piece(wing,"WingDoorLintel",Vector3(0,y+4.1,12),Vector3(4,1.0,.45),plaster)
		piece(wing,"WingDesk",Vector3(0,y+1.0,0),Vector3(3,.15,1.4),wood)
		for z in [-6.0,6.0]:
			window(wing,Vector3(11.28,y+2.55,z),Vector2(3.5,2.4),false)
			window(wing,Vector3(-11.28,y+2.55,z),Vector2(3.5,2.4),false)
	piece(wing,"WingRoof",Vector3(0,9.5,0),Vector3(23,.35,25),tile)
