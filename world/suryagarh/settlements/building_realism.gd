extends RefCounted
## Construction and furnishing detail for the existing civic footprints.
static func finish(tint: Color, grade: float, paving: bool = false) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://world/suryagarh/settlements/building_finish.gdshader")
	mat.set_shader_parameter("tint",tint)
	mat.set_shader_parameter("grade",grade)
	mat.set_shader_parameter("paving",paving)
	return mat

static func civic(b: Node3D) -> void:
	# A hanging frame needs a reservoir and flame, not an empty cage.
	if not b.police:
		for level in 2:
			for x in [-5.0,8.0]:
				preload("res://world/suryagarh/settlements/police_refinement.gd").lamp(b,"HallOilLamp",Vector3(x,level*b.floor_y+3.84,0),7.5,level*b.floor_y+4.94)
	# Table aprons and stretchers connect their trestles beneath the boards.
	for level in 2:
		for row in 3:
			if b.police and (level != 1 or row != 2): continue
			var y: float = level*b.floor_y
			var z: float = -6+row*5
			for side in [-1,1]:
				b.piece(b,"TableApron",Vector3(3,y+.69,z+side*.62),Vector3(6.9,.16,.075),b.wood,false)
			b.piece(b,"TrestleStretcher",Vector3(3,y+.24,z),Vector3(6.9,.10,.12),b.wood,false)
			for x in [-.4,6.4]:
				b.piece(b,"TrestleFoot",Vector3(x,y+.055,z),Vector3(.35,.11,1.4),b.wood,false)
	if not b.police:
		for level in 2:
			var y: float=level*b.floor_y
			# A records preparation bay at the east wall; main aisle and stairs clear.
			b.piece(b,"RecordsSideboard",Vector3(15,y+.65,7),Vector3(1.2,1.3,3.2),b.wood)
			for drawer in 3:
				b.piece(b,"RecordsDrawer",Vector3(14.38,y+.25+drawer*.37,7),Vector3(.05,.31,3.0),b.wood,false)
				b.piece(b,"RecordsPull",Vector3(14.32,y+.25+drawer*.37,7),Vector3(.06,.04,.30),b.iron,false)
			for book in 4:
				b.piece(b,"RegistryFolio",Vector3(15,y+1.34+book*.07,6.4),Vector3(.65,.06,.45),b.ochre,false)
	soften(b,b.wood)
	# Low splash apron protects the lime wall; it does not cover any opening.
	for side in [-1,1]:
		b.piece(b,"LimePlinth",Vector3(side*(b.width*.5+.02),.22,0),Vector3(.56,.44,b.depth),b.stone,false)

static func residence(b: Node3D, h: Node3D, level: int) -> void:
	room_bays(b,h,level)
	var y: float = level*b.STOREY
	var base: float = .34 if level==0 else 0.0
	var paper: Material = finish(Color(.73,.69,.57),b.position.y)
	var ink: Material = b.material(Color(.07,.065,.05))
	for side in [-1,1]:
		for row in [-1,1]:
			var x: float = side*23.5
			var z: float = row*10.5
			for dx in [-.29,.29]:
				for dz in [-.29,.29]:
					b.piece(h,"ChairLeg",Vector3(x+dx,y+base+.23,z+2.2+dz),Vector3(.075,.46,.075),b.wood,false)
			for dx in [-.29,.29]:
				b.piece(h,"ChairSideStretcher",Vector3(x+dx,y+base+.19,z+2.2),Vector3(.05,.06,.58),b.wood,false)
			for dz in [-.68,.68]:
				b.piece(h,"DeskApron",Vector3(x,y+.84,z+dz),Vector3(2.8,.19,.08),b.wood,false)
			b.piece(h,"DeskLedger",Vector3(x-.65,y+1.11,z),Vector3(.45,.07,.33),b.carpet,false)
			b.piece(h,"DeskPaper",Vector3(x-.02,y+1.085,z+.1),Vector3(.32,.015,.42),paper,false)
			b.piece(h,"DeskInkPot",Vector3(x+.45,y+1.13,z),Vector3(.085,.11,.085),ink,false)
	if level==1:
		var fabric: Material = finish(Color(.36,.29,.20),b.position.y)
		for x in [-5.0,5.0]:
			for dx in [-1.2,1.2]:
				for dz in [-.48,.48]:
					b.piece(h,"SofaFoot",Vector3(x+dx,y+.16,9+dz),Vector3(.10,.32,.10),b.wood,false)
			for dx in [-.85,0.0,.85]:
				b.piece(h,"SofaCushion",Vector3(x+dx,y+.62,9),Vector3(.80,.20,1.0),fabric,false)
			b.piece(h,"DrawingLowTable",Vector3(x,y+.42,6.8),Vector3(2.2,.12,1.0),b.wood)
			for dx in [-.85,.85]:
				for dz in [-.32,.32]: b.piece(h,"LowTableLeg",Vector3(x+dx,y+.18,6.8+dz),Vector3(.09,.36,.09),b.wood,false)
			b.piece(h,"SofaBack",Vector3(x,y+.98,9.60),Vector3(3,.85,.14),b.wood,false)
			for side in [-1,1]: b.piece(h,"SofaArm",Vector3(x+side*1.40,y+.78,9),Vector3(.16,.18,1.35),b.wood,false)
	if level==2:
		for x in [-23.0,23.0]:
			b.piece(h,"BedHeadboard",Vector3(x,y+1.18,-13.5),Vector3(3.05,1.1,.15),b.wood,false)
			for dx in [-.75,.75]:
				var pillow := MeshInstance3D.new()
				pillow.name = "Pillow"
				var mesh := SphereMesh.new()
				mesh.radius = .5
				mesh.height = 1.0
				mesh.radial_segments = 16
				mesh.rings = 8
				pillow.mesh = mesh
				pillow.material_override = paper
				pillow.position = Vector3(x+dx,y+1.25,-12.7)
				pillow.scale = Vector3(1.12,.24,.68)
				h.add_child(pillow)
			b.piece(h,"FoldedBedCover",Vector3(x,y+1.20,-9.5),Vector3(2.8,.06,1.7),b.carpet,false)
	soften(h,b.wood)

static func wood(tint: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader=preload("res://world/suryagarh/settlements/building_wood.gdshader")
	mat.set_shader_parameter("tint",tint)
	return mat

# Six subdivided faces projected onto a rounded cuboid. Matching box collisions
# remain conservative, while bevels catch light on seats, rails and table edges.
static func rounded_box(size: Vector3, radius: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := size*.5
	var r := minf(radius,minf(half.x,minf(half.y,half.z))*.8)
	var inner := half-Vector3.ONE*r
	for axis in 3:
		var u := (axis+1)%3
		var v := (axis+2)%3
		for direction in [-1.0,1.0]:
			var grid := PackedVector3Array()
			for j in 4:
				for i in 4:
					var point := Vector3.ZERO
					point[axis]=half[axis]*direction
					var coordinates := [-1.0,0.0,0.0,1.0]
					point[u]=coordinates[i]*half[u]
					point[v]=coordinates[j]*half[v]
					if i==1: point[u]=-inner[u]
					if i==2: point[u]=inner[u]
					if j==1: point[v]=-inner[v]
					if j==2: point[v]=inner[v]
					grid.append(point)
			for j in 3:
				for i in 3:
					var indices := [j*4+i,j*4+i+1,(j+1)*4+i,j*4+i+1,(j+1)*4+i+1,(j+1)*4+i]
					if direction>0: indices.reverse()
					for index in indices:
						var point := grid[index]
						var core := point.clamp(-inner,inner)
						var normal := (point-core).normalized()
						var rounded := core+normal*r
						st.set_normal(normal)
						var along := 0 if size.x>=size.z else 2
						var across := 2 if along==0 else 0
						st.set_uv(Vector2(rounded[along]+size[along]*.5,rounded[across]+rounded.y+size[across]*.5))
						st.add_vertex(rounded)
	st.index()
	return st.commit()

static func soften(parent: Node3D, timber: Material) -> void:
	for child in parent.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh:
			var label: String = str(parent.get_meta("part_label",parent.name))
			var furniture := false
			for word in ["Table","Chair","Bench","Sofa","Bed","Cabinet","Shelf","Trestle","Desk","Bookcase"]:
				if word in label: furniture=true
			if furniture or child.material_override==timber:
				child.mesh=rounded_box(child.mesh.size,.075 if "Cushion" in label else (.018 if furniture else .004))
		if child is Node3D: soften(child,timber)

static func room_bays(b: Node3D,h: Node3D,level: int) -> void:
	var floor_y: float=level*b.STOREY+(.34 if level==0 else 0.0)
	for side in [-1.0,1.0]:
		# Storage beside the exterior wall, outside all room doors and east stairs.
		var x: float=side*31.4
		var z := 13.8
		b.piece(h,"RoomSideboard",Vector3(x,floor_y+.62,z),Vector3(1.15,1.24,3.0),b.wood)
		for drawer in 3:
			b.piece(h,"SideboardDrawer",Vector3(x-side*.59,floor_y+.25+drawer*.35,z),Vector3(.04,.29,2.82),b.wood,false)
			b.piece(h,"DrawerPull",Vector3(x-side*.64,floor_y+.25+drawer*.35,z),Vector3(.065,.045,.24),b.brass,false)
		var prop: Node3D=load("res://objects/household/storage/brass_pot.tscn").instantiate()
		h.add_child(prop)
		prop.position=Vector3(x,floor_y+1.24,z+.7)
		prop.scale=Vector3.ONE*.35
		b.piece(h,"RoomRug",Vector3(side*25,floor_y+.015,13.4),Vector3(5.5,.018,5.6),b.carpet,false)
		if level==2:
			b.piece(h,"BedsideChest",Vector3(side*26,floor_y+.46,-12),Vector3(1.15,.92,.9),b.wood)
			b.piece(h,"ChestTopLip",Vector3(side*26,floor_y+.94,-12),Vector3(1.22,.06,.98),b.wood,false)
		else:
			# A second visitor seat turns the desk into a usable conversation bay.
			var p:=Vector3(side*25.2,floor_y,12.7)
			b.piece(h,"VisitorChairSeat",p+Vector3(0,.52,0),Vector3(.8,.12,.8),b.wood)
			b.piece(h,"VisitorChairBack",p+Vector3(0,1.03,.34),Vector3(.8,.92,.10),b.wood,false)
			for dx in [-.29,.29]:
				for dz in [-.29,.29]: b.piece(h,"VisitorChairLeg",p+Vector3(dx,.23,dz),Vector3(.075,.46,.075),b.wood,false)
