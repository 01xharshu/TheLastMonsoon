extends RefCounted
## Original paired-leaf shrub candidate; batch geometry shared by plot and loads.
static func mesh() -> ArrayMesh:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for branch in 3:
		var axis:=Vector3(sin(branch*TAU/3),0,cos(branch*TAU/3))
		for pair in 6:
			var h:=.14+pair*.09
			var center:=Vector3.UP*h+axis*h*.20
			for side in [-1.0,1.0]:
				var direction:Vector3=Vector3(axis.z,0,-axis.x)*side
				var tip:Vector3=center+direction*(.13+sin(pair*.7)*.025)+Vector3.UP*.03
				var middle:=center.lerp(tip,.52)
				var width:=axis*.038
				for vertex:Vector3 in [center,middle-width,tip,center,tip,middle+width]:
					st.set_color(Color(.19,.36,.12));st.set_uv(Vector2(vertex.x,vertex.y));st.add_vertex(vertex)
	st.generate_normals();return st.commit()
