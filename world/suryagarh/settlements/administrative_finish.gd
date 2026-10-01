extends RefCounted
## Original joinery and surface detail; retain existing access and no building text.
var b: Node3D
var timber: Material
var lime: Material
var paving: Material
var roof: Material
var iron: Material
var brick: Material
func build(builder: Node3D, district: Node3D) -> void:
	b = builder
	lime = preload("res://world/suryagarh/settlements/building_realism.gd").finish(Color(.77,.735,.64),10.0)
	paving = preload("res://world/suryagarh/settlements/building_realism.gd").finish(Color(.46,.445,.39),10.0,true)
	timber = surface(Color(.30,.20,.115),2)
	brick = surface(Color(.48,.29,.18),1)
	roof = preload("res://world/suryagarh/settlements/military_detail.gd").surface(Color(.45,.255,.16),3)
	iron = b.iron
	for room in district.get_children():
		if not room is Node3D: continue
		for mesh in room.find_children("*","MeshInstance3D",true,false):
			if mesh.material_override == b.plaster: mesh.material_override = lime
			elif mesh.material_override == b.stone: mesh.material_override = paving
			elif mesh.material_override == b.wood: mesh.material_override = timber
			elif mesh.material_override == b.tile: mesh.material_override = roof
			elif mesh.material_override == b.brick: mesh.material_override = brick
		for part in room.get_children():
			if str(part.name).begins_with("Ledger"):
				room.remove_child(part)
				part.free()
		var dimensions: Vector2 = room.get_meta("room_dimensions")
		front_windows(room,dimensions.x,dimensions.y)
		exterior(room,dimensions.x,dimensions.y)
		roof_structure(room,dimensions.x,dimensions.y)
		if room.name == "Collectorate":
			for x in [-10.0,0.0,10.0]: writing_station(room,Vector3(x,.24,-3))
			for x in [-13.6,-3.6,6.4]: shelves(room,Vector3(x,.24,-3),PI/2)
		elif room.name == "DistrictTreasury":
			for x in [-6.0,6.0]:
				writing_station(room,Vector3(x,.24,2))
				counting_tray(room,Vector3(x-.75,1.08,2.3))
			shelves(room,Vector3(-8,.24,-7.8),0)
		elif room.name == "BritishCourthouse":
			writing_station(room,Vector3(0,.42,-7.5))
			writing_station(room,Vector3(11,.24,-7))
			# Low front rail flanks a clear central opening to the dais.
			for x in [-4.0,4.0]:
				b.piece(room,"DaisRail",Vector3(x,.99,-5.3),Vector3(3.7,.10,.09),timber,false)
				for dx in [-1.7,0,1.7]: b.piece(room,"DaisRailPost",Vector3(x+dx,.67,-5.3),Vector3(.075,.74,.075),timber,false)
		for piece in room.get_children():
			if str(piece.name).begins_with("WaitingBench"):
				var at: Vector3 = piece.position
				b.piece(room,"BenchStretcher",at+Vector3(0,-.22,0),Vector3(3.4,.075,.08),timber,false)
		# Warm local lamps off the clear central walking strip.
		for x in [-dimensions.x*.28,dimensions.x*.28]: lamp(room,Vector3(x,2.85,dimensions.y*.15))
func exterior(room: Node3D,w: float,d: float) -> void:
	for side in [-1,1]:
		b.piece(room,"StoneSplashCourse",Vector3(side*(w/2+.025),.45,0),Vector3(.45,.42,d),paving,false)
		b.piece(room,"DoorJamb",Vector3(side*1.46,1.39,d/2+.07),Vector3(.10,2.3,.48),timber,false)
	b.piece(room,"DoorHead",Vector3(0,2.57,d/2+.08),Vector3(3.03,.12,.48),timber,false)
	b.piece(room,"DoorThreshold",Vector3(0,.255,d/2),Vector3(2.9,.03,.5),paving,false)
	var bays := int(w/4)
	var span := w/bays
	for i in bays:
		var x: float = -w/2+span*(i+.5)
		var opening: float = span-1.6
		b.piece(room,"ProjectedWindowSill",Vector3(x,1.43,-d/2-.08),Vector3(opening+.24,.12,.65),paving,false)
		for side in [-1,1]:
			b.piece(room,"WindowFrameJamb",Vector3(x+side*opening/2,2.1,-d/2),Vector3(.075,1.35,.48),timber,false)
			var shutter := Node3D.new()
			shutter.name = "OpenWindowShutter"
			room.add_child(shutter)
			shutter.position = Vector3(x+side*opening/2,1.47,-d/2-.26)
			shutter.rotation.y = -side*1.20
			panel(shutter,side,opening/2-.045,1.26)
		b.piece(room,"WindowFrameHead",Vector3(x,2.77,-d/2),Vector3(opening+.1,.08,.48),timber,false)
	# The veranda has supported fascia rather than a floating thin roof edge.
	b.piece(room,"VerandaFascia",Vector3(0,3.04,d/2+4.30),Vector3(w+.8,.23,.10),timber,false)
	b.piece(room,"VerandaTieBeam",Vector3(0,3.03,d/2+3.60),Vector3(w-.8,.18,.18),timber,false)
	for x in [-w/2+1,-w/4,w/4,w/2-1]:
		for side in [-1,1]:
			var brace: Node3D = b.piece(room,"VerandaKneeBrace",Vector3(x+side*.26,2.80,d/2+3.6),Vector3(.76,.07,.10),timber,false)
			brace.rotation.z = side*.65
func panel(parent: Node3D,side: int,width: float,height: float) -> void:
	for i in 6:
		var x: float = -side*width*(i+.5)/6
		b.piece(parent,"TimberLeafBoard",Vector3(x,height/2,0),Vector3(width/6-.008,height,.055),timber,false)
	for y in [height*.18,height*.82]:
		b.piece(parent,"LeafCrossRail",Vector3(-side*width/2,y,.04),Vector3(width,.085,.055),timber,false)
		b.piece(parent,"IronHingeStrap",Vector3(-side*width*.18,y,-.035),Vector3(width*.36,.035,.018),iron,false)
		b.piece(parent,"HingePin",Vector3(0,y,0),Vector3(.035,.12,.07),iron,false)
func roof_structure(room: Node3D,w: float,d: float) -> void:
	for side in [-1,1]:
		var skin: Node3D = b.piece(room,"TimberRoofUnderside",Vector3(side*w/4,3.7+w*.03-.14,0),Vector3(w/2+.45,.055,d+.9),timber,false)
		skin.rotation.z = -side*.12
		b.piece(room,"WallPlate",Vector3(side*(w/2-.24),3.57,0),Vector3(.16,.17,d-.3),timber,false)
	for z in range(-int(d/2)+1,int(d/2),4):
		b.piece(room,"RoofTieBeam",Vector3(0,3.52,z),Vector3(w-.35,.18,.18),timber,false)
		for side in [-1,1]:
			var rafter: Node3D = b.piece(room,"RoofRafter",Vector3(side*w/4,3.7+w*.03-.22,z),Vector3(w/2+.15,.13,.12),timber,false)
			rafter.rotation.z = -side*.12
		b.piece(room,"KingPost",Vector3(0,3.6+w*.03,z),Vector3(.13,w*.06,.13),timber,false)
	b.piece(room,"VerandaSoffit",Vector3(0,3.04,d/2+2),Vector3(w+.4,.055,4.5),timber,false)
func writing_station(room: Node3D,at: Vector3) -> void:
	for side in [-1,1]:
		b.piece(room,"DeskApron",at+Vector3(0,.67,side*.43),Vector3(2.0,.17,.07),timber,false)
		b.piece(room,"DeskStretcher",at+Vector3(0,.23,side*.35),Vector3(1.8,.075,.075),timber,false)
	b.piece(room,"DeskDrawer",at+Vector3(0,.66,.49),Vector3(.78,.14,.03),timber,false)
	b.piece(room,"DrawerPull",at+Vector3(0,.66,.52),Vector3(.16,.025,.025),iron,false)
	b.piece(room,"InkPot",at+Vector3(.73,.89,-.10),Vector3(.085,.1,.085),iron,false)
	b.piece(room,"ReedPen",at+Vector3(.7,.86,.16),Vector3(.19,.009,.009),timber,false).rotation.y = .35
	var folio: Node3D = load("res://objects/household/supplies/record_folio.tscn").instantiate()
	room.add_child(folio)
	folio.position = at+Vector3(-.48,.845,0)
	chair(room,at+Vector3(0,0,-1.13))
func chair(room: Node3D,at: Vector3) -> void:
	var node := Node3D.new()
	node.name = "OfficeChair"
	node.add_to_group("administrative_chairs")
	room.add_child(node)
	node.position = at
	b.piece(node,"Seat",Vector3(0,.46,0),Vector3(.60,.09,.58),timber)
	for x in [-.24,.24]:
		for z in [-.23,.23]: b.piece(node,"ChairLeg",Vector3(x,.21,z),Vector3(.065,.42,.065),timber,false)
		b.piece(node,"BackPost",Vector3(x,.75,-.23),Vector3(.065,.65,.065),timber,false)
		b.piece(node,"ChairStretcher",Vector3(x,.19,0),Vector3(.05,.06,.46),timber,false)
	for y in [.69,.93]: b.piece(node,"BackRail",Vector3(0,y,-.23),Vector3(.54,.085,.055),timber,false)
func shelves(room: Node3D,at: Vector3,yaw: float) -> void:
	var node := Node3D.new()
	node.name = "RecordsRack"
	room.add_child(node)
	node.position = at
	node.rotation.y = yaw
	for x in [-.92,.92]: b.piece(node,"RackUpright",Vector3(x,1.0,0),Vector3(.09,2,.48),timber)
	for y in [.1,.65,1.2,1.75]:
		b.piece(node,"RackShelf",Vector3(0,y,0),Vector3(1.9,.09,.50),timber,false)
		for i in 3:
			var folio: Node3D = load("res://objects/household/supplies/record_folio.tscn").instantiate()
			node.add_child(folio)
			folio.position = Vector3(-.6+i*.6,y+.05,0)
func lamp(room: Node3D,at: Vector3) -> void:
	var fixture := Node3D.new()
	fixture.name = "OfficeOilLamp"
	room.add_child(fixture)
	fixture.position = at
	for x in [-.09,.09]:
		for z in [-.09,.09]: b.piece(fixture,"LampCage",Vector3(x,0,z),Vector3(.016,.3,.016),iron,false)
	b.piece(fixture,"OilReservoir",Vector3(0,-.15,0),Vector3(.22,.09,.22),iron,false)
	b.piece(fixture,"LampHood",Vector3(0,.19,0),Vector3(.26,.05,.26),iron,false)
	b.piece(fixture,"Suspension",Vector3(0,.43,0),Vector3(.018,.42,.018),iron,false)
	var dimensions: Vector2 = room.get_meta("room_dimensions")
	var roof_y: float = 3.7+dimensions.x*.06-absf(at.x)*.12-.17
	var hanger: float = maxf(.05,roof_y-at.y-.65)
	b.piece(fixture,"RoofHanger",Vector3(0,.65+hanger/2,0),Vector3(.025,hanger,.025),iron,false)
	b.piece(fixture,"HookRail",Vector3(0,roof_y-at.y,0),Vector3(.5,.035,.07),timber,false)
	var flame := StandardMaterial3D.new()
	flame.albedo_color = Color(1,.6,.2)
	flame.emission_enabled = true
	flame.emission = Color(1,.45,.1)
	b.piece(fixture,"Flame",Vector3(0,.01,0),Vector3(.026,.08,.026),flame,false)
	var light := OmniLight3D.new()
	fixture.add_child(light)
	light.light_color = Color(1,.78,.53)
	light.light_energy = .5
	light.omni_range = 7
	light.omni_attenuation = 1.6
	light.shadow_enabled = false

func surface(tint: Color,kind: int) -> Material:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://world/suryagarh/settlements/administrative_surface.gdshader")
	mat.set_shader_parameter("tint",tint)
	mat.set_shader_parameter("kind",kind)
	return mat
func counting_tray(room: Node3D,at: Vector3) -> void:
	b.piece(room,"CountingTrayBase",at+Vector3(0,.015,0),Vector3(.32,.03,.24),timber,false)
	for side in [-1,1]:
		b.piece(room,"TrayRim",at+Vector3(side*.155,.04,0),Vector3(.025,.05,.24),timber,false)
		b.piece(room,"TrayEnd",at+Vector3(0,.04,side*.115),Vector3(.32,.05,.025),timber,false)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(.42,.43,.41)
	metal.metallic = .7
	metal.roughness = .65
	for i in 6:
		var visual := MeshInstance3D.new()
		visual.name = "CountingDisc"
		var mesh := CylinderMesh.new()
		mesh.top_radius = .022
		mesh.bottom_radius = .022
		mesh.height = .004
		mesh.radial_segments = 16
		visual.mesh = mesh
		visual.material_override = metal
		room.add_child(visual)
		visual.position = at+Vector3(-.06+(i%3)*.06,.032,-.03+floori(i/3.0)*.06)

func front_windows(room: Node3D,w: float,d: float) -> void:
	# Replace the two solid door piers with masonry surrounding real apertures.
	for part in room.get_children():
		if part.get_child_count() == 0 or not part.get_child(0) is MeshInstance3D: continue
		var mesh: Mesh = part.get_child(0).mesh
		if mesh is BoxMesh and is_equal_approx(mesh.size.y,3.35) and is_equal_approx(mesh.size.x,w/2-1.5) and part.position.z > 0:
			room.remove_child(part)
			part.free()
	for side in [-1,1]:
		var spans: Array[Vector2] = []
		var centers: Array[float] = [side*(w/4-2.1),side*(w/4+2.1)]
		centers.sort()
		var edge: float = -w/2 if side < 0 else 1.5
		var end: float = -1.5 if side < 0 else w/2
		for x in centers:
			spans.append(Vector2(edge,x-.9))
			edge = x+.9
			b.piece(room,"FrontWindowSill",Vector3(x,1.43,d/2+.08),Vector3(2.04,.12,.65),paving,false)
			for wing in [-1,1]:
				b.piece(room,"FrontFrameJamb",Vector3(x+wing*.9,2.1,d/2),Vector3(.075,1.35,.48),timber,false)
				var shutter := Node3D.new()
				shutter.name = "FrontOpenShutter"
				room.add_child(shutter)
				shutter.position = Vector3(x+wing*.9,1.47,d/2+.26)
				shutter.rotation.y = wing*1.2
				panel(shutter,wing,.855,1.26)
			b.piece(room,"FrontFrameHead",Vector3(x,2.77,d/2),Vector3(1.9,.08,.48),timber,false)
			for dx in [-.6,-.3,0,.3,.6]: b.piece(room,"FrontWindowBar",Vector3(x+dx,2.1,d/2),Vector3(.045,1.35,.045),iron)
		spans.append(Vector2(edge,end))
		for span in spans:
			b.piece(room,"FrontMasonryPier",Vector3((span.x+span.y)/2,1.9,d/2),Vector3(span.y-span.x,3.35,.4),lime)
		var middle: float = side*(w/4+.75)
		var width: float = w/2-1.5
		b.piece(room,"FrontSillWall",Vector3(middle,.825,d/2),Vector3(width,1.2,.4),lime)
		b.piece(room,"FrontHeaderWall",Vector3(middle,3.175,d/2),Vector3(width,.8,.4),lime)
