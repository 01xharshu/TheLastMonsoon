extends SceneTree
## Original, deterministic meshes; run headless to rebuild the reusable scenes.
const OUT = "res://assets/props/household/"
var surface: SurfaceTool

func _initialize() -> void:
	build.call_deferred()

func material(color: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = .92
	return result

func triangle(a: Vector3, b: Vector3, c: Vector3, tint: Color = Color.WHITE) -> void:
	for point in [a,b,c]:
		surface.set_color(tint)
		surface.add_vertex(point)

func finish(name_: String, mat: Material) -> ArrayMesh:
	surface.generate_normals()
	surface.index()
	var result := surface.commit()
	result.surface_set_material(0,mat)
	assert(ResourceSaver.save(result,OUT+name_+".res",ResourceSaver.FLAG_CHANGE_PATH) == OK)
	return ResourceLoader.load(OUT+name_+".res","",ResourceLoader.CACHE_MODE_REPLACE)

func mesh_node(parent: Node3D, label: String, mesh: Mesh, at := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.position = at
	parent.add_child(node)
	return node

func tube(parent: Node3D, label: String, a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 6
	mesh.rings = 0
	mesh.material = mat
	var node := mesh_node(parent,label,mesh,(a+b)*.5)
	node.quaternion = Quaternion(Vector3.UP,(b-a).normalized())

func own(node: Node, root_node: Node) -> void:
	for child in node.get_children():
		child.owner = root_node
		own(child,root_node)

func save_scene(node: Node3D, path: String) -> void:
	# Bake repeated reeds/cords into material batches instead of shipping hundreds of nodes.
	if path != "res://objects/roti.tscn":
		var batches: Dictionary = {}
		for child in node.get_children():
			if not child is MeshInstance3D: continue
			var mat: Material = child.mesh.surface_get_material(0)
			if not batches.has(mat):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				batches[mat] = tool
			batches[mat].append_from(child.mesh,0,child.transform)
			child.free()
		var index := 0
		for mat in batches:
			var combined: ArrayMesh = batches[mat].commit()
			combined.surface_set_material(0,mat)
			assert(ResourceSaver.save(combined,OUT+node.name.to_snake_case()+"_"+str(index)+".res",ResourceSaver.FLAG_CHANGE_PATH) == OK)
			mesh_node(node,"Surface"+str(index),ResourceLoader.load(OUT+node.name.to_snake_case()+"_"+str(index)+".res","",ResourceLoader.CACHE_MODE_REPLACE))
			index += 1
	own(node,node)
	var packed := PackedScene.new()
	assert(packed.pack(node) == OK)
	assert(ResourceSaver.save(packed,path) == OK)
	if path == "res://objects/roti.tscn":
		var text := FileAccess.get_file_as_string(path)
		for format in [3,4]:
			text = text.replace("[gd_scene format="+str(format)+"]","[gd_scene format="+str(format)+" uid=\"uid://dlbc130mvno3k\"]")
		var file := FileAccess.open(path,FileAccess.WRITE)
		file.store_string(text)
		file.close()
	node.free()

func bread_point(ring: int, angle: float, upper: bool) -> Vector3:
	var fraction: float = float(ring)/12.0
	var radius: float = .13*fraction*(1.0+.025*sin(angle*7.0)+.014*cos(angle*11.0))
	var y: float = .002 if not upper else .009+.014*(1.0-fraction*fraction)
	if upper: y += .0015*sin(angle*5.0+fraction*18.0)*fraction
	return Vector3(cos(angle)*radius,y,sin(angle)*radius)

func roti() -> void:
	surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for upper in [true,false]:
		for ring in 12:
			for segment in 64:
				var a: float = TAU*segment/64.0
				var b: float = TAU*(segment+1)/64.0
				var p := bread_point(ring,a,upper)
				var q := bread_point(ring+1,a,upper)
				var r := bread_point(ring+1,b,upper)
				var s := bread_point(ring,b,upper)
				if upper:
					triangle(p,r,q)
					triangle(p,s,r)
				else:
					triangle(p,q,r)
					triangle(p,r,s)
	for segment in 64:
		var a: float = TAU*segment/64.0
		var b: float = TAU*(segment+1)/64.0
		triangle(bread_point(12,a,false),bread_point(12,a,true),bread_point(12,b,true))
		triangle(bread_point(12,a,false),bread_point(12,b,true),bread_point(12,b,false))
	var mat := ShaderMaterial.new()
	mat.shader = load(OUT+"roti_surface.gdshader")
	var mesh := finish("roti",mat)
	var node: Node3D = load("res://objects/roti.tscn").instantiate()
	node.get_node("RotiMesh").mesh = mesh
	node.get_node("RotiMesh").position = Vector3.ZERO
	node.get_node("RotiMesh").set_surface_override_material(0,null)
	var shape := CylinderShape3D.new()
	shape.radius = .132
	shape.height = .026
	node.get_node("CollisionShape3D").shape = shape
	node.get_node("CollisionShape3D").position = Vector3(0,.013,0)
	save_scene(node,"res://objects/roti.tscn")

func sack_point(profile: Vector2, angle: float) -> Vector3:
	var folds: float = .012*sin(angle*10.0+profile.y*9.0)+.006*cos(angle*17.0)
	var r: float = maxf(.001,profile.x+folds*minf(1.0,profile.y*12.0))
	return Vector3(cos(angle)*r,profile.y,sin(angle)*r*.82)

func sack() -> void:
	surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile := [Vector2(.001,0),Vector2(.15,0),Vector2(.22,.06),Vector2(.24,.16),Vector2(.235,.28),Vector2(.20,.38),Vector2(.12,.45),Vector2(.055,.49),Vector2(.052,.52),Vector2(.085,.57),Vector2(.001,.565)]
	for ring in range(profile.size()-1):
		for segment in 64:
			var a: float = TAU*segment/64.0
			var b: float = TAU*(segment+1)/64.0
			var p := sack_point(profile[ring],a)
			var q := sack_point(profile[ring+1],a)
			var r := sack_point(profile[ring+1],b)
			var s := sack_point(profile[ring],b)
			triangle(p,r,q)
			triangle(p,s,r)
	var cloth := ShaderMaterial.new()
	cloth.shader = load(OUT+"woven_surface.gdshader")
	var node := StaticBody3D.new()
	node.name = "TiedGrainSack"
	node.add_to_group("solid_period_prop",true)
	mesh_node(node,"GatheredCloth",finish("grain_sack",cloth))
	var cord := material(Color(.28,.19,.095))
	for turn in 3:
		for segment in 48:
			var a: float = TAU*segment/48.0
			var b: float = TAU*(segment+1)/48.0
			tube(node,"NeckCord",Vector3(.059*cos(a),.495+turn*.007,.053*sin(a)),Vector3(.059*cos(b),.495+turn*.007,.053*sin(b)),.004,cord)
	tube(node,"TieTail",Vector3(.056,.51,0),Vector3(.13,.42,.025),.005,cord)
	tube(node,"TieTail",Vector3(.056,.51,0),Vector3(.12,.45,-.04),.005,cord)
	var shape := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for level in [Vector2(.16,0),Vector2(.235,.17),Vector2(.20,.38),Vector2(.08,.57)]:
		for i in 12:
			var angle: float = TAU*i/12.0
			points.append(Vector3(level.x*cos(angle),level.y,level.x*.82*sin(angle)))
	shape.points = points
	var collision := CollisionShape3D.new()
	collision.shape = shape
	node.add_child(collision)
	save_scene(node,"res://objects/household/grain_sack.tscn")

func mat() -> void:
	var node := StaticBody3D.new()
	node.name = "WovenReedMat"
	var reeds := [material(Color(.48,.35,.17)),material(Color(.57,.44,.24)),material(Color(.63,.51,.30))]
	for strand in 100:
		var z: float = -.79+strand*.016
		var mesh := BoxMesh.new()
		mesh.size = Vector3(.9,.007,.014)
		mesh.material = reeds[strand%3]
		mesh_node(node,"Reed",mesh,Vector3(0,.006,z))
	var thread := material(Color(.27,.19,.10))
	surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for column in 10:
		var x: float = -.435+column*.0965
		for strand in 100:
			var z: float = -.798+strand*.016
			var y0: float = .010+(.003 if strand%2==0 else -.003)
			var y1: float = .010+(-.003 if strand%2==0 else .003)
			var a := Vector3(x-.002,y0,z)
			var b := Vector3(x+.002,y0,z)
			var c := Vector3(x+.002,y1,z+.016)
			var d := Vector3(x-.002,y1,z+.016)
			triangle(a,b,c)
			triangle(a,c,d)
	mesh_node(node,"WovenBindings",finish("mat_bindings",thread))
	for side in [-1.0,1.0]:
		tube(node,"BoundEdge",Vector3(side*.448,.011,-.8),Vector3(side*.448,.011,.8),.007,thread)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(.91,.018,1.61)
	collision.shape = shape
	collision.position.y = .009
	node.add_child(collision)
	save_scene(node,"res://objects/household/woven_mat.tscn")

func build() -> void:
	roti()
	sack()
	mat()
	print("HOUSEHOLD BATCH: built roti, tied sack, woven mat")
	quit()
