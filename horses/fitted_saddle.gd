extends RefCounted
## Plain curved tack; construction informed by Indian period saddle references.
static func panel(parent: Node3D, label: String, width: float, length_: float, origin: Vector3, height: Callable, thickness: float, material: Material) -> MeshInstance3D:
	var vertices: Array[Vector3] = []
	var nx := 24
	var nz := 20
	for layer in 2:
		for j in nz+1:
			var z := (float(j)/nz-0.5)*length_
			for i in nx+1:
				var x := (float(i)/nx-0.5)*width
				vertices.append(Vector3(x,float(height.call(x,z))-layer*thickness,z))
	var triangles: Array[int] = []
	var layer_size := (nx+1)*(nz+1)
	for layer in 2:
		for j in nz:
			for i in nx:
				var a := layer*layer_size+j*(nx+1)+i
				var quad := [a,a+1,a+nx+2,a+nx+1]
				if layer==1: quad.reverse()
				triangles.append_array([quad[0],quad[1],quad[2],quad[0],quad[2],quad[3]])
	var boundary: Array[int] = []
	for i in nx: boundary.append(i)
	for j in nz: boundary.append(j*(nx+1)+nx)
	for i in range(nx,0,-1): boundary.append(nz*(nx+1)+i)
	for j in range(nz,0,-1): boundary.append(j*(nx+1))
	for i in boundary.size():
		var a := boundary[i]
		var b := boundary[(i+1)%boundary.size()]
		triangles.append_array([a,b+layer_size,b,a,a+layer_size,b+layer_size])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(vertices)
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(triangles)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var surface := SurfaceTool.new()
	surface.create_from(mesh,0)
	surface.generate_normals()
	var node := MeshInstance3D.new()
	node.name = label
	node.position = origin
	node.set_meta("horse_piece",label)
	node.mesh = surface.commit()
	node.material_override = material
	parent.add_child(node)
	return node

static func build(parent: Node3D, leather: Material, cloth: Material) -> void:
	# Cloth bends over the barrel rather than forming a rigid horizontal board.
	panel(parent,"SaddleCloth",1.10,0.88,Vector3(0,1.80,0.02),func(x: float,z: float) -> float: return -0.42*pow(absf(x)/0.55,1.8)+0.008*cos(z*12.0),0.012,cloth)
	# Padded seat with gently raised edges; supported by the fitted cloth.
	panel(parent,"LeatherSaddle",0.48,0.58,Vector3(0,1.86,0.02),func(x: float,z: float) -> float: return 0.04*pow(x/0.24,2)+0.028*pow(z/0.29,2),0.045,leather)
	# Continuous shaped bows, keeping the existing grip nodes recoverable.
	var pommel := panel(parent,"Pommel",0.43,0.09,Vector3(0,1.87,-0.27),func(x: float,z: float) -> float: return 0.16*(1.0-pow(x/0.215,2))+0.018*sqrt(maxf(0.0,1.0-pow(z/0.045,2))),0.025,leather)
	pommel.set_meta("grip_height",2.04)
	panel(parent,"Cantle",0.46,0.10,Vector3(0,1.87,0.30),func(x: float,z: float) -> float: return 0.18*(1.0-pow(x/0.23,2))+0.018*sqrt(maxf(0.0,1.0-pow(z/0.05,2))),0.025,leather)
	var thread := StandardMaterial3D.new()
	thread.albedo_color = Color(0.28,0.20,0.11)
	thread.roughness = 0.95
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for edge in 4:
		var points: Array[Vector3] = []
		for i in 25:
			var t := float(i)/24
			var x := lerpf(-0.535,0.535,t) if edge<2 else (-0.535 if edge==2 else 0.535)
			var z := (-0.425 if edge==0 else 0.425) if edge<2 else lerpf(-0.425,0.425,t)
			points.append(Vector3(x,1.808-0.42*pow(absf(x)/0.55,1.8)+0.008*cos(z*12.0),z+0.02))
		for i in points.size()-1:
			var a := points[i]
			var b := points[i+1]
			var frame := Basis(Quaternion(Vector3.UP,(b-a).normalized()))
			for segment in 8:
				var angle := float(segment)*TAU/8
				var next := float(segment+1)*TAU/8
				var r := frame*Vector3(cos(angle)*0.004,0,sin(angle)*0.004)
				var r_next := frame*Vector3(cos(next)*0.004,0,sin(next)*0.004)
				for point in [a+r,a+r_next,b+r_next,a+r,b+r_next,b+r]: surface.add_vertex(point)
	surface.generate_normals()
	var binding := MeshInstance3D.new()
	binding.name = "SaddleClothBinding"
	binding.set_meta("horse_piece","SaddleClothBinding")
	binding.mesh = surface.commit()
	binding.material_override = thread
	parent.add_child(binding)
