extends RefCounted
## Separated residential plots and military service market; construction candidates.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
var b: Node3D
var architecture = preload("res://world/suryagarh/settlements/administrative_district.gd").new()

func build(builder: Node3D) -> void:
	b = builder
	var original := {"plaster":b.plaster,"wood":b.wood,"tile":b.tile}
	b.plaster = surface("clay_plaster",Color(.84,.81,.71),false)
	b.wood = surface("dark_wood",Color(.64,.51,.38),true)
	b.tile = b.material(Color(.43,.23,.14))
	var lines := anchor("CivilLines")
	lines.add_to_group("civil_lines")
	lines.set_meta("location_numbers",[9,10])
	architecture.b = b
	architecture.district = lines
	architecture.shell_builder.b = b
	architecture.shell_builder.district = lines
	for spec in [["CollectorBungalow",-40.0,Vector2(24,16)], ["OfficerBungalow",40.0,Vector2(20,14)]]:
		var home: Node3D = architecture.room(spec[0],Vector3(spec[1],0,-10),spec[2],"")
		home.remove_from_group("administrative_buildings")
		home.add_to_group("civil_lines_bungalows")
		home.set_meta("role","collector" if spec[0] == "CollectorBungalow" else "military_officer")
		architecture.desk(home,Vector3(-6,0.24,-3))
		architecture.shell_builder.bed(home,Vector3(6,0.24,-3),true)
		architecture.bench(home,Vector3(8,0.24,spec[2].y/2+2))
		refine_home(home,spec[2])
		# Broad separate compounds with open carriage gates and no wall across the drive.
		for side in [-1.0,1.0]:
			b.piece(lines,"CompoundSide",Vector3(spec[1]+side*32,0.55,-8),Vector3(0.4,1.1,68),b.plaster)
			b.piece(lines,"GateReturn",Vector3(spec[1]+side*18,0.55,26),Vector3(28,1.1,0.4),b.plaster)
		for side in [-1.0,1.0]:
			b.piece(lines,"RearBoundary",Vector3(spec[1]+side*18,0.55,-42),Vector3(28,1.1,0.4),b.plaster)
		for side in [-1.0,1.0]:
			b.piece(lines,"GardenBed",Vector3(spec[1]+side*22,0.12,7),Vector3(7,0.24,22),b.ochre)
		var quarters: Node3D = architecture.room(spec[0]+"ServiceQuarters",Vector3(spec[1],0,-51),Vector2(14,6),"")
		quarters.remove_from_group("administrative_buildings")
		quarters.add_to_group("civil_lines_service_quarters")
		architecture.shell_builder.bed(quarters,Vector3(-4,0.24,0),false)
		b.piece(lines,"RearServiceGate",Vector3(spec[1]+25,0.03,-44),Vector3(5,0.06,8),b.ochre,false)
	# Avenue has a clear centre, with seating and planting kept on its edges.
	for x in [-70.0,-10.0,10.0,70.0]:
		architecture.bench(lines,Vector3(x,0,48))
	for child in lines.get_children():
		if child is Node3D: b.merge_visuals(child)
	bazaar()
	b.plaster = original.plaster
	b.wood = original.wood
	b.tile = original.tile

func anchor(id: String) -> Node3D:
	var plot: Dictionary = Layout.PLOTS[id]
	var node := Node3D.new()
	node.name = id
	node.position = Vector3(plot.center.x,plot.grade,plot.center.y)
	b.add_child(node)
	return node

func bazaar() -> void:
	var market := anchor("CantonmentBazaar")
	market.add_to_group("cantonment_bazaar")
	market.set_meta("location_numbers",[12])
	# Two rows around a ten-metre central service lane; west military approach is open.
	var roles := ["GrainTrader","ClothTrader","Cookshop","Cobbler","Farrier","ProvisionTrader"]
	for i in 6:
		var stall := Node3D.new()
		stall.name = roles[i]
		market.add_child(stall)
		stall.position = Vector3(-26+i%3*26,0,(-1 if i<3 else 1)*20)
		stall.add_to_group("cantonment_bazaar_stalls")
		stall.set_meta("service",roles[i])
		b.piece(stall,"RaisedEarthFloor",Vector3(0,0.08,0),Vector3(9,0.16,8),b.ochre)
		b.piece(stall,"RearWall",Vector3(0,1.55,-3.8),Vector3(9,2.9,0.3),b.brick)
		b.piece(stall,"ShadeRoof",Vector3(0,3.15,0),Vector3(10,0.18,9),b.tile)
		for x in [-4.0,4.0]:
			for z in [-3.4,3.4]: b.piece(stall,"ShadePost",Vector3(x,1.65,z),Vector3(0.18,3.0,0.18),b.wood)
		b.piece(stall,"ServiceCounter",Vector3(0,0.91,1.7),Vector3(5,0.12,1),b.wood)
		for x in [-2.0,2.0]: b.piece(stall,"CounterLeg",Vector3(x,0.48,1.7),Vector3(0.15,0.8,0.8),b.wood)
		for x in [-2.5,2.5]:
			var prop: Node3D = load("res://objects/household/storage/"+("barrel" if i%2 else "crate")+".tscn").instantiate()
			stall.add_child(prop)
			prop.position = Vector3(x,0.16,-2)
		match roles[i]:
			"GrainTrader", "ProvisionTrader":
				for x in [-1.5,0.0,1.5]:
					var sack: Node3D = load("res://objects/household/grain_sack.tscn").instantiate()
					stall.add_child(sack)
					sack.position = Vector3(x,0.16,-1)
			"ClothTrader":
				for j in 3: b.piece(stall,"FoldedCloth",Vector3(-1.5+j*1.5,1.03,1.7),Vector3(1.2,0.12,0.65),b.plaster if j%2 else b.ochre,false)
			"Cookshop":
				b.piece(stall,"CookingHearth",Vector3(-3,0.4,-1),Vector3(1.6,0.48,1.5),b.brick)
				b.piece(stall,"HearthOpening",Vector3(-3,0.5,-0.23),Vector3(0.8,0.3,0.02),b.iron,false)
			"Cobbler":
				for x in [-1.5,0.0,1.5]: b.piece(stall,"LeatherWork",Vector3(x,1.01,1.7),Vector3(0.65,0.05,0.45),b.wood,false)
			"Farrier":
				b.piece(stall,"AnvilBlock",Vector3(-3,0.4,-1),Vector3(0.8,0.48,0.8),b.wood)
				b.piece(stall,"AnvilFoot",Vector3(-3,0.75,-1),Vector3(0.55,0.22,0.5),b.iron)
				b.piece(stall,"AnvilFace",Vector3(-3,0.93,-1),Vector3(1.1,0.14,0.35),b.iron)
		if i >= 3: stall.rotation.y = PI
		var entry := Marker3D.new()
		entry.name = "Entrance"
		entry.position = Vector3(0,0.16,5)
		stall.add_child(entry)
		awning(stall)
		prop(stall,"storage/basket",Vector3(3.2,.16,.2))
		if roles[i] == "Cookshop": prop(stall,"storage/brass_pot",Vector3(-3,.64,-1))
		b.merge_visuals(stall)
	# Supply carts can pause here without occupying the cantonment entrance or bazaar aisle.
	b.piece(market,"CartStanding",Vector3(32,0.03,35),Vector3(18,0.06,12),b.ochre,false)
	for x in [24.0,40.0]: b.piece(market,"TetherPost",Vector3(x,0.7,40),Vector3(0.18,1.4,0.18),b.wood)
	b.piece(market,"TetherRail",Vector3(32,1.1,40),Vector3(16,0.14,0.14),b.wood)

func surface(asset: String, tint: Color, diffuse: bool) -> Material:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	if diffuse: mat.albedo_texture = load("res://assets/architecture/materials/"+asset+"_Diffuse.jpg")
	mat.normal_enabled = true
	mat.normal_texture = load("res://assets/architecture/materials/"+asset+"_nor_gl.jpg")
	mat.normal_scale = 0.32
	mat.roughness_texture = load("res://assets/architecture/materials/"+asset+"_Rough.jpg")
	mat.roughness = 0.85
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE*0.55
	return mat

func refine_home(home: Node3D, size: Vector2) -> void:
	var w := size.x
	var d := size.y
	# Replace sealed side walls with supported, framed windows in actual openings.
	for side in [-1.0,1.0]:
		var nearest: Node3D
		for node in home.get_children():
			if node is Node3D and str(node.name).begins_with("SideWall") and signf(node.position.x)==side: nearest = node
		if nearest != null:
			home.remove_child(nearest)
			nearest.free()
		b.piece(home,"SideSillMasonry",Vector3(side*w/2,0.825,0),Vector3(.4,1.2,d),b.plaster)
		b.piece(home,"SideWindowHeader",Vector3(side*w/2,3.175,0),Vector3(.4,.8,d),b.plaster)
		var opening := 2.4
		for span in [Vector2(-d/2,-d/4-opening/2),Vector2(-d/4+opening/2,d/4-opening/2),Vector2(d/4+opening/2,d/2)]:
			b.piece(home,"SideWindowPier",Vector3(side*w/2,2.1,(span.x+span.y)/2),Vector3(.4,1.35,span.y-span.x),b.plaster)
		for z in [-d/4,d/4]:
			var detail := preload("res://world/suryagarh/settlements/bhairavpur_house_detail.gd").new()
			detail.settlement = b
			detail._window_frame(home,Vector3(side*w/2,1.425,z),Vector2(opening,1.35),side*PI/2,false,true)
			# Place the shutter leaves beyond the interior masonry face, with inner casing.
			# The shared window helper now puts them partly inside a 0.4 m wall.
			var frame: Node3D = home.get_child(home.get_child_count()-1)
			frame.get_node("PairedWoodShutters").position.z = -.28
			for edge in [-1.0,1.0]: b.piece(frame,"InnerWindowJamb",Vector3(edge*(opening/2+.025),.675,-.28),Vector3(.09,1.51,.16),b.wood,false)
			for y in [-.02,1.37]: b.piece(frame,"InnerWindowRail",Vector3(0,y,-.28),Vector3(opening+.16,.09,.16),b.wood,false)
		b.piece(home,"RoofFascia",Vector3(side*(w/2+.4),3.67,0),Vector3(.12,.22,d+1.4),b.wood,false)
		b.piece(home,"VerandaSkirting",Vector3(side*(w/4+.85),.36,d/2+.22),Vector3(w/2-1.7,.2,.09),b.wood,false)
	for x in [-1.55,1.55]: b.piece(home,"EntranceJamb",Vector3(x,1.54,d/2+.23),Vector3(.12,2.6,.16),b.wood,false)
	b.piece(home,"DoorFrameHead",Vector3(0,2.84,d/2+.23),Vector3(3.2,.14,.16),b.wood,false)
	var door := preload("res://objects/hinged_door.gd").new()
	door.name = "BungalowEntranceDoor"
	door.width = 2.9
	door.height = 2.5
	door.night_lock = false
	door.position = Vector3(-1.45,.24,d/2+.24)
	door.build(b.wood)
	home.add_child(door)
	# Interior ceiling and supporting timber keep the underside of roof tiles concealed.
	b.piece(home,"LimeCeiling",Vector3(0,3.57,0),Vector3(w-.4,.06,d-.4),b.plaster,false)
	for z in [-d/3,0.0,d/3]: b.piece(home,"CeilingTieBeam",Vector3(0,3.42,z),Vector3(w-.4,.22,.18),b.wood,false)
	# Timber floor boards sit directly on the supporting stone base.
	for i in int(w/.65):
		b.piece(home,"Floorboard",Vector3(-w/2+.34+i*.65,.25,0),Vector3(.64,.02,d-.4),b.wood,false)
	for z in [-d/2+.23,d/2-.23]:
		for side in [-1.0,1.0]: b.piece(home,"WallSkirting",Vector3(side*(w/4+1),.36,z),Vector3(w/2-2,.18,.08),b.wood,false)
	# Bearing walls divide a central reception hall from office and sleeping rooms.
	# Their heads meet the ceiling ties; open doors retain a clear cross-house route.
	for x in [-3.5,3.5]:
		for side in [-1.0,1.0]:
			b.piece(home,"RoomBearingWall",Vector3(x,1.77,side*(d/4+.55)),Vector3(.18,3.06,d/2-1.1),b.plaster)
		b.piece(home,"RoomDoorHead",Vector3(x,2.92,0),Vector3(.18,.76,2.2),b.plaster)
		for z in [-1.12,1.12]: b.piece(home,"RoomDoorJamb",Vector3(x,1.39,z),Vector3(.23,2.3,.12),b.wood,false)
		b.piece(home,"RoomDoorTimberHead",Vector3(x,2.57,0),Vector3(.23,.12,2.35),b.wood,false)
	# Reception furniture sits behind the entrance-to-centre walking path.
	architecture.desk(home,Vector3(0,.26,-3.5))
	chair(home,Vector3(-2,.26,-3.5),PI/2)
	chair(home,Vector3(2,.26,-3.5),-PI/2)
	prop(home,"storage/brass_pot",Vector3(.6,1.10,-3.5))
	b.piece(home,"BedHeadboard",Vector3(6,1.04,-3.93),Vector3(1.42,.9,.12),b.wood)
	for x in [5.4,6.6]: b.piece(home,"BedHeadPost",Vector3(x,.82,-3.93),Vector3(.09,1.16,.09),b.wood)
	bookcase(home,Vector3(-w/2+.5,.26,0))
	chair(home,Vector3(-6,.26,-1.8),PI)
	architecture.desk(home,Vector3(-w/3,.26,3))
	chair(home,Vector3(-w/3,.26,4.2),PI)
	for spec in [["supplies/record_folio",Vector3(-6,1.08,-3)],["oil_lamp_visual",Vector3(-5.3,1.08,-3)],["storage/brass_pot",Vector3(-w/3,1.10,3)],["woven_mat",Vector3(6,.265,1)],["storage/crate",Vector3(w/2-2,.26,-d/2+2)]]:
		prop(home,spec[0],spec[1])
	b.piece(home,"Pillow",Vector3(6,.9,-3.72),Vector3(.85,.18,.45),b.plaster,false)
	b.piece(home,"BedCoverFold",Vector3(6,.83,-2.5),Vector3(1.2,.07,.65),b.ochre,false)
	architecture.desk(home,Vector3(w/2-3,.26,3))
	prop(home,"water_pot_visual",Vector3(w/2-3,1.10,3))
	for side in [-1.0,1.0]:
		b.piece(home,"WallPictureFrame",Vector3(-w/3+side*1.5,2.25,d/2-.23),Vector3(1.3,1.0,.1),b.wood,false)
		b.piece(home,"WallPicturePaper",Vector3(-w/3+side*1.5,2.25,d/2-.29),Vector3(1.12,.82,.015),b.ochre,false)
	chair(home,Vector3(-w/3,.26,d/2+2),PI)
	prop(home,"storage/brass_pot",Vector3(-w/3+1,.24,d/2+2))

func prop(parent: Node3D, slug: String, at: Vector3) -> void:
	var node: Node3D = load("res://objects/household/"+slug+".tscn").instantiate()
	parent.add_child(node)
	node.position = at

func chair(parent: Node3D, at: Vector3, yaw: float) -> void:
	var node := Node3D.new()
	parent.add_child(node)
	node.position = at
	node.rotation.y = yaw
	b.piece(node,"ChairSeat",Vector3(0,.47,0),Vector3(.65,.1,.65),b.wood)
	for x in [-.25,.25]:
		for z in [-.25,.25]: b.piece(node,"ChairLeg",Vector3(x,.22,z),Vector3(.075,.44,.075),b.wood)
	for x in [-.25,.25]: b.piece(node,"ChairBackPost",Vector3(x,.84,-.25),Vector3(.075,.74,.075),b.wood)
	for y in [.78,1.1]: b.piece(node,"ChairBackRail",Vector3(0,y,-.25),Vector3(.57,.085,.075),b.wood)

func awning(stall: Node3D) -> void:
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(.66,.55,.36)
	cloth.roughness = 1.0
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 8:
		var x0 := -4.4+i*1.1
		var x1 := x0+1.1
		var a := Vector3(x0,3.05,3.4)
		var c := Vector3(x1,3.05,3.4)
		var f0 := Vector3(x0,2.75-.09*sin(float(i)/8*PI),5.7)
		var f1 := Vector3(x1,2.75-.09*sin(float(i+1)/8*PI),5.7)
		for point in [a,c,f0,c,f1,f0]: st.add_vertex(point)
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = "CanvasServiceAwning"
	mesh.mesh = st.commit()
	mesh.material_override = cloth
	stall.add_child(mesh)
	for x in [-4.2,4.2]:
		b.piece(stall,"AwningPost",Vector3(x,1.43,5.5),Vector3(.12,2.86,.12),b.wood)
	b.piece(stall,"AwningFrontRail",Vector3(0,2.78,5.5),Vector3(8.5,.08,.08),b.wood,false)

func bookcase(home: Node3D, at: Vector3) -> void:
	var node := Node3D.new()
	node.name = "OfficeBookcase"
	node.position = at
	home.add_child(node)
	for z in [-.85,.85]: b.piece(node,"BookcaseUpright",Vector3(0,1.1,z),Vector3(.55,2.2,.09),b.wood)
	b.piece(node,"BookcaseBacking",Vector3(-.24,1.1,0),Vector3(.06,2.2,1.75),b.wood)
	for y in [.08,.72,1.38,2.13]: b.piece(node,"BookcaseShelf",Vector3(0,y,0),Vector3(.55,.08,1.8),b.wood)
	for y in [.15,.79,1.45]:
		for i in 7:
			b.piece(node,"BoundVolume",Vector3(.04,y+.19,-.65+i*.21),Vector3(.32,.38+(i%3)*.035,.16),b.ochre if i%2 else b.wood,false)
