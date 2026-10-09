extends RefCounted
const Detail = preload("res://world/suryagarh/settlements/military_detail.gd")

static func furnish(b, district: Node3D) -> void:
	var wood := Detail.surface(Color(.29,.19,.10),2)
	var straw := ShaderMaterial.new()
	straw.shader = preload("res://world/suryagarh/settlements/cantonment_straw.gdshader")
	var stone := Detail.surface(Color(.57,.57,.51))
	var grain: Node3D = district.get_node("GrainFodderWarehouse")
	# Keep a broad central loading aisle; storage is lifted clear of damp stone.
	for x in [-6.0,6.0]:
		b.piece(grain,"DunnageFeet",Vector3(x,.34,-2.5),Vector3(3.3,.20,2.5),wood)
		for z in [-3.5,-3.0,-2.5,-2.0,-1.5]:
			b.piece(grain,"PalletSlat",Vector3(x,.48,z),Vector3(3.5,.08,.35),wood)
		for row in 2:
			for col in 3:
				Detail.prop(grain,"res://objects/household/grain_sack.tscn",Vector3(x-.8+col*.8,.52,-3.2+row*.9)).rotation.y = col*.17
	for x in [-6.0,6.0]:
		for z in [1.0,2.3]:
			var bundle_x: float = -7.5 if x < 0 else x
			var bundle_z: float = (.55 if z == 1.0 else 1.65) if x < 0 else z
			var bundle_width: float = 1.8 if x < 0 else 2.4
			var bundle = b.piece(grain,"LooseFodderBundle",Vector3(bundle_x,.65,bundle_z),Vector3(bundle_width,.8,1),straw)
			for child in bundle.get_children():
				if child is MeshInstance3D:
					var hay_mesh := SphereMesh.new()
					hay_mesh.radius = .5
					hay_mesh.height = 1
					child.mesh = hay_mesh
					child.scale = Vector3(bundle_width,.8,1)
			for dx in ([-.5,.5] if x < 0 else [-.7,.7]):
				var binding := MeshInstance3D.new()
				var ring := TorusMesh.new()
				ring.inner_radius = .317
				ring.outer_radius = .340
				binding.mesh = ring
				binding.material_override = wood
				binding.rotation.z = PI/2
				binding.scale.z = 1.25
				binding.position = Vector3(bundle_x+dx,.65,bundle_z)
				grain.add_child(binding)

	Detail.prop(grain,"res://objects/household/storage/basket.tscn",Vector3(-3,.24,2.7))
	var stable: Node3D = district.get_node("CavalryStables")
	for i in 8:
		var x := -14.2+i*4.0
		b.piece(stable,"StallStraw",Vector3(x,.265,-1.7),Vector3(3.2,.05,3),straw,false)
		for strand in 18:
			var stem = b.piece(stable,"ScatteredStraw",Vector3(x-1.4+fmod(strand*.73,2.8),.295,-3+fmod(strand*.61,2.6)),Vector3(.012,.012,.22+fmod(strand*.13,.3)),straw,false)
			stem.rotation.y = strand*1.7
		for z in [-3.5,.7]:
			b.piece(stable,"RailPost",Vector3(x-1.7,1.05,z),Vector3(.16,1.62,.16),wood)
		Detail.prop(stable,"res://objects/household/storage/bucket.tscn",Vector3(x+1.0,.24,-.1))
		# Open trough rather than a solid feed box.
		b.piece(stable,"MangerFeed",Vector3(x,.82,-3.5),Vector3(2.4,.04,.5),straw,false)
	for z in [1.1,1.5]: b.piece(stable,"DrainLip",Vector3(0,.28,z),Vector3(30,.08,.10),stone,false)
	b.piece(stable,"DrainChannel",Vector3(0,.247,1.3),Vector3(30,.012,.28),wood,false)
	var ward: Node3D = district.get_node("MilitaryHospital")
	for x in [-9.0,-3.0,3.0,9.0]:
		for z in [-2.0,2.0]:
			bed_linen(ward,Vector3(x,.868,z),preload("res://world/suryagarh/settlements/military_room_finish.gd").cloth(Color(.78,.76,.66)))
			b.piece(ward,"BedHeadboard",Vector3(x,1.02,z-1.03),Vector3(1.32,.9,.08),wood)
			b.piece(ward,"BedsideCabinet",Vector3(x+1.5,.60,z),Vector3(.65,.72,.65),wood)
			Detail.prop(ward,"res://objects/household/water_pot_visual.tscn",Vector3(x+1.5,.96,z)).scale = Vector3.ONE*.45
	Detail.prop(ward,"res://objects/household/storage/bucket.tscn",Vector3(-1,.24,-3.8))
	Detail.prop(ward,"res://objects/household/storage/brass_pot.tscn",Vector3(.45,1.03,-3))
	Detail.prop(ward,"res://objects/household/supplies/bandage_roll.tscn",Vector3(-.5,1.03,-3))
	b.piece(ward,"MedicineShelf",Vector3(0,1.8,-4.6),Vector3(2.6,.12,.55),wood)
	for x in [-1.1,1.1]: b.piece(ward,"ShelfBracket",Vector3(x,1.55,-4.7),Vector3(.08,.5,.3),wood,false)
	for x in [-.8,0,.8]: Detail.prop(ward,"res://objects/household/supplies/supply_parcel.tscn",Vector3(x,1.86,-4.6))

static func church(b, room: Node3D) -> void:
	var wood := Detail.surface(Color(.24,.14,.07),2)
	for z in [-3.0,-.8,1.4,3.6,5.8]:
		for x in [-3.1,3.1]:
			b.piece(room,"PewSeat",Vector3(x,.72,z),Vector3(3.5,.12,.55),wood)
			b.piece(room,"PewBack",Vector3(x,1.05,z+.25),Vector3(3.5,.66,.09),wood)
			for dx in [-1.5,1.5]: b.piece(room,"PewEnd",Vector3(x+dx,.65,z),Vector3(.12,.82,.65),wood)
	b.piece(room,"ChancelStep",Vector3(0,.34,-6.5),Vector3(8,.2,3.7),b.stone)
	b.piece(room,"AltarTop",Vector3(0,1.35,-7),Vector3(2.8,.16,1),wood)
	for x in [-1.1,1.1]: b.piece(room,"AltarLeg",Vector3(x,.91,-7),Vector3(.16,.72,.75),wood)
	b.piece(room,"AltarLinen",Vector3(0,1.44,-7),Vector3(2.85,.025,1.03),b.plaster,false)
	b.piece(room,"CrossUpright",Vector3(0,2.4,-8.7),Vector3(.10,1.2,.10),wood,false)
	b.piece(room,"CrossArms",Vector3(0,2.65,-8.7),Vector3(.65,.10,.10),wood,false)
	for x in [-5.3,5.3]:
		for z in [-6.0,0.0,6.0]: b.piece(room,"WallPilaster",Vector3(x,1.9,z),Vector3(.25,3.35,.4),b.plaster)
	b.piece(room,"BellGablePiers",Vector3(-.65,4.4,9),Vector3(.3,1.4,.4),b.plaster)
	b.piece(room,"BellGablePiers",Vector3(.65,4.4,9),Vector3(.3,1.4,.4),b.plaster)
	b.piece(room,"BellGableHead",Vector3(0,5.15,9),Vector3(1.6,.2,.5),b.stone)
	var bell := MeshInstance3D.new()
	bell.name = "CastBell"
	var bell_mesh := CylinderMesh.new()
	bell_mesh.top_radius = .12
	bell_mesh.bottom_radius = .29
	bell_mesh.height = .45
	bell.mesh = bell_mesh
	bell.material_override = b.iron
	bell.position = Vector3(0,4.55,9)
	room.add_child(bell)
	b.piece(room,"BellClapper",Vector3(0,4.25,9),Vector3(.065,.18,.065),b.iron,false)

static func cemetery(b, district: Node3D) -> void:
	var yard := Node3D.new()
	yard.name = "MilitaryCemetery"
	yard.position = Vector3(-61,0,0)
	district.add_child(yard)
	yard.add_to_group("military_cemetery")
	var stone := Detail.surface(Color(.57,.56,.49))
	for x in [-6.0,6.0]: b.piece(yard,"BoundaryWall",Vector3(x,1.05,0),Vector3(.35,2.1,21),stone)
	b.piece(yard,"RearWall",Vector3(0,.6,-10.5),Vector3(12,1.2,.35),stone)
	for x in [-3.7,3.7]: b.piece(yard,"GateWall",Vector3(x,.6,10.5),Vector3(4.6,1.2,.35),stone)
	for x in [-1.35,1.35]: b.piece(yard,"GatePier",Vector3(x,.9,10.5),Vector3(.45,1.8,.45),stone)
	for side in [-1,1]:
		for z in [9.4,10.4]: b.piece(yard,"OpenGateFrame",Vector3(side*1.30,.7,z),Vector3(.05,1.3,.05),b.iron)
		for y in [.16,.75,1.28]: b.piece(yard,"OpenGateRail",Vector3(side*1.30,y,9.9),Vector3(.05,.05,1.05),b.iron)
		for i in 5: b.piece(yard,"OpenGateBar",Vector3(side*1.30,.7,9.5+i*.2),Vector3(.025,1.2,.025),b.iron)
	b.piece(yard,"GravelWalk",Vector3(0,.015,0),Vector3(2.1,.03,21),b.ochre,false)
	for x in [-3.5,3.5]:
		for i in 5:
			var z := -8.0+i*3.5
			b.piece(yard,"GravePlot",Vector3(x,.04,z),Vector3(1.3,.08,2.2),b.ochre,false)
			b.piece(yard,"HeadstoneFoot",Vector3(x,.12,z-1),Vector3(.9,.24,.4),stone)
			b.piece(yard,"Headstone",Vector3(x,.68,z-1),Vector3(.65,1.0,.16),stone)
			if i%2 == 0:
				b.piece(yard,"CrossStem",Vector3(x,1.4,z-1),Vector3(.13,.55,.16),stone)
				b.piece(yard,"CrossArms",Vector3(x,1.5,z-1),Vector3(.48,.13,.16),stone)
	var entry := Marker3D.new()
	entry.name = "Entrance"
	entry.position = Vector3(0,.05,12)
	yard.add_child(entry)

static func roof(b, room: Node3D, w: float, d: float) -> void:
	var wood := Detail.surface(Color(.29,.19,.10),2)
	var floor_mat := ShaderMaterial.new()
	floor_mat.shader = preload("res://world/suryagarh/settlements/cantonment_floor.gdshader")
	for mesh in room.get_node("Floor").get_children():
		if mesh is MeshInstance3D: mesh.material_override = floor_mat
	for child in room.get_children():
		if str(child.name).contains("RoofTie"): child.free()
	for i in range(1,int(d/3)+1):
		var z := -d/2+i*d/(int(d/3)+1)
		b.piece(room,"TrussTie",Vector3(0,3.45,z),Vector3(w-.2,.18,.16),wood,false)
		b.piece(room,"KingPost",Vector3(0,3.55+w*.03,z),Vector3(.14,.2+w*.06,.14),wood,false)
		for side in [-1,1]:
			var rafter = b.piece(room,"PrincipalRafter",Vector3(side*w/4,3.59+w*.03,z),Vector3(w/2+.15,.16,.16),wood,false)
			rafter.rotation.z = side*-.12

static func bed_linen(parent: Node3D, p: Vector3, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = "DrapedWardLinen"
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ix in 16:
		for iz in 20:
			for corner in [Vector2(0,0),Vector2(0,1),Vector2(1,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
				var x: float = -.70+(ix+corner.x)*1.4/16
				var z: float = -.95+(iz+corner.y)*1.9/20
				var drop := maxf(0,absf(x)-.58)*1.6
				var ripple := .006*sin(x*31+z*4)+.003*sin(z*26)
				surface.add_vertex(Vector3(x,-drop+ripple,z))
	surface.generate_normals()
	mesh.mesh = surface.commit()
	mesh.material_override = mat
	mesh.position = p
	parent.add_child(mesh)
