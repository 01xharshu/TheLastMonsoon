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

static func chair(b: Node3D, center: Vector3, yaw: float = 0.0, senior := false) -> void:
	var node := Node3D.new()
	node.name = "StationChair"
	node.add_to_group("station_furnishing_chairs")
	node.position = center
	node.rotation.y = yaw
	b.add_child(node)
	if senior:
		var upholstery := StandardMaterial3D.new()
		upholstery.albedo_color = Color(.19,.23,.13)
		b.piece(node,"LeatherSeatPad",Vector3(0,.501,0),Vector3(.55,.025,.53),upholstery,false)
		b.piece(node,"LeatherBackPad",Vector3(0,.83,.208),Vector3(.47,.43,.065),upholstery,false)
		for x in [-.27,.27]:
			b.piece(node,"ArmSupport",Vector3(x,.59,-.15),Vector3(.045,.22,.045),b.wood,false)
			b.piece(node,"Armrest",Vector3(x,.70,-.035),Vector3(.08,.055,.45),b.wood,false)
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

static func lamp(b: Node3D, label: String, center: Vector3, range_value: float = 6.0, ceiling_y: float = 4.9) -> void:
	var fixture := Node3D.new()
	fixture.name = label
	fixture.position = center
	b.add_child(fixture)
	var suspension: float = maxf(0.10, ceiling_y-center.y-0.25)
	b.piece(fixture,"LampSuspension",Vector3(0,0.25+suspension*0.5,0),Vector3(0.018,suspension,0.018),b.iron,false)
	b.piece(fixture,"CeilingHook",Vector3(0,ceiling_y-center.y,0),Vector3(0.10,0.04,0.10),b.iron,false)
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
	forecourt_gate(b)
	escape_window(b)
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
	preload("res://world/suryagarh/settlements/official_desk.gd").build(b,b,Vector3(3,0,10),0.0)
	chair(b,Vector3(3,0,9.12),PI)
	papers(b,Vector3(2.6,0.93,10))
	for z in [10.5,14.0]:
		b.piece(b,"StationWaitingBench",Vector3(-3,0.47,z),Vector3(0.68,0.12,2.2),b.wood)
		for dz in [-0.85,0.85]:
			b.piece(b,"WaitingBenchLeg",Vector3(-3,0.22,z+dz),Vector3(0.52,0.44,0.10),b.wood,false)
	for level in 2:
		var y: float = level*b.floor_y
		for z in [-7.0,4.0]:
			if level!=0 or z!=-7.0:chair(b,Vector3(-9.5,y,z+(.82 if level==0 and is_equal_approx(z,4.0) else 1.2)))
			papers(b,Vector3(-9.2 if level==0 and is_equal_approx(z,4.0) else -9.85,y+0.93,z))
			lamp(b,"OfficeOilLamp",Vector3(-12.6,y+2.2,z),5.5,y+4.94)
		# Freestanding register cabinet beside the office bay.
		b.piece(b,"RegisterCabinetBack",Vector3(-12.75,y+1.2,-9.5),Vector3(0.08,2.25,2.5),b.wood,false)
		for shelf in 4:
			b.piece(b,"StationRegisterShelf",Vector3(-12.45,y+0.50+shelf*0.48,-9.5),Vector3(0.55,0.065,2.5),b.wood)
			for bundle in 5:
				b.piece(b,"TiedRegisterBundle",Vector3(-12.45,y+0.60+shelf*0.48,-10.4+bundle*0.43),Vector3(0.43,0.13,0.30),b.ochre,false)
		lamp(b,"HallOilLamp",Vector3(5,y+2.4,12),7.0,y+4.94)
	# Furnish room edges while leaving the inquiry seats, drawer and door approaches clear.
	for level in 2:
		var y: float = level*b.floor_y
		for z in [-10.9, 8.0]:
			b.piece(b,"StationRecordChest",Vector3(-12.5,y+.36,z),Vector3(1.0,.72,.62),b.wood)
			b.piece(b,"ChestLidRim",Vector3(-12.5,y+.74,z),Vector3(1.04,.07,.66),b.wood,false)
		for z in [-10.8, 7.8]:
			b.piece(b,"OfficeWallBoard",Vector3(-7.0,y+1.65,z),Vector3(1.1,.75,.08),b.wood,false)
			b.piece(b,"OfficePinnedNotice",Vector3(-7.0,y+1.66,z+.046),Vector3(.72,.48,.012),b.material(Color(.72,.66,.51)),false)
		# A narrow writing shelf and document bundles give each bay a distinct purpose.
		b.piece(b,"OfficeSideWritingShelf",Vector3(-12.25,y+.82,1.0),Vector3(.65,.09,1.65),b.wood)
		for bundle in 3:
			b.piece(b,"OfficeFileBundle",Vector3(-12.25,y+.92,.48+bundle*.50),Vector3(.47,.12,.35),b.ochre,false)
	# Senior chamber: a wall map and an additional visitor chair flank the existing
	# mission desk without moving the officer, visitor seats or revolver drawer.
	b.piece(b,"SeniorWallMapFrame",Vector3(-11.1,1.68,-11.82),Vector3(1.45,1.0,.08),b.wood,false)
	b.piece(b,"SeniorWallMap",Vector3(-11.1,1.68,-11.77),Vector3(1.28,.83,.015),b.material(Color(.70,.63,.48)),false)
	b.piece(b,"SeniorDistrictChartFrame",Vector3(-12.85,1.85,-4.5),Vector3(.08,1.12,1.75),b.wood,false)
	b.piece(b,"SeniorDistrictChart",Vector3(-12.79,1.85,-4.5),Vector3(.015,.96,1.58),b.material(Color(.69,.62,.47)),false)
	for mark in 4:
		b.piece(b,"DistrictChartMark",Vector3(-12.778,1.62+mark*.15,-4.5+mark*.12),Vector3(.006,.018,.75),b.wood,false)
	chair(b,Vector3(-11.9,0,-3.65),-PI*.5)
	# Officer's wall board, duty pegs and folded bedding make upper rooms distinct.
	b.piece(b,"OfficerNoticeBoard",Vector3(-10,b.floor_y+1.7,8.82),Vector3(1.30,0.90,0.07),b.wood,false)
	for x in [-11.8,-11.2,-10.6,-10.0]:
		b.piece(b,"DutyCoatPeg",Vector3(x,b.floor_y+1.6,-11.82),Vector3(0.045,0.045,0.22),b.wood,false)
	b.piece(b,"DutyStorageChest",Vector3(-11.9,b.floor_y+0.32,-4.2),Vector3(1.1,0.64,0.62),b.wood)
	b.piece(b,"FoldedDutyBlanket",Vector3(-11.9,b.floor_y+0.69,-4.2),Vector3(0.85,0.09,0.50),b.ochre,false)
	for z in [-10.0,4.0]:
		lamp(b,"CellarOilLamp",Vector3(6,-1.65,z),7.5,-0.38)
	b.set_meta("station_room_program",["reception","records","report_office","officer_room","duty_room","armoury","holding_cells","lower_detention"])
	b.set_meta("station_local_lights",8)


static func forecourt_gate(b: Node3D) -> void:
	# Open hardwood leaves sit beyond the five-metre station approach.
	var gate_z := 24.0
	for side in [-1.0,1.0]:
		var pier_at := Vector3(side*3.45,0,gate_z)
		var at: Vector3 = b.to_global(pier_at)
		pier_at.y = b.layout.height(at.x,at.z)-b.global_position.y
		b.piece(b,"ThanaGatePier",pier_at+Vector3.UP*1.46,Vector3(.75,3.3,.76),b.stone)
		b.piece(b,"ThanaGateCoping",pier_at+Vector3.UP*3.12,Vector3(.92,.16,.92),b.plaster,false)
		var wing := Vector3(side*6.60,0,gate_z)
		var wing_world: Vector3 = b.to_global(wing)
		wing.y = b.layout.height(wing_world.x,wing_world.z)-b.global_position.y
		b.piece(b,"ThanaForecourtWall",wing+Vector3.UP*.79,Vector3(5.7,2.0,.43),b.stone)
		b.piece(b,"ThanaWallCoping",wing+Vector3.UP*1.84,Vector3(5.8,.12,.58),b.plaster,false)
		var leaf := Node3D.new();leaf.name="OpenThanaTimberGate"
		b.add_child(leaf);leaf.position=pier_at+Vector3(-side*.23,.12,-.3)
		for plank in 11:
			b.piece(leaf,"GatePlank",Vector3(0,1.22,-.12-plank*.21),Vector3(.115,2.43,.205),b.wood,false)
		for height in [.34,1.18,2.10]:
			b.piece(leaf,"GateCrossRail",Vector3(.075,height,-1.17),Vector3(.095,.15,2.42),b.wood,false)
		for height in [.36,2.11]:
			b.piece(leaf,"GateHingeStrap",Vector3(.134,height,-.30),Vector3(.032,.115,.62),b.iron,false)
		b.piece(leaf,"GateLeafSupport",Vector3(0,1.22,-1.17),Vector3(.14,2.44,2.36),b.wood).get_child(0).hide()

	var alarm := preload("res://world/suryagarh/settlements/thana_alarm_bell.gd").new()
	alarm.name = "ThanaAlarmBell"
	var bell_at := Vector3(-3.45,2.58,24.70)
	var bell_ground: Vector3 = b.to_global(Vector3(bell_at.x,0,bell_at.z))
	bell_at.y += b.layout.height(bell_ground.x,bell_ground.z)-b.global_position.y
	b.add_child(alarm);alarm.position=bell_at
	b.piece(b,"BellTimberBracket",bell_at+Vector3(0,.29,-.30),Vector3(.20,.18,.84),b.wood,false)


static func escape_window(b: Node3D) -> void:
	var wall: float=b.width*.5
	var bay:=4.0
	var portal:=Marker3D.new()
	portal.name="StationEscapeWindow"
	portal.set_meta("deep_sill",true)
	portal.position=Vector3(wall,1.30,bay)
	portal.add_to_group("climbable_windows")
	b.add_child(portal)
	b.piece(b,"WindowDeskTop",Vector3(wall-1.25,.66,bay),Vector3(2.0,.12,2.25),b.wood)
	b.piece(b,"WindowDeskFootstool",Vector3(wall-2.69,.31,bay),Vector3(.88,.10,1.25),b.wood)
	for z in [bay-.5,bay+.5]:
		b.piece(b,"WindowDeskFootstoolTrestle",Vector3(wall-2.69,.13,z),Vector3(.70,.26,.12),b.wood,false)
	for x in [wall-2.12,wall-.38]:
		for z in [bay-1.0,bay+1.0]:
			b.piece(b,"WindowDeskLeg",Vector3(x,.30,z),Vector3(.12,.60,.12),b.wood,false)
	for z in [bay-1.0,bay+1.0]:
		b.piece(b,"WindowDeskApron",Vector3(wall-1.25,.55,z),Vector3(1.85,.15,.09),b.wood,false)
	papers(b,Vector3(wall-1.55,.75,bay+.83))
	b.piece(b,"WindowOuterStep",Vector3(wall+.82,.66,bay),Vector3(1.14,.16,2.35),b.wood)
	for z in [bay-1.0,bay+1.0]:
		var post_at:=Vector3(wall+1.28,0,z)
		var world_at: Vector3=b.to_global(post_at)
		var ground: float=b.layout.height(world_at.x,world_at.z)-b.global_position.y
		var bottom:=minf(ground-.18,.5)
		b.piece(b,"WindowStepTimberPost",Vector3(post_at.x,(bottom+.58)*.5,z),Vector3(.15,.58-bottom,.15),b.wood)
