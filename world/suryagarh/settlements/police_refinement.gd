extends RefCounted
## Original station detail: lime-masonry trim, open high vents and room furnishings.

static func masonry(grade: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://world/suryagarh/settlements/police_masonry.gdshader")
	mat.set_shader_parameter("building_grade", grade)
	return mat

static func vent(b: Node3D, label: String, center: Vector3, width: float, sideways: bool = false) -> void:
	var node := Node3D.new()
	node.name = label
	node.position = center
	if sideways: node.rotation.y = PI * 0.5
	b.add_child(node)
	for side in [-1,1]:
		b.piece(node,"VentJamb",Vector3(side*(width*0.5-0.04),0,0),Vector3(0.08,0.90,0.12),b.wood,false)
		b.piece(node,"VentRail",Vector3(0,side*0.41,0),Vector3(width,0.08,0.12),b.wood,false)
	for i in 5:
		b.piece(node,"VentLouvre",Vector3(0,-0.30+i*0.15,0),Vector3(width-0.12,0.055,0.15),b.wood,false).rotation.x = -0.32
	node.set_meta("open_air_path",true)

static func chair(b: Node3D, center: Vector3, yaw: float = 0.0) -> void:
	var node := Node3D.new()
	node.name = "StationChair"
	node.position = center
	node.rotation.y = yaw
	b.add_child(node)
	b.piece(node,"ChairSeat",Vector3(0,0.46,0),Vector3(0.57,0.08,0.55),b.wood)
	for x in [-0.23,0.23]:
		for z in [-0.21,0.21]:
			b.piece(node,"ChairLeg",Vector3(x,0.22,z),Vector3(0.065,0.44,0.065),b.wood,false)
	for x in [-0.23,0.23]:
		b.piece(node,"ChairBackPost",Vector3(x,0.77,0.22),Vector3(0.065,0.62,0.065),b.wood,false)
	for y in [0.70,0.91]:
		b.piece(node,"ChairBackRail",Vector3(0,y,0.22),Vector3(0.52,0.08,0.065),b.wood,false)

static func papers(b: Node3D, center: Vector3) -> void:
	var paper: Material = b.material(Color(0.74,0.69,0.55))
	var ink: Material = b.material(Color(0.10,0.09,0.07))
	b.piece(b,"StationDocumentStack",center,Vector3(0.30,0.035,0.39),paper,false)
	for i in 4:
		b.piece(b,"HandwrittenLine",center+Vector3(0,0.019,-0.10+i*0.055),Vector3(0.18,0.001,0.003),ink,false)
	b.piece(b,"InkWell",center+Vector3(0.31,0.04,0.04),Vector3(0.075,0.08,0.075),ink,false)
	var pen: Node3D = b.piece(b,"WritingReed",center+Vector3(0.30,0.09,0.04),Vector3(0.008,0.20,0.008),b.wood,false)
	pen.rotation.z = 0.30

static func lamp(b: Node3D, label: String, center: Vector3, range_value: float = 6.0) -> void:
	var fixture := Node3D.new()
	fixture.name = label
	fixture.position = center
	b.add_child(fixture)
	b.piece(fixture,"LampWallBracket",Vector3(0,0,0.18),Vector3(0.055,0.08,0.36),b.iron,false)
	b.piece(fixture,"OilReservoir",Vector3(0,-0.12,0),Vector3(0.21,0.11,0.21),b.iron,false)
	b.piece(fixture,"LampHood",Vector3(0,0.22,0),Vector3(0.28,0.055,0.28),b.iron,false)
	for x in [-0.10,0.10]:
		for z in [-0.10,0.10]:
			b.piece(fixture,"LanternCage",Vector3(x,0.045,z),Vector3(0.018,0.31,0.018),b.iron,false)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.93,0.46,0.10)
	glow.emission_enabled = true
	glow.emission = Color(1.0,0.38,0.07)
	glow.emission_energy_multiplier = 1.3
	b.piece(fixture,"OilFlame",Vector3(0,0.02,0),Vector3(0.025,0.08,0.025),glow,false)
	var light := OmniLight3D.new()
	light.name = "LocalOilLight"
	light.position.y = 0.07
	light.light_color = Color(1.0,0.73,0.43)
	light.light_energy = 0.72
	light.omni_range = range_value
	light.omni_attenuation = 1.7
	light.shadow_enabled = false
	light.distance_fade_enabled = true
	light.distance_fade_begin = 22.0
	light.distance_fade_length = 8.0
	fixture.add_child(light)

static func furnish(b: Node3D) -> void:
	# Corner quoins and a thin projecting stone plinth rather than a printed grid.
	for x in [-b.width*0.5,b.width*0.5]:
		for z in [-b.depth*0.5,b.depth*0.5]:
			for row in 12:
				b.piece(b,"StationQuoin",Vector3(x,row*0.42+0.23,z),Vector3(0.72 if row%2==0 else 0.58,0.38,0.58 if row%2==0 else 0.72),b.stone,false)
	for side in [-1,1]:
		b.piece(b,"StationPlinthCourse",Vector3(side*b.width*0.5,0.28,0),Vector3(0.64,0.30,b.depth),b.stone,false)
		for level in 2:
			for z in range(-int(b.depth*0.5)+2,int(b.depth*0.5),4):
				vent(b,"StationHighVent",Vector3(side*b.width*0.5,level*b.floor_y+4.0,z),2.35,true)
	# Front room is reception; west bays serve records/officer/duty work.
	b.piece(b,"ReceptionDesk",Vector3(3,0.85,10),Vector3(3.0,0.12,0.95),b.wood)
	for x in [1.7,4.3]:
		b.piece(b,"ReceptionDeskSupport",Vector3(x,0.40,10),Vector3(0.12,0.80,0.82),b.wood)
	chair(b,Vector3(3,0,8.9),PI)
	papers(b,Vector3(2.6,0.93,10))
	for z in [10.5,14.0]:
		b.piece(b,"StationWaitingBench",Vector3(-3,0.47,z),Vector3(0.68,0.12,2.2),b.wood)
		for dz in [-0.85,0.85]:
			b.piece(b,"WaitingBenchLeg",Vector3(-3,0.22,z+dz),Vector3(0.52,0.44,0.10),b.wood,false)
	for level in 2:
		var y: float = level*b.floor_y
		for z in [-7.0,4.0]:
			chair(b,Vector3(-9.5,y,z+1.2))
			papers(b,Vector3(-9.85,y+0.93,z))
			lamp(b,"OfficeOilLamp",Vector3(-12.6,y+2.2,z),5.5)
		# Individual office storage is tucked beside the outer wall.
		for shelf in 4:
			b.piece(b,"StationRegisterShelf",Vector3(-12.45,y+0.50+shelf*0.48,-9.5),Vector3(0.55,0.065,2.5),b.wood)
			for bundle in 5:
				b.piece(b,"TiedRegisterBundle",Vector3(-12.45,y+0.60+shelf*0.48,-10.4+bundle*0.43),Vector3(0.43,0.13,0.30),b.ochre,false)
		lamp(b,"HallOilLamp",Vector3(5,y+2.4,12),7.0)
	# Officer's wall board, duty pegs and folded bedding make upper rooms distinct.
	b.piece(b,"OfficerNoticeBoard",Vector3(-12.8,b.floor_y+1.7,4),Vector3(0.07,0.90,1.30),b.wood,false)
	for z in [-8.2,-7.6,-7.0,-6.4]:
		b.piece(b,"DutyCoatPeg",Vector3(-12.7,b.floor_y+1.6,z),Vector3(0.22,0.045,0.045),b.wood,false)
	b.piece(b,"DutyStorageChest",Vector3(-11.9,b.floor_y+0.32,-4.2),Vector3(1.1,0.64,0.62),b.wood)
	b.piece(b,"FoldedDutyBlanket",Vector3(-11.9,b.floor_y+0.69,-4.2),Vector3(0.85,0.09,0.50),b.ochre,false)
	for z in [-10.0,4.0]:
		lamp(b,"CellarOilLamp",Vector3(6,-1.65,z),7.5)
	b.set_meta("station_room_program",["reception","records","report_office","officer_room","duty_room","armoury","holding_cells","lower_detention"])
	b.set_meta("station_local_lights",8)
