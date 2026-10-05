extends RefCounted
static func surface(color:Color,kind:int=0)->ShaderMaterial:
	var mat:=ShaderMaterial.new()
	mat.shader=preload("res://world/suryagarh/settlements/military_surface.gdshader")
	mat.set_shader_parameter("tint",color)
	mat.set_shader_parameter("kind",kind)
	return mat
static func prop(parent:Node3D,path:String,p:Vector3)->Node3D:
	var node:Node3D=load(path).instantiate()
	parent.add_child(node)
	node.position=p
	return node

static func cloth(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://world/suryagarh/settlements/military_linen.gdshader")
	mat.set_shader_parameter("tint",color)
	return mat

# Rounded layered perimeter gives cushions volume without sharp slab corners.
static func cushion(parent: Node3D,label: String,p: Vector3,size: Vector3,mat: Material,roundness:float=.22) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array[PackedVector3Array] = []
	for layer in [Vector2(.82,-.48),Vector2(1,-.20),Vector2(1,.12),Vector2(.86,.44),Vector2(.35,.52)]:
		var ring := PackedVector3Array()
		for i in 32:
			var angle := TAU*i/32.0
			var cx := cos(angle)
			var cz := sin(angle)
			var x: float = signf(cx)*pow(absf(cx),roundness)*size.x*.5*layer.x
			var z: float = signf(cz)*pow(absf(cz),roundness)*size.z*.5*layer.x
			ring.append(Vector3(x,size.y*layer.y,z))
		rings.append(ring)
	for r in rings.size()-1:
		for i in 32:
			var j := (i+1)%32
			for v in [rings[r][i],rings[r+1][i],rings[r][j],rings[r][j],rings[r+1][i],rings[r+1][j]]:
				st.set_uv(Vector2(v.x,v.z))
				st.add_vertex(v)
	for i in 32:
		for v in [rings[4][i],Vector3(0,size.y*.53,0),rings[4][(i+1)%32]]:
			st.set_uv(Vector2(v.x,v.z))
			st.add_vertex(v)
	st.generate_normals()
	st.index()
	var node := MeshInstance3D.new()
	node.name=label
	node.mesh=st.commit()
	node.material_override=mat
	node.position=p
	parent.add_child(node)

static func bed(parent: Node3D,p: Vector3,white: bool) -> void:
	parent.set_meta("linen_bed_count",int(parent.get_meta("linen_bed_count",0))+1)
	cushion(parent,"LinenMattress",p+Vector3(0,.55,0),Vector3(1.18,.13,1.98),cloth(Color(.72,.69,.59) if white else Color(.59,.54,.41)))
	cushion(parent,"LinenPillow",p+Vector3(0,.68,-.70),Vector3(.85,.15,.40),cloth(Color(.77,.74,.64)),.48)
	cushion(parent,"WoolBlanketFold",p+Vector3(0,.67,.62),Vector3(1.12,.10,.55),cloth(Color(.32,.30,.22)))

static func room(b,room: Node3D,w: float,d: float) -> void:
	var floor_mat := ShaderMaterial.new()
	floor_mat.shader=preload("res://world/suryagarh/settlements/cantonment_floor.gdshader")
	for mesh in room.get_node("Floor").get_children():
		if mesh is MeshInstance3D: mesh.material_override=floor_mat
	if room.name == "OfficersQuarters":
		for x in [-8.0,8.0]:
			prop(room,"res://objects/household/woven_mat.tscn",Vector3(x,.245,1.15)).scale=Vector3(.65,1,.65)
			prop(room,"res://objects/household/storage/brass_pot.tscn",Vector3(x+.35,1.065,-.15)).scale=Vector3.ONE*.3
	else:
		prop(room,"res://objects/household/water_pot_visual.tscn",Vector3(w*.4,.24,1.15)).scale=Vector3.ONE*.6
	# Peg rail and cross-braces: local detail, central aisle retained.
	for side in [-1.0,1.0]:
		b.piece(room,"KitPegRail",Vector3(side*w*.34,1.65,-d*.5+.3),Vector3(3,.10,.10),b.wood,false)
		for peg in [-1.0,-.5,0.0,.5,1.0]:
			b.piece(room,"KitPeg",Vector3(side*w*.34+peg,1.65,-d*.5+.4),Vector3(.045,.045,.15),b.wood,false)

static func armoury(b,room:Node3D)->void:
	var wood:=surface(Color(.24,.16,.10),2)
	# Storage stays on side walls, clear of doorway and ammunition counter.
	for x in [-8.0,8.0]:
		for y in [.65,1.35,2.05]:
			b.piece(room,"ArmourySideShelf",Vector3(x,y,0),Vector3(1,.10,3.2),wood)
		for z in [-1.45,1.45]:
			b.piece(room,"ShelfUpright",Vector3(x,1.15,z),Vector3(.10,1.82,.10),wood)
		for z in [-.8,.7]:
			prop(room,"res://objects/household/supplies/supply_parcel.tscn",Vector3(x,.70,z))
		prop(room,"res://objects/household/storage/basket.tscn",Vector3(x,1.40,.4)).scale=Vector3.ONE*.6
	prop(room,"res://objects/household/storage/stool.tscn",Vector3(1.6,.24,-2.3))
	# Existing folio was below counter top; correct its support and add a lamp.
	for child in room.get_children():
		if child is Node3D and child.scene_file_path.ends_with("record_folio.tscn"):
			child.position=Vector3(.7,1.01,-4)
	prop(room,"res://objects/household/oil_lamp_visual.tscn",Vector3(-.8,1.01,-4))
	for x in [-6.0,6.0]:
		for offset in [-.8,0.0,.8]:
			# Base chocks and a keeper block locate each rifle stock and barrel.
			for side in [-1.0,1.0]:
				b.piece(room,"RifleStockChock",Vector3(x+offset+side*.13,.62,-3.95),Vector3(.045,.06,.30),wood,false)
			b.piece(room,"RifleKeeper",Vector3(x+offset,1.56,-4.02),Vector3(.16,.10,.07),wood,false)

static func emplacement(b,p:Vector3)->void:
	var iron:=surface(Color(.12,.13,.13))
	for row in 3:
		for col in (3-row)*(3-row):
			var ball:=MeshInstance3D.new()
			ball.name="StackedRoundShot"
			var sphere:=SphereMesh.new()
			sphere.radius=.09
			sphere.height=.18
			ball.mesh=sphere
			ball.material_override=iron
			ball.position=p+Vector3(2.3+(col%(3-row))*.182+row*.091,.13+row*.129,1.8+floorf(float(col)/(3-row))*.182+row*.091)
			b.add_child(ball)
	prop(b,"res://objects/household/storage/bucket.tscn",p+Vector3(-2.4,.04,1.5))
	var staff=b.box("GunSpongeStaff",p+Vector3(2.2,.13,-1),Vector3(.045,.045,2.8),b.wood,false)
	staff.rotation.y=.15
	b.box("SpongeHead",p+Vector3(2.4,.13,.34),Vector3(.15,.14,.26),surface(Color(.35,.30,.22)),false)
