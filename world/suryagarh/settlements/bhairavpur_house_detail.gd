extends RefCounted
## Physical roof, opening and craft details applied before village mesh batching.
const Surface = preload("res://world/suryagarh/settlements/village_surface.gdshader")
const WORKSHOPS := {25: "carpenter", 27: "weaver", 30: "potter"}
const MARKET_GOODS := ["produce","grain","cloth","pottery","produce","grain","cloth","timber"]
var settlement
var palette: Array[Material]
var roof_tile: Material
var roof_straw: Material
var roof_earth: Material
var clay: Material
var cloth: Array[Material]

func configure(builder, wall_palette: Array[Material]) -> void:
	settlement = builder
	palette = wall_palette
	roof_tile = _surface(Color(.40,.18,.09),0)
	roof_straw = _surface(Color(.54,.42,.23),1)
	roof_earth = builder.material(Color(.53,.43,.29))
	clay = builder.material(Color(.53,.28,.15))
	cloth = [_surface(Color(.27,.34,.39),2),_surface(Color(.57,.34,.24),2),_surface(Color(.65,.57,.38),2)]

func _surface(color: Color, kind: int) -> Material:
	var material := ShaderMaterial.new()
	material.shader = Surface
	material.set_shader_parameter("tint",color)
	material.set_shader_parameter("surface_kind",kind)
	return material

func _piece(parent: Node3D,label: String,at: Vector3,size: Vector3,material: Material,solid := true) -> Node3D:
	return settlement.piece(parent,label,at,size,material,solid)

func house(house_node: Node3D,extent: Vector2,index: int) -> void:
	_roof(house_node,extent,index)
	_openings(house_node,extent,index)
	if index != 0:
		_interior(house_node,extent,index)
	if index >= 8 and index%3 == 0:
		var z := extent.y*.5+5.2
		for side in [-1.0,1.0]:
			_piece(house_node,"CourtyardGatePost",Vector3(side*1.34,1.05,z),Vector3(.14,2.1,.14),settlement.wood)
		_piece(house_node,"CourtyardGateBeam",Vector3(0,2.1,z),Vector3(2.9,.13,.18),settlement.wood)
	if WORKSHOPS.has(index):
		house_node.add_to_group("bhairavpur_workshop")
		house_node.set_meta("craft",WORKSHOPS[index])
		_workshop(house_node,extent,WORKSHOPS[index])

func _roof(house_node: Node3D,extent: Vector2,index: int) -> void:
	for node: Node in house_node.get_children():
		var old_roof := false
		for child in node.get_children():
			if child is MeshInstance3D and child.material_override == settlement.tile: old_roof = true
		if old_roof:
			node.free()
	var w := extent.x
	var d := extent.y
	const WALL_TOP := 3.04
	if index%4 == 2:
		house_node.set_meta("roof_style","earth terrace")
		_piece(house_node,"TerraceRoof",Vector3(0,WALL_TOP+.12,0),Vector3(w+.4,.24,d+.4),roof_earth)
		for side in [-1.0,1.0]:
			_piece(house_node,"TerraceSideParapet",Vector3(side*w*.5,WALL_TOP+.43,0),Vector3(.22,.38,d+.2),palette[index%palette.size()])
			_piece(house_node,"TerraceEndParapet",Vector3(0,WALL_TOP+.43,side*d*.5),Vector3(w,.38,.22),palette[index%palette.size()])
		for z in [-d*.35,0.0,d*.35]:
			_piece(house_node,"CeilingJoist",Vector3(0,WALL_TOP-.08,z),Vector3(w,.16,.18),settlement.wood,false)
		return
	var straw := index%4 == 1
	house_node.set_meta("roof_style","thatch gable" if straw else "clay tile gable")
	var angle := .43 if straw else .27
	var thickness := .32 if straw else .18
	var ridge_y: float = WALL_TOP+w*.5*tan(angle)+.12
	var half_span := w*.5+.55
	var roof: Material = roof_straw if straw else roof_tile
	for side in [-1.0,1.0]:
		_piece(house_node,"DetailedRoofSlope",Vector3(side*half_span*.5,ridge_y-half_span*.5*tan(angle),0),Vector3(half_span/cos(angle),thickness,d+1.2),roof).rotation.z = -side*angle
		var gable := Node3D.new()
		gable.name = "ClosedGable"
		gable.position = Vector3(0,WALL_TOP,side*d*.5)
		house_node.add_child(gable)
		var mesh := MeshInstance3D.new()
		mesh.mesh = _gable_mesh(w,ridge_y-WALL_TOP-thickness*.5,.22)
		mesh.material_override = palette[index%palette.size()]
		gable.add_child(mesh)
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		collision.shape = mesh.mesh.create_convex_shape(true,true)
		body.add_child(collision)
		gable.add_child(body)
		_piece(house_node,"GableTieBeam",Vector3(0,WALL_TOP-.03,side*d*.5),Vector3(w,.14,.20),settlement.wood,false)
	_piece(house_node,"DetailedRoofRidge",Vector3(0,ridge_y+.04,0),Vector3(.22,.18,d+1.3),roof,false)
	_piece(house_node,"InteriorRidgeBeam",Vector3(0,ridge_y-.2,0),Vector3(.18,.18,d),settlement.wood,false)

func _gable_mesh(width: float,height: float,depth: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertices: Array[Vector3] = [Vector3(-width*.5,0,-depth*.5),Vector3(width*.5,0,-depth*.5),Vector3(0,height,-depth*.5),Vector3(-width*.5,0,depth*.5),Vector3(width*.5,0,depth*.5),Vector3(0,height,depth*.5)]
	for i in [0,2,1, 3,4,5, 0,1,3, 1,4,3, 0,3,2, 3,5,2, 1,2,4, 2,5,4]:
		var p := vertices[i]
		surface.set_uv(Vector2(p.x/width+.5,p.y/maxf(height,.01)))
		surface.add_vertex(p)
	surface.generate_normals()
	surface.generate_tangents()
	surface.index()
	return surface.commit()

func _openings(house_node: Node3D,extent: Vector2,index: int) -> void:
	var w := extent.x
	var d := extent.y
	var wall: Material = palette[index%palette.size()]
	house_node.get_node("BackWall").free()
	# An actual rear opening breaks up the otherwise blank central-lane frontage.
	_piece(house_node,"RearSillWall",Vector3(0,.745,-d*.5),Vector3(w,1.01,.38),wall)
	_piece(house_node,"RearHeadWall",Vector3(0,2.57,-d*.5),Vector3(w,.94,.38),wall)
	for side in [-1.0,1.0]:
		_piece(house_node,"RearWindowPier",Vector3(side*(w+1.4)*.25,1.675,-d*.5),Vector3((w-1.4)*.5,.85,.38),wall)
		_piece(house_node,"RearWindowJamb",Vector3(side*.71,1.675,-d*.5-.21),Vector3(.09,.93,.12),settlement.wood,false)
		_piece(house_node,"DoorJamb",Vector3(side*1.31,1.425,d*.5+.20),Vector3(.12,2.37,.12),settlement.wood,false)
	for y in [1.25,2.1]:
		_piece(house_node,"RearWindowRail",Vector3(0,y,-d*.5-.21),Vector3(1.5,.09,.12),settlement.wood,false)
	_piece(house_node,"DoorHeader",Vector3(0,2.65,d*.5+.20),Vector3(2.75,.16,.12),settlement.wood,false)
	_piece(house_node,"EntranceApron",Vector3(0,.015,d*.5+1.75),Vector3(2.7,.03,1.5),roof_earth,false)
	var door := preload("res://objects/hinged_door.gd").new()
	door.name = "EntranceDoor"
	door.position = Vector3(-1.3,.24,d*.5+.20)
	door.night_lock = index != 0 and index%5 != 0
	door.always_open = WORKSHOPS.has(index)
	door.build(settlement.wood)
	house_node.add_child(door)
	# A few unbarred openings support deliberate infiltration; most cannot be crossed.
	var accessible := index in [4,11,19,28]
	var grille := index%3 == 2
	house_node.set_meta("window_access", "open" if accessible else ("iron grille" if grille else "wood shutter"))
	for side in [-1.0,1.0]:
		if accessible:
			var portal := Node3D.new()
			portal.name = "OpenWindowTraversal"
			portal.position = Vector3(side*w*.5,1.34,0)
			house_node.add_child(portal)
			portal.add_to_group("climbable_windows")
			continue
		if grille:
			for bar in 8:
				_piece(house_node,"SideWindowIronBar",Vector3(side*w*.5,1.915,-.96+bar*.275),Vector3(.07,1.15,.055),settlement.iron,false)
			# Continuous physical envelope prevents capsule squeezing between bars.
			_window_barrier(house_node,Vector3(side*w*.5,1.915,0),Vector3(.12,1.15,2.2))
		else:
			pass # Framed paired shutters above provide matching moving collision.
	_window_frame(house_node,Vector3(0,1.25,-d*.5),Vector2(1.4,.85),PI,accessible,not grille and not accessible)
	if not accessible:
		if grille:
			for bar in 7:
				_piece(house_node,"RearWindowIronBar",Vector3(-.60+bar*.2,1.675,-d*.5),Vector3(.055,.85,.07),settlement.iron,false)
			_window_barrier(house_node,Vector3(0,1.675,-d*.5),Vector3(1.4,.85,.12))
		else:
			pass # Actual hinged rear shutters are installed in the window frame.

func _window_frame(parent: Node3D,at: Vector3,size: Vector2,yaw: float,open_entry: bool,shuttered: bool) -> void:
	var frame := Node3D.new()
	frame.name="TimberWindowFrame"
	frame.position=at
	frame.rotation.y=yaw
	parent.add_child(frame)
	for side in [-1.0,1.0]:
		_piece(frame,"WindowJamb",Vector3(side*(size.x*.5+.025),size.y*.5,.12),Vector3(.09,size.y+.16,.16),settlement.wood,false)
	for y in [-.02,size.y+.02]:
		_piece(frame,"WindowFrameRail",Vector3(0,y,.12),Vector3(size.x+.16,.09,.16),settlement.wood,false)
	if shuttered:
		var shutter := preload("res://objects/hinged_door.gd").new()
		shutter.name="PairedWoodShutters"
		shutter.width=size.x
		shutter.height=size.y
		shutter.position=Vector3(-size.x*.5,0,.14)
		shutter.opened=false
		shutter.inside_only=true
		shutter.auto_open_at_dawn=false
		shutter.label_name="shutters"
		shutter.build(settlement.wood)
		frame.add_child(shutter)
	elif open_entry:
		for side in [-1.0,1.0]:
			var leaf := _piece(frame,"HeldOpenShutter",Vector3(side*(size.x*.5+.12),size.y*.5,size.x*.25+.14),Vector3(.09,size.y,size.x*.5),settlement.wood,false)
			_piece(frame,"ShutterStay",Vector3(side*(size.x*.5+.10),.18,.30),Vector3(.18,.035,.40),settlement.iron,false)
	else:
		for y in [.08,size.y-.08]:
			_piece(frame,"IronGrilleCrossRail",Vector3(0,y,.025),Vector3(size.x,.045,.045),settlement.iron,false)

func _window_barrier(parent: Node3D,at: Vector3,size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "WindowBarrier"
	body.position = at
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)

func _interior(house_node: Node3D,extent: Vector2,index: int) -> void:
	for x in [-2.66,-1.34]:
		for z in [-2.4,-.4]:
			_piece(house_node,"SleepingPlatformLeg",Vector3(x,.34,z),Vector3(.12,.20,.12),settlement.wood)
	_piece(house_node,"SleepingMat",Vector3(-2,.635,-1.4),Vector3(1.66,.07,2.4),cloth[index%cloth.size()],false)
	var hearth := Vector3(extent.x*.5-1.1,.36,-extent.y*.5+1.1)
	_piece(house_node,"CookingHearth",hearth,Vector3(1.0,.24,.8),settlement.stone)
	_piece(house_node,"HearthOpening",hearth+Vector3(0,.03,.405),Vector3(.35,.13,.015),settlement.iron,false)
	_pot(house_node,"CookingPot",hearth+Vector3(0,.12,0),.75)
	_piece(house_node,"StorageChest",Vector3(extent.x*.5-1.0,.52,-extent.y*.5+2.4),Vector3(.95,.56,.65),settlement.wood)
	_piece(house_node,"ChestLid",Vector3(extent.x*.5-1.0,.82,-extent.y*.5+2.4),Vector3(1.02,.07,.71),settlement.wood,false)

func _workshop(house_node: Node3D,extent: Vector2,craft: String) -> void:
	var centre := Vector3(2.25,0,extent.y*.5+1.0)
	if craft == "carpenter":
		_piece(house_node,"CarpenterBench",centre+Vector3(0,.85,0),Vector3(1.65,.14,.75),settlement.wood)
		for x in [-.62,.62]:
			for z in [-.25,.25]:
				_piece(house_node,"BenchLeg",centre+Vector3(x,.39,z),Vector3(.13,.78,.13),settlement.wood)
		_piece(house_node,"BenchWorkpiece",centre+Vector3(0,.96,0),Vector3(1.4,.08,.28),roof_earth,false)
		_piece(house_node,"TimberStock",Vector3(extent.x*.5-.25,.32,-extent.y*.5-1.0),Vector3(.6,.64,2.2),settlement.wood)
	elif craft == "weaver":
		var envelope := StaticBody3D.new()
		envelope.name = "LoomEnvelope"
		envelope.position = centre+Vector3(0,.75,0)
		var envelope_collision := CollisionShape3D.new()
		var envelope_shape := BoxShape3D.new()
		envelope_shape.size = Vector3(1.65,1.5,1.1)
		envelope_collision.shape = envelope_shape
		envelope.add_child(envelope_collision)
		house_node.add_child(envelope)
		for x in [-.8,.8]:
			for z in [-.5,.5]:
				_piece(house_node,"LoomPost",centre+Vector3(x,.75,z),Vector3(.10,1.5,.10),settlement.wood)
		for y in [.25,1.4]:
			for z in [-.5,.5]:
				_piece(house_node,"LoomRail",centre+Vector3(0,y,z),Vector3(1.8,.09,.10),settlement.wood)
		_piece(house_node,"WovenPanel",centre+Vector3(0,.97,0),Vector3(1.35,.025,1.08),cloth[0],false).rotation.x = -.52
		for side in [-1.0,1.0]:
			_piece(house_node,"LoomClothSupport",centre+Vector3(side*.8,.97,0),Vector3(.075,.065,1.15),settlement.wood,false).rotation.x = -.52
		for x in range(12):
			_piece(house_node,"WarpThread",centre+Vector3(-.61+x*.11,.987,0),Vector3(.008,.012,1.08),cloth[2],false).rotation.x = -.52
	else:
		_cylinder(house_node,"PotterFlywheel",centre+Vector3(0,.1,0),.57,.16,settlement.wood,true)
		_cylinder(house_node,"WheelAxle",centre+Vector3(0,.39,0),.065,.58,settlement.wood,true)
		_cylinder(house_node,"WheelHead",centre+Vector3(0,.72,0),.30,.08,settlement.wood,true)
		_pot(house_node,"WheelVessel",centre+Vector3(0,.76,0),.75)
		for i in 3:
			_pot(house_node,"DryingPot",Vector3(-extent.x*.5+.85+i*.65,0,extent.y*.5+1.0),.9)

func stock(stall: Node3D,index: int,produce_materials: Array[Material]) -> void:
	var goods: String = MARKET_GOODS[index]
	stall.set_meta("goods",goods)
	if goods == "produce":
		for tray in 3:
			var x: float = (tray-1)*1.25
			_piece(stall,"TrayBase",Vector3(x,.99,0),Vector3(1.02,.13,.72),settlement.wood,false)
			for side in [-1.0,1.0]:
				_piece(stall,"TrayRim",Vector3(x,1.08,side*.36),Vector3(1.02,.13,.045),settlement.wood,false)
			var fruit := SphereMesh.new()
			fruit.radius = .10
			fruit.height = .20
			fruit.radial_segments = 8
			fruit.rings = 4
			var mesh := MultiMeshInstance3D.new()
			mesh.name = "Produce"
			mesh.multimesh = MultiMesh.new()
			mesh.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			mesh.multimesh.mesh = fruit
			mesh.multimesh.instance_count = 12
			for i in 12:
				mesh.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,Vector3(x-.33+(i%4)*.22,1.14,-.22+(i/4)*.22)))
			mesh.material_override = produce_materials[(index+tray)%produce_materials.size()]
			mesh.visibility_range_end = 110.0
			stall.add_child(mesh)
	elif goods == "pottery":
		for i in 5: _pot(stall,"MarketPot",Vector3(-1.5+i*.75,.93,0),.8+float(i%2)*.2)
	elif goods == "grain":
		for i in 4:
			var sack := SphereMesh.new()
			sack.radius = .24
			sack.height = .45
			var mesh := MeshInstance3D.new()
			mesh.mesh = sack
			mesh.material_override = cloth[2]
			mesh.position = Vector3(-1.45+i*.95,1.155,0)
			stall.add_child(mesh)
			_cylinder(stall,"SackTie",Vector3(-1.45+i*.95,1.35,0),.09,.06,settlement.wood,false)
	elif goods == "cloth":
		for i in 3:
			for layer in 3:
				_piece(stall,"FoldedCloth",Vector3(-1.3+i*1.3,.97+layer*.08,0),Vector3(.82,.08,.65),cloth[(i+layer)%cloth.size()],false)
	else:
		for i in 4:
			_piece(stall,"CutPlanks",Vector3(-1.3+i*.8,1.02,0),Vector3(.55,.18,1.0),settlement.wood,false)

func _cylinder(parent: Node3D,label: String,at: Vector3,radius: float,height: float,material: Material,solid: bool) -> void:
	var node := Node3D.new()
	node.name = label
	node.position = at
	parent.add_child(node)
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 16
	mesh.mesh = cylinder
	mesh.material_override = material
	node.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		collision.shape = shape
		body.add_child(collision)
		node.add_child(body)

func _pot(parent: Node3D,label: String,at: Vector3,size: float) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = _pot_mesh()
	mesh.material_override = clay
	mesh.position = at
	mesh.scale = Vector3.ONE*size
	parent.add_child(mesh)

func _pot_mesh() -> ArrayMesh:
	var profile: Array[Vector2] = [Vector2(0,0),Vector2(.02,.11),Vector2(.12,.20),Vector2(.26,.23),Vector2(.38,.14),Vector2(.42,.11),Vector2(.44,.13),Vector2(.44,.09),Vector2(.38,.09)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in 16:
		for row in range(profile.size()-1):
			var vertices: Array[Vector3] = []
			var uvs: Array[Vector2] = []
			for i in [0,1,2, 1,3,2]:
				var angle := float(segment+i%2)*TAU/16.0
				var p: Vector2 = profile[row+i/2]
				vertices.append(Vector3(sin(angle)*p.y,p.x,cos(angle)*p.y))
				uvs.append(Vector2(float(segment+i%2)/16.0,p.x/.44))
			for i in vertices.size():
				surface.set_uv(uvs[i])
				surface.add_vertex(vertices[i])
	surface.generate_normals()
	surface.generate_tangents()
	surface.index()
	return surface.commit()
