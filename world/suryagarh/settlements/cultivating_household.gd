extends RefCounted
## One authored livelihood pilot. Decorative tools/storage imply no new gameplay.
const Sack = preload("res://objects/household/grain_sack.tscn")
const Mat = preload("res://objects/household/woven_mat.tscn")
const WaterVessel = preload("res://objects/household/water_pot_visual.tscn")
var b
var earth: Material
var soil_surface: Material

func furnish(village, home: Node3D) -> void:
	b = village.settlement
	earth = b.material(Color(.48,.36,.23))
	home.set_meta("livelihood","cultivating")
	home.set_meta("regional_basis","Awadh candidate; late June 1857 provisional")
	home.set_meta("field_id","BhairavpurHouse1WorkedPlot")
	var arbitrary := home.get_node_or_null("HouseholdProp")
	if arbitrary: arbitrary.free()
	var kit := Node3D.new()
	kit.name = "CultivatingKit"
	home.add_child(kit)
	_flat_roof(home)
	# Grain is kept indoors, off the damp floor, apart from the rear cooking bay.
	_piece(kit,"GrainStorageDeck",Vector3(3.3,.505,.9),Vector3(1.8,.09,.9),b.wood)
	for x in [2.52,4.08]:
		for z in [.57,1.23]:
			_piece(kit,"StorageLeg",Vector3(x,.35,z),Vector3(.10,.22,.10),b.wood)
	for i in 3:
		var sack: Node3D = Sack.instantiate()
		sack.name = "SeedSack" if i==2 else "GrainSack%d"%i
		kit.add_child(sack)
		sack.position = Vector3(2.7+i*.6,.55,.9)
		if i == 2: sack.scale = Vector3.ONE*.8
		sack.set_meta("contents","seed reserve" if i==2 else "stored previous harvest; species unresolved")
	for x in [3.63,3.97]:
		_piece(kit,"LampShelfCorbel",Vector3(x,1.22,3.4),Vector3(.15,.20,.24),earth,false)
	# Covered domestic water on an earthen support in the shaded threshold bay.
	_piece(kit,"WaterStand",Vector3(-3.55,.12,4.65),Vector3(1.35,.24,.95),earth)
	for i in 2:
		var pot: Node3D = WaterVessel.instantiate()
		pot.name = "CoveredWaterVessel%d"%i
		pot.set_meta("earthen_vessel", true)
		kit.add_child(pot)
		pot.position = Vector3(-3.87+i*.64,.24,4.65)
		_cylinder(pot,"ClayCover",Vector3(0,.813,0),.20,.026,earth)
		_cylinder(pot,"CoverGrip",Vector3(0,.842,0),.045,.034,earth)
		for label in ["ClayCover","CoverGrip"]:
			var cover: MeshInstance3D = pot.get_node(label)
			cover.set_surface_override_material(0,earth)
			cover.material_override = null
		var body = preload("res://objects/household/breakable_earthenware.gd").new()
		body.visual_root = pot
		body.vessel_size = 1.8
		body.name = "VesselCollision"
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = .31
		cylinder.height = .8
		shape.shape = cylinder
		shape.position.y = .4
		body.add_child(shape)
		pot.add_child(body)
	# Replace the bare horizontal shade slab with pitched thatch and real bearers.
	home.get_node("VerandaShade").free()
	for post: Node in home.get_children():
		if str(post.name).begins_with("ShadePost"): post.free()
	var straw := ShaderMaterial.new()
	straw.shader = preload("res://world/suryagarh/settlements/village_surface.gdshader")
	straw.set_shader_parameter("surface_kind",1)
	straw.set_shader_parameter("tint",Color(.48,.38,.24))
	_piece(kit,"ThresholdThatch",Vector3(0,2.66,4.65),Vector3(10.0,.20,2.8),straw,false).rotation.x = .09
	for z in [3.45,5.6]:
		_piece(kit,"ShadeBearer",Vector3(0,2.46 if z>4 else 2.65,z),Vector3(9.2,.13,.13),b.wood,false)
	for x in [-4.45,4.45]:
		_piece(kit,"BearerPost",Vector3(x,1.22,5.6),Vector3(.14,2.44,.14),b.wood)
	for x in [-4.1,-2.0,0.0,2.0,4.1]:
		_piece(kit,"ShadeRafter",Vector3(x,2.54,4.65),Vector3(.09,.11,2.65),b.wood,false).rotation.x = .09
	# Low earth edges define work space while keeping a wide central approach.
	_piece(kit,"WorkingCourt",Vector3(0,.012,7.05),Vector3(8.5,.024,3.0),earth,false)
	for side in [-1.0,1.0]:
		_piece(kit,"CourtEarthEdge",Vector3(side*4.25,.10,7.05),Vector3(.15,.20,3.1),earth,false)
	var mat: Node3D = Mat.instantiate()
	mat.name = "SeedPreparationMat"
	kit.add_child(mat)
	mat.position = Vector3(-2.7,.024,6.8)
	mat.rotation.y = PI*.5
	mat.set_meta("purpose","portable sorting mat; stored under cover during rain")
	# Protected implement rest on the right. Full-size sickle silhouettes are
	# original candidates, not replicas of the small East Indian museum model.
	_piece(kit,"ToolRest",Vector3(3.4,.66,5.2),Vector3(1.2,.08,.55),b.wood)
	for x in [2.92,3.88]:
		_piece(kit,"ToolRestLeg",Vector3(x,.31,5.2),Vector3(.10,.62,.10),b.wood)
	for i in 2: _sickle(kit,Vector3(3.15+i*.45,.71,5.2),float(i)*.45)
	# A small household-linked plot demonstrates season/state, not a ripe crop.
	var field: Node3D = village._root("BhairavpurHouse1WorkedPlot",Vector2(-321,198))
	field.set_meta("household_id","BhairavpurHouse1")
	field.set_meta("landscape","inland plain")
	field.set_meta("season_state","worked bare earth with residual rabi stubble")
	field.set_meta("crop_species","unresolved; no standing ripe crop")
	field.set_meta("water_source","rainfed candidate; no irrigation claim")
	field.set_meta("processing_destination","BhairavpurHouse1/CultivatingKit")
	_soil_patch(field,"WorkedEarth",4.6,4.4,true)
	for side in [-1.0,1.0]:
		_earth_bank(field,side)
	for i in 22:
		var x := -2.0+float((i*7)%21)*.19
		var z := -1.8+float((i*11)%19)*.20
		var height := .07+float(i%4)*.025
		_piece(field,"OldCutStubble",Vector3(x,.034+height*.5,z),Vector3(.012,height,.012),village.fabric[0],false).rotation.z = float(i%3-1)*.16
	# The field is approached along its eastern edge, not through crop rows.
	var path: Node3D = village._root("House1FieldFootpath",Vector2(-317.5,197.4))
	_soil_patch(path,"WorkedFootRoute",1.4,14.8,false)
	path.set_meta("connects",["House1 court","House1 worked plot edge","village south lane"])

func _piece(parent: Node3D,label: String,at: Vector3,size: Vector3,material: Material,solid := true) -> Node3D:
	return b.piece(parent,label,at,size,material,solid)

func _cylinder(parent: Node3D,label: String,at: Vector3,radius: float,height: float,material: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.position = at
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 20
	mesh.mesh = shape
	mesh.material_override = material
	parent.add_child(mesh)

func _sickle(parent: Node3D,at: Vector3,yaw: float) -> void:
	var tool := Node3D.new()
	tool.name = "HarvestSickle"
	tool.position = at
	tool.rotation.y = yaw
	parent.add_child(tool)
	_cylinder(tool,"WoodenGrip",Vector3(.21,.015,-.12),.025,.20,b.wood)
	tool.get_node("WoodenGrip").rotation.x = PI*.5
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 18:
		var a := float(i)/18.0*2.6
		var c := float(i+1)/18.0*2.6
		var outer_a := Vector3(cos(a)*.22,.015,sin(a)*.22)
		var outer_c := Vector3(cos(c)*.22,.015,sin(c)*.22)
		var inner_a := Vector3(cos(a)*(.18+.04*float(i)/18),.015,sin(a)*(.18+.04*float(i)/18))
		var inner_c := Vector3(cos(c)*(.18+.04*float(i+1)/18),.015,sin(c)*(.18+.04*float(i+1)/18))
		for vertex: Vector3 in [outer_a,inner_a,outer_c,outer_c,inner_a,inner_c,outer_c,inner_a,outer_a,inner_c,inner_a,outer_c]: surface.add_vertex(vertex)
	surface.generate_normals()
	surface.index()
	var blade := MeshInstance3D.new()
	blade.name = "IronBlade"
	blade.mesh = surface.commit()
	blade.material_override = b.iron
	tool.add_child(blade)

func _flat_roof(home: Node3D) -> void:
	# Lucknow gazetteer pp.85-86 describes flat-roofed earth-built dwellings.
	# Construction here is an original supported candidate, not a dated replica.
	for node: Node in home.get_children():
		# Repeated builder labels become anonymous Node3D names. Remove the old
		# roof envelope by height as well, before adding the authored terrace.
		if node is Node3D and node.position.y >= 3.0:
			node.free()
			continue
		for prefix in ["DetailedRoofSlope","ClosedGable","GableTieBeam","DetailedRoofRidge","InteriorRidgeBeam"]:
			if str(node.name).begins_with(prefix):
				node.free()
				break
	home.set_meta("roof_style","earth terrace")
	var roof := Node3D.new()
	roof.name = "CultivatingEarthRoof"
	home.add_child(roof)
	_piece(roof,"EarthenRoofDeck",Vector3(0,3.16,0),Vector3(9.9,.24,7.6),earth)
	# Two longitudinal bearers reduce the transverse joist spans to about 3.2m.
	for x in [-1.6,1.6]:
		_piece(roof,"RoofBearer",Vector3(x,2.96,0),Vector3(.18,.16,6.8),b.wood,false)
		for z in [-2.9,2.9]:
			_piece(roof,"RoofBearerPost",Vector3(x,1.56,z),Vector3(.16,2.64,.16),b.wood)
	for z in [-3.1,-2.1,-1.1,-.1,.9,1.9,2.9]:
		_piece(roof,"TerraceJoist",Vector3(0,3.04,z),Vector3(9.3,.12,.12),b.wood,false)
	for side in [-1.0,1.0]:
		_piece(roof,"LowEndParapet",Vector3(0,3.40,side*3.58),Vector3(9.5,.24,.18),earth)
		# Short side parapet sections leave a drainage gap in the middle.
		for z in [-1.9,1.9]:
			_piece(roof,"LowSideParapet",Vector3(side*4.65,3.40,z),Vector3(.18,.24,3.2),earth)

func _soil_material() -> Material:
	if soil_surface: return soil_surface
	var shader := Shader.new()
	shader.code = """shader_type spatial;
	varying vec3 p;
	void vertex() { p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
	void fragment() {
		float broad = sin(p.x*3.7+p.z*.8)*sin(p.z*5.2-p.x*.4);
		float grit = fract(sin(dot(floor(p.xz*65.0),vec2(12.9898,78.233)))*43758.5453);
		// Shader albedo is linear; keep dry soil distinct from pale paving.
		ALBEDO = vec3(.10,.055,.025)*(0.92+0.10*broad+0.12*grit);
		ROUGHNESS = 1.0;
	}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	soil_surface = material
	return material

func _soil_point(x: float,z: float,width: float,furrows: bool) -> Vector3:
	var rough := sin(x*17+z*8)*sin(z*21-x*6)*.006
	var ridge := (.012+.012*sin(z*TAU/.6+x*.18)) if furrows else .0
	var edge := 1.0+.035*sin(z*3.4)+.018*sin(z*8.7)
	var edge_falloff := clampf((width*.5-absf(x))/.22,0.0,1.0)
	return Vector3(x*edge,.006+(ridge+rough)*edge_falloff,z+.025*sin(x*7.3))

func _soil_patch(parent: Node3D,label: String,width: float,depth: float,furrows: bool) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := 24 if furrows else 8
	var nz := 48 if furrows else 32
	for row in nz:
		for col in nx:
			var x := -width*.5+float(col)*width/nx
			var z := -depth*.5+float(row)*depth/nz
			var a := _soil_point(x,z,width,furrows)
			var b_ := _soil_point(x+width/nx,z,width,furrows)
			var c := _soil_point(x,z+depth/nz,width,furrows)
			var d := _soil_point(x+width/nx,z+depth/nz,width,furrows)
			for point: Vector3 in [a,b_,c,b_,d,c]: surface.add_vertex(point)
	_add_earth_mesh(parent,label,surface)

func _earth_bank(parent: Node3D,side: float,half_width := 2.35,depth := 4.4) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in 24:
		var z := -depth*.5+float(segment)*depth/24
		var next_z := z+depth/24
		for half in 2:
			var strip: Array[Vector3] = []
			for sample in [Vector2(half,z),Vector2(half+1,z),Vector2(half,next_z),Vector2(half+1,next_z)]:
				var x := side*half_width+.04*sin(sample.y*4.1)+.025*sin(sample.y*9.5)
				strip.append(Vector3(x+(sample.x-1)*.15,.015+(.075+.015*sin(sample.y*6.0) if sample.x==1 else 0.0),sample.y))
			for index in [0,1,2,1,3,2]: surface.add_vertex(strip[index])
	_add_earth_mesh(parent,"PlotEarthBank",surface)

func _add_earth_mesh(parent: Node3D,label: String,surface: SurfaceTool) -> void:
	surface.generate_normals()
	surface.index()
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = surface.commit()
	mesh.material_override = _soil_material()
	parent.add_child(mesh)
