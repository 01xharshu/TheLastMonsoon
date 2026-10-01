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
	# Low splash apron protects the lime wall; it does not cover any opening.
	for side in [-1,1]:
		b.piece(b,"LimePlinth",Vector3(side*(b.width*.5+.02),.22,0),Vector3(.56,.44,b.depth),b.stone,false)

static func residence(b: Node3D, h: Node3D, level: int) -> void:
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
				b.piece(h,"SofaCushion",Vector3(x+dx,y+.62,9),Vector3(.80,.17,1.0),fabric,false)
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
