extends Node3D
## Bounded, survey-grounded dressing. Never places obstacles in travelled lanes.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
var layout := Layout.new()
var rng := RandomNumberGenerator.new()
var rock_material: StandardMaterial3D
var stones: Array[Transform3D] = []
var stone_positions: Array[Vector3] = []
var prop_count := 0

func _ready() -> void:
	name = "RouteAndMarketDetail"
	rng.seed = 1857
	rock_material = StandardMaterial3D.new()
	rock_material.albedo_texture = preload("res://assets/nature/materials/rock_boulder_dry_diff_1k.jpg")
	rock_material.normal_enabled = true
	rock_material.normal_texture = preload("res://assets/nature/materials/rock_boulder_dry_nor_gl_1k.jpg")
	rock_material.roughness = .96
	rock_material.albedo_color=Color(.58,.53,.45)
	_mountain()
	_batch_stones()
	_dress_settlement()
	set_meta("prop_count", prop_count)

func ground(p: Vector2) -> Vector3:
	return Vector3(p.x,layout.height(p.x,p.y),p.y)

func _stone(p: Vector2, size: Vector3, yaw: float, lift := 0.0) -> void:
	if layout.road_distance(p.x,p.y)<5.4:return
	var at := ground(p)+Vector3.UP*(size.y*.34+lift)
	stones.append(Transform3D(Basis(Vector3.UP,yaw).scaled(size),at))
	stone_positions.append(at)

func _mountain() -> void:
	var route: Array = Layout.ROUTES["fort_trail"]
	# Reinforcement on steep outer verges, with deliberate gaps at switchbacks.
	for segment in range(3,route.size()-1):
		var a: Vector2 = route[segment]
		var b: Vector2 = route[segment+1]
		var tangent := (b-a).normalized()
		var normal := Vector2(-tangent.y,tangent.x)
		var steps := maxi(1,int(a.distance_to(b)/1.2))
		for step in range(2,steps-2):
			var p := a.lerp(b,float(step)/steps)
			var side := 1.0 if layout.height((p+normal*7).x,(p+normal*7).y)<layout.height((p-normal*7).x,(p-normal*7).y) else -1.0
			var edge := p+normal*side*6.1
			if layout.road_distance(edge.x,edge.y)<5.4: continue
			for course in 2:
				_stone(edge+tangent*(.25 if course==1 else 0.0),Vector3(rng.randf_range(.8,1.1),.42,rng.randf_range(.45,.65)),atan2(tangent.y,tangent.x),course*.32)
			if step%5==0:
				_stone(p-normal*side*rng.randf_range(7,10),Vector3(rng.randf_range(.6,1.4),rng.randf_range(.4,.9),rng.randf_range(.6,1.1)),rng.randf()*TAU)
		_drain(a,b,normal)

func _drain(a: Vector2,b: Vector2,normal: Vector2) -> void:
	# Narrow rock-lined runoff bed on the uphill verge; conforms at 1 m intervals.
	var middle := (a+b)*.5
	var side := 1.0 if layout.height((middle+normal*7).x,(middle+normal*7).y)>layout.height((middle-normal*7).x,(middle-normal*7).y) else -1.0
	var st := SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := maxi(1,ceili(a.distance_to(b)))
	for i in range(2,steps-2):
		var p := a.lerp(b,float(i)/steps)+normal*side*5.5
		var q := a.lerp(b,float(i+1)/steps)+normal*side*5.5
		if layout.road_distance(p.x,p.y)<4.8:continue
		var points: Array[Vector2] = [p-normal*.24,p+normal*.24,q-normal*.24,q+normal*.24]
		for index in [0,2,1,1,2,3]:
			st.set_uv(points[index]*.7);st.add_vertex(ground(points[index])+Vector3.UP*.025)
	st.generate_normals()
	var mesh := MeshInstance3D.new();mesh.name="RunoffBed%d"%get_child_count();mesh.mesh=st.commit();mesh.material_override=rock_material
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)

func _batch_stones() -> void:
	var primitive := SphereMesh.new();primitive.radial_segments=9;primitive.rings=4;primitive.radius=.5;primitive.height=1.0
	var source_faces := primitive.get_faces()
	var collision_source := PackedVector3Array()
	var st := SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in source_faces:
		var irregular := 1.0+.18*sin(vertex.x*23.0+vertex.y*17.0+vertex.z*31.0)
		st.set_uv(Vector2(vertex.x+vertex.z,vertex.y)*2.0)
		st.add_vertex(vertex*irregular)
		collision_source.append(vertex*irregular)
	st.generate_normals();st.generate_tangents();st.index()
	var mesh := st.commit()
	var batch := MultiMeshInstance3D.new();batch.name="DryStoneVerge"
	batch.multimesh=MultiMesh.new();batch.multimesh.transform_format=MultiMesh.TRANSFORM_3D;batch.multimesh.mesh=mesh;batch.multimesh.instance_count=stones.size()
	batch.material_override=rock_material;batch.visibility_range_end=150;batch.visibility_range_end_margin=20
	add_child(batch)
	for i in stones.size():batch.multimesh.set_instance_transform(i,stones[i])
	# One trimesh collision for the stone assembly, with the same transformed vertices.
	var faces := PackedVector3Array()
	var source := collision_source
	for transform in stones:
		for vertex in source:faces.append(transform*vertex)
	var body := StaticBody3D.new();body.name="VergeStoneContact"
	var shape := CollisionShape3D.new();var concave := ConcavePolygonShape3D.new();concave.set_faces(faces);shape.shape=concave
	body.add_child(shape);add_child(body)

func _prop(parent: Node3D,path: String,at: Vector3,yaw := 0.0) -> void:
	var prop: Node3D = load("res://objects/household/"+path+".tscn").instantiate()
	prop.name="PeriodDetail%d"%prop_count;parent.add_child(prop);prop.position=at;prop.rotation.y=yaw;prop_count+=1

func _dress_settlement() -> void:
	var settlement := get_parent().get_node("Settlement")
	for i in 8:
		var stall: Node3D = settlement.get_node("BhairavpurMarketStall%d"%i)
		_apron(stall,Vector2(5.5,3.5),Vector2.ZERO)
		_prop(stall,"woven_mat",Vector3(.9,.025,-.85),.08)
		_prop(stall,"grain_sack",Vector3(1.55,0,-.85),.2+i*.31)
		_prop(stall,"storage/basket",Vector3(-1.4,.94,0),i*.47)
		if i%2==0:_prop(stall,"storage/stool",Vector3(.6,0,-.85),.25)
	for i in [2,5,9,16,23,28]:
		var house: Node3D = settlement.get_node("BhairavpurHouse%d"%i)
		# Side of the house, away from the centre doorway and street approaches.
		_apron(house,Vector2(4.0,1.8),Vector2(-1.5,-4.2))
		_prop(house,"storage/bucket",Vector3(-2.8,0,-4.0),i*.3)
		_prop(house,"woven_mat",Vector3(-1.1,.025,-4.2),.12)
		_prop(house,"storage/basket",Vector3(-.6,0,-4.0),.2)
	for stall in get_tree().get_nodes_in_group("cantonment_bazaar_stalls"):
		if stall is Node3D:
			_prop(stall,"grain_sack",Vector3(2.9,.16,-1.4),.4)
			_prop(stall,"storage/crate",Vector3(2.9,.16,-2.2),-.08)
			_prop(stall,"storage/brass_pot",Vector3(2.9,.16,-.5),.3)

static func canopy(parent: Node3D, material: Material,index: int) -> void:
	var st := SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var width := 4.9;var depth := 2.9
	for x in 16:
		for z in 8:
			for corner in [Vector2(0,0),Vector2(0,1),Vector2(1,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
				var u: float = (x+corner.x)/16.0;var v: float = (z+corner.y)/8.0
				var sag := .20*sin(PI*u)*sin(PI*v)
				st.set_uv(Vector2(u,v));st.add_vertex(Vector3((u-.5)*width,2.57-sag-v*.12+.018*sin(u*TAU*7+index)*sin(PI*v),(v-.5)*depth))
	st.generate_normals();st.index()
	var mesh := MeshInstance3D.new();mesh.name="TensionedClothShade";mesh.mesh=st.commit()
	var cloth := ShaderMaterial.new();cloth.shader=preload("res://world/suryagarh/shaders/market_cloth.gdshader")
	var tint: Color=material.get_shader_parameter("tint") if material is ShaderMaterial else material.get("albedo_color")
	cloth.set_shader_parameter("tint",tint)
	mesh.material_override=cloth;parent.add_child(mesh)

func _apron(parent: Node3D, size: Vector2, center: Vector2) -> void:
	var st := SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in 6:
		for z in 4:
			for corner in [Vector2(0,0),Vector2(0,1),Vector2(1,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
				var uv := Vector2((x+corner.x)/6.0,(z+corner.y)/4.0)
				var local := Vector3((uv.x-.5)*size.x+center.x,0,(uv.y-.5)*size.y+center.y)
				var point := parent.to_global(local)
				point.y=layout.height(point.x,point.z)+.035
				st.set_uv(uv);st.add_vertex(parent.to_local(point))
	st.generate_normals();st.index()
	var mat := ShaderMaterial.new();mat.shader=preload("res://world/suryagarh/shaders/work_earth.gdshader")
	mat.set_shader_parameter("earth_texture",preload("res://assets/nature/materials/brown_mud_dry_diff_1k.jpg"))
	var mesh := MeshInstance3D.new();mesh.name="PackedWorkApron";mesh.mesh=st.commit();mesh.material_override=mat
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;parent.add_child(mesh)
