extends RefCounted
## Connected residential quarters, market and small cultivated edge of Bhairavpur.
## Uses the settlement's original construction helpers and shared world survey.
const WaterSource = preload("res://objects/water_pot.gd")
const Bucket = preload("res://assets/props/polyhaven/wooden_bucket_02/wooden_bucket_02_1k.gltf")
const Pot = preload("res://assets/props/polyhaven/brass_pot_01/brass_pot_01_1k.gltf")
const Basket = preload("res://assets/props/polyhaven/wicker_basket_01/wicker_basket_01_1k.gltf")
const Stool = preload("res://assets/props/polyhaven/wooden_stool_01/wooden_stool_01_1k.gltf")
const MangoTree = preload("res://environment/vegetation/mango_tree/mango_tree_01.glb")
const HOME_COUNT := 33
const STALL_COUNT := 8
const GARDEN_COUNT := 12
var settlement
var earth: Material
var crop_material: Material
var fabric: Array[Material] = []
var wall_palette: Array[Material] = []
var produce_materials: Array[Material] = []
var roots: Array[Node3D] = []
var house_detail := preload("res://world/suryagarh/settlements/bhairavpur_house_detail.gd").new()

func build(builder) -> void:
	settlement = builder
	earth = builder.material(Color(.38, .29, .18))
	crop_material = builder.material(Color(.20, .33, .12))
	fabric = [builder.material(Color(.66,.54,.35)), builder.material(Color(.48,.34,.23)), builder.material(Color(.54,.52,.35))]
	wall_palette = [builder.ochre, builder.material(Color(.68,.54,.36)), builder.material(Color(.57,.48,.34)), builder.material(Color(.73,.65,.48))]
	produce_materials = [builder.material(Color(.37,.48,.14)), builder.material(Color(.71,.48,.13)), builder.material(Color(.47,.23,.10))]
	house_detail.configure(builder,wall_palette)
	_build_homes()
	_build_well()
	_build_market()
	_build_farm_edge()
	_build_shade_trees()
	preload("res://world/suryagarh/settlements/village_social_places.gd").new().build(self)
	preload("res://world/suryagarh/settlements/village_night_life.gd").new().build(builder)
	# Keep visible procedural geometry in one mesh per root, with material surfaces.
	# Physical pieces remain separate so openings and passage collision stay exact.
	for node in roots:
		_merge_static_geometry(node)
	settlement.set_meta("bhairavpur_home_count", HOME_COUNT)
	settlement.set_meta("bhairavpur_stall_count", STALL_COUNT)
	settlement.set_meta("bhairavpur_garden_count", GARDEN_COUNT)

func _root(label: String, p: Vector2) -> Node3D:
	var node := Node3D.new()
	node.name = label
	settlement.add_child(node)
	node.position = Vector3(p.x, settlement.layout.height(p.x,p.y), p.y)
	node.add_to_group("bhairavpur_structure")
	roots.append(node)
	return node

func _piece(parent: Node3D, label: String, at: Vector3, size: Vector3, material: Material, solid := true) -> Node3D:
	return settlement.piece(parent, label, at, size, material, solid)

func _build_homes() -> void:
	var sites: Array[Dictionary] = []
	# Retain the original eight house identifiers and centres for existing props.
	for i in 8:
		sites.append({"p": Vector2(-343+(i%4)*22, 214+(i/4)*35), "yaw": PI if i<4 else 0.0, "size": Vector2(9.5,7.2), "quarter": "old village"})
	# Smaller homes fill the eleven-metre gaps in the original street frontage.
	for z in [214.0,249.0]:
		for x in [-332.0,-310.0,-288.0]:
			sites.append({"p": Vector2(x,z), "yaw": PI if z<230 else 0.0, "size": Vector2(7.8,6.6), "quarter": "old village infill"})
	# Two facing rows form an actual western residential lane.
	for z in [176.0,199.0,249.0,276.0,299.0]:
		for x in [-383.0,-365.0]:
			sites.append({"p": Vector2(x,z), "yaw": PI*.5 if x<-374 else -PI*.5, "size": Vector2(8.6,6.4), "quarter": "west lane"})
	for z in [249.0,278.0]:
		sites.append({"p": Vector2(-237,z), "yaw": -PI*.5, "size": Vector2(8.6,6.4), "quarter": "east lane"})
	for x in [-343.0,-321.0,-299.0,-277.0]:
		sites.append({"p": Vector2(x,299), "yaw": 0.0, "size": Vector2(9.0,7.0), "quarter": "north lane"})
	for x in [-343.0,-321.0,-299.0]:
		sites.append({"p": Vector2(x,166), "yaw": 0.0, "size": Vector2(9.0,7.0), "quarter": "south lane"})
	assert(sites.size() == HOME_COUNT)
	for i in sites.size():
		var site: Dictionary = sites[i]
		var house: Node3D = settlement.make_building("BhairavpurHouse%d"%i, site.p, site.size, false, false, false, true)
		house.rotation.y = site.yaw
		house.add_to_group("bhairavpur_home")
		house.add_to_group("bhairavpur_structure")
		house.set_meta("quarter", site.quarter)
		roots.append(house)
		for mesh in house.find_children("*", "MeshInstance3D", true, false):
			if mesh.material_override == settlement.ochre:
				mesh.material_override = wall_palette[i % wall_palette.size()]
		_household_detail(house, site.size, i)
		house_detail.house(house,site.size,i)
		if i == 0:
			preload("res://world/suryagarh/settlements/arjun_house.gd").new().furnish(settlement, house)

func _household_detail(house: Node3D, extent: Vector2, index: int) -> void:
	var w := extent.x
	var d := extent.y
	# Side props leave the central doorway and steps open.
	var prop: PackedScene = [Pot, Basket, Bucket, Stool][index % 4]
	var decoration: Node3D = prop.instantiate()
	decoration.name = "HouseholdProp"
	house.add_child(decoration)
	decoration.position = Vector3(-w*.5+.9, 0, d*.5+1.05)
	# A physical sideyard boundary gives selected homes a readable courtyard.
	if index >= 8 and index % 3 == 0:
		for side in [-1.0, 1.0]:
			_piece(house, "CourtyardSide", Vector3(side*(w*.5+.4), .35, d*.5+3.4), Vector3(.22,.7,3.7), settlement.ochre)
			_piece(house, "CourtyardFront", Vector3(side*(w*.25+.75), .3, d*.5+5.2), Vector3(w*.5-1.1,.6,.22), settlement.ochre)
	if index % 4 == 0:
		_piece(house, "FirewoodStack", Vector3(w*.5-.6,.18,-d*.5-.5), Vector3(1.25,.36,.55), settlement.wood)
		for layer in 3:
			_piece(house, "SplitWood", Vector3(w*.5-.6,.12+layer*.11,-d*.5-.51), Vector3(1.28,.06,.58), settlement.wood, false)

func _build_well() -> void:
	var well := _root("BhairavpurVillageWell", Vector2(-289,231))
	_piece(well,"PavedApron",Vector3(0,.035,0),Vector3(5.2,.07,5.2),settlement.stone)
	var body := WaterSource.new()
	body.name = "WellBody"
	body.position.y = .52
	body.hold_duration = .65
	body.marker_height = .75
	well.add_child(body)
	var wall := MeshInstance3D.new()
	wall.name = "HollowBrickShaft"
	wall.mesh = _shaft_mesh()
	wall.material_override = settlement.brick
	body.add_child(wall)
	var collision := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 1.22
	cylinder.height = .96
	collision.shape = cylinder
	body.add_child(collision)
	var mouth := MeshInstance3D.new()
	mouth.name = "DarkWellMouth"
	var mouth_mesh := CylinderMesh.new()
	mouth_mesh.top_radius = .86
	mouth_mesh.bottom_radius = .86
	mouth_mesh.height = .018
	mouth.mesh = mouth_mesh
	mouth.material_override = settlement.iron
	mouth.position.y = .12
	well.add_child(mouth)
	var rim := MeshInstance3D.new()
	rim.name = "StoneRim"
	var ring := TorusMesh.new()
	ring.inner_radius = .87
	ring.outer_radius = 1.17
	ring.rings = 24
	ring.ring_segments = 8
	rim.mesh = ring
	rim.material_override = settlement.stone
	rim.position.y = 1.03
	well.add_child(rim)
	for side in [-1.0,1.0]:
		_piece(well,"TimberUpright",Vector3(side*1.45,1.35,0),Vector3(.16,2.6,.16),settlement.wood)
	_piece(well,"CrossBeam",Vector3(0,2.62,0),Vector3(3.05,.2,.2),settlement.wood)
	var roller := MeshInstance3D.new()
	roller.name = "WaterRoller"
	var roller_mesh := CylinderMesh.new()
	roller_mesh.top_radius = .16
	roller_mesh.bottom_radius = .16
	roller_mesh.height = .72
	roller.mesh = roller_mesh
	roller.material_override = settlement.wood
	roller.position.y = 2.37
	roller.rotation.z = PI*.5
	well.add_child(roller)
	_piece(well,"DrawRope",Vector3(0,1.62,.15),Vector3(.025,1.48,.025),settlement.ochre,false)
	var bucket: Node3D = Bucket.instantiate()
	bucket.name = "SuspendedBucket"
	well.add_child(bucket)
	bucket.position = Vector3(0,.50,.15)
	for side in [-1.0,1.0]:
		var seat := _root("BhairavpurWellSeat%d"%int(side+1),Vector2(-289+side*5,235))
		_piece(seat,"StoneSeat",Vector3(0,.24,0),Vector3(2.1,.48,.7),settlement.stone)

func _shaft_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 24:
		var a := float(i)*TAU/24.0
		var b := float(i+1)*TAU/24.0
		var outer_bottom_a := Vector3(sin(a)*1.22,-.48,cos(a)*1.22)
		var outer_bottom_b := Vector3(sin(b)*1.22,-.48,cos(b)*1.22)
		var outer_top_a := Vector3(sin(a)*1.12,.48,cos(a)*1.12)
		var outer_top_b := Vector3(sin(b)*1.12,.48,cos(b)*1.12)
		var inner_bottom_a := Vector3(sin(a)*.86,-.48,cos(a)*.86)
		var inner_bottom_b := Vector3(sin(b)*.86,-.48,cos(b)*.86)
		var inner_top_a := Vector3(sin(a)*.86,.48,cos(a)*.86)
		var inner_top_b := Vector3(sin(b)*.86,.48,cos(b)*.86)
		for vertex: Vector3 in [outer_bottom_a,outer_top_a,outer_bottom_b, outer_bottom_b,outer_top_a,outer_top_b,
			inner_bottom_b,inner_top_b,inner_bottom_a, inner_bottom_a,inner_top_b,inner_top_a,
			outer_top_a,inner_top_a,outer_top_b, outer_top_b,inner_top_a,inner_top_b]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	return surface.commit()

func _build_market() -> void:
	for i in STALL_COUNT:
		var p := Vector2(-338+(i%4)*14, 268+(i/4)*15)
		var stall := _root("BhairavpurMarketStall%d"%i,p)
		stall.add_to_group("bhairavpur_market_stall")
		if i >= 4: stall.rotation.y = PI
		_piece(stall,"Counter",Vector3(0,.84,0),Vector3(4.4,.18,1.2),settlement.wood)
		for side in [-1.0,1.0]:
			_piece(stall,"CounterLeg",Vector3(side*1.75,.39,0),Vector3(.16,.78,.85),settlement.wood)
			for z in [-1.1,1.1]:
				_piece(stall,"ShadePost",Vector3(side*2.0,1.25,z),Vector3(.14,2.5,.14),settlement.wood)
		_piece(stall,"Shade",Vector3(0,2.55,0),Vector3(4.9,.12,2.9),fabric[i%fabric.size()],false).rotation.x = -.06
		_piece(stall,"ShadeHem",Vector3(0,2.38,1.4),Vector3(4.9,.23,.055),fabric[i%fabric.size()],false)
		house_detail.stock(stall,i,produce_materials)
		var storage: Node3D = Basket.instantiate() if i%2==0 else Bucket.instantiate()
		storage.name = "MarketStorage"
		stall.add_child(storage)
		storage.position = Vector3(-1.25,0,-.8)
	# A visible shared loading area gives the market scale without filling its aisle.
	var shed := _root("BhairavpurGrainStore",Vector2(-280,285))
	_piece(shed,"StoreFloor",Vector3(0,.08,0),Vector3(7,.16,5),settlement.stone)
	for x in [-3.2,3.2]:
		for z in [-2.2,2.2]:
			_piece(shed,"StorePost",Vector3(x,1.6,z),Vector3(.18,3.2,.18),settlement.wood)
	_piece(shed,"StoreShade",Vector3(0,3.22,0),Vector3(7.5,.17,5.7),fabric[1],false)
	for x in [-2.2,0.0,2.2]:
		_piece(shed,"GrainBin",Vector3(x,.5,-1.1),Vector3(1.6,.84,1.3),settlement.wood)
		_piece(shed,"GrainSurface",Vector3(x,.94,-1.1),Vector3(1.4,.04,1.1),fabric[0],false)

func _build_farm_edge() -> void:
	var leaves := _crop_mesh()
	for i in GARDEN_COUNT:
		var p := Vector2(-419+(i%2)*12,235+(i/2)*14)
		var garden := _root("BhairavpurKitchenGarden%d"%i,p)
		garden.add_to_group("bhairavpur_garden")
		_piece(garden,"RaisedEarth",Vector3(0,.06,0),Vector3(8,.12,4.4),earth,false)
		for side in [-1.0,1.0]:
			_piece(garden,"EarthBorder",Vector3(0,.10,side*2.2),Vector3(8.2,.20,.18),earth,false)
		var plants: Array[Transform3D] = []
		for row in 3:
			for column in 12:
				var position := Vector3(-3.5+column*.63,.13,-1.5+row*1.5)
				var basis := Basis(Vector3.UP,float(column+row+i)*1.74).scaled(Vector3.ONE*(.8+float((column+i)%4)*.12))
				plants.append(Transform3D(basis,position))
		_batch(garden,"CultivatedPlants",leaves,crop_material,plants)
	var drying := _root("BhairavpurHarvestYard",Vector2(-408,211))
	_piece(drying,"DryingMat",Vector3(0,.025,0),Vector3(8,.05,5),fabric[0],false)
	for side in [-1.0,1.0]:
		_piece(drying,"StrawStack",Vector3(side*2.0,.5,-.9),Vector3(1.9,1,1.6),fabric[0])
		_piece(drying,"StackBinding",Vector3(side*2.0,.51,-.9),Vector3(.08,1.04,1.64),settlement.wood,false)

func _crop_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for leaf in 6:
		var angle := float(leaf)*TAU/6.0
		var direction := Vector3(sin(angle),0,cos(angle))
		var side := Vector3(cos(angle),0,-sin(angle))*.035
		var mid := direction*.08+Vector3.UP*.22
		var tip := direction*.16+Vector3.UP*(.34+float(leaf%2)*.06)
		var vertices: Array[Vector3] = [-side*.25,side*.25,mid-side, mid-side,side*.25,mid+side, mid-side,mid+side,tip]
		for i in range(0,vertices.size(),3):
			for j in 3: surface.add_vertex(vertices[i+j])
			for j in [2,1,0]: surface.add_vertex(vertices[i+j])
	surface.generate_normals()
	return surface.commit()

func _build_shade_trees() -> void:
	for p: Vector2 in [Vector2(-356,219),Vector2(-274,274),Vector2(-394,227),Vector2(-260,300),Vector2(-332,182),Vector2(-343,287)]:
		var tree := _root("BhairavpurShadeTree%d"%settlement.get_tree().get_nodes_in_group("bhairavpur_shade_tree").size(),p)
		tree.add_to_group("bhairavpur_shade_tree")
		tree.add_child(MangoTree.instantiate())
		var body := StaticBody3D.new()
		body.name = "TrunkBody"
		tree.add_child(body)
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = .35
		cylinder.height = 2.2
		shape.shape = cylinder
		shape.position.y = 1.1
		body.add_child(shape)
		# Retain the imported tree hierarchy/materials; do not merge foliage.
		roots.erase(tree)

func _batch(parent: Node3D,label: String,mesh: Mesh,material: Material,transforms: Array[Transform3D]) -> void:
	var batch := MultiMeshInstance3D.new()
	batch.name = label
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.mesh = mesh
	batch.multimesh.instance_count = transforms.size()
	for i in transforms.size(): batch.multimesh.set_instance_transform(i,transforms[i])
	batch.material_override = material
	batch.visibility_range_end = 110.0
	batch.visibility_range_end_margin = 15.0
	parent.add_child(batch)

func _merge_static_geometry(node: Node3D) -> void:
	var surfaces: Dictionary = {}
	for mesh: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
		# Hinged doors/shutters must retain their moving visual hierarchy.
		var ancestor: Node = mesh.get_parent()
		var dynamic := false
		while ancestor != node and ancestor != null:
			if ancestor is Interactable or ancestor is Skeleton3D or ancestor is CharacterBody3D or ancestor.get_script() != null:
				dynamic = true
				break
			ancestor = ancestor.get_parent()
		if dynamic: continue
		# Keep skinned/animated objects separate; static imported furniture can
		# share a material surface without changing its collision or source file.
		if mesh.mesh == null or mesh.skin != null or mesh.name == "OilFlame" or mesh.get_script() != null: continue
		if mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_ON: continue
		var missing_material := false
		for i in mesh.mesh.get_surface_count():
			if mesh.get_active_material(i) == null: missing_material = true
		if missing_material: continue
		var transform: Transform3D = node.global_transform.affine_inverse()*mesh.global_transform
		for i in mesh.mesh.get_surface_count():
			var mat: Material = mesh.get_active_material(i)
			if mat == null: continue
			if not surfaces.has(mat):
				var surface := SurfaceTool.new()
				surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				surfaces[mat] = surface
			surfaces[mat].append_from(mesh.mesh,i,transform)
		preload("res://player/climb_opportunities.gd").retain_edge(node,mesh)
		mesh.free()
	var merged := ArrayMesh.new()
	for mat: Material in surfaces:
		surfaces[mat].set_material(mat)
		surfaces[mat].commit(merged)
	if merged.get_surface_count() > 0:
		var visual := MeshInstance3D.new()
		visual.name = "VillageMergedGeometry"
		visual.mesh = merged
		visual.visibility_range_end = 750
		visual.visibility_range_end_margin = 60
		node.add_child(visual)
