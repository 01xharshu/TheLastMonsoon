extends RefCounted
## Reusable unit geometry. World placement and collision remain in the fort builder.
static func chipped_stone(seed_value: int = 1857) -> ArrayMesh:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	var corners: Array[Vector3] = []
	for p in [Vector3(-.5,-.5,-.5),Vector3(.5,-.5,-.5),Vector3(.5,.5,-.5),Vector3(-.5,.5,-.5),Vector3(-.5,-.5,.5),Vector3(.5,-.5,.5),Vector3(.5,.5,.5),Vector3(-.5,.5,.5)]:
		corners.append(p*random.randf_range(.88,1.0))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in [[0,3,2,1],[4,5,6,7],[0,4,7,3],[1,2,6,5],[0,1,5,4],[3,7,6,2]]:
		for index in [0,1,2,0,2,3]: surface.add_vertex(corners[face[index]])
	surface.generate_normals()
	return surface.commit()

static func fractured_rock() -> ArrayMesh:
	var random := RandomNumberGenerator.new()
	random.seed = 185709
	var rings: Array[PackedVector3Array] = []
	for level in range(5):
		var ring := PackedVector3Array()
		var y: float = [-.5,-.35,.02,.34,.5][level]
		var radius: float = [.22,.47,.5,.36,.09][level]
		for segment in range(9):
			var angle: float = segment*TAU/9.0+level*.11
			var r: float = radius*random.randf_range(.78,1.15)
			ring.append(Vector3(cos(angle)*r,y+random.randf_range(-.035,.035),sin(angle)*r))
		rings.append(ring)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for level in range(4):
		for segment in range(9):
			var next: int = (segment+1)%9
			for vertex in [rings[level][segment],rings[level+1][segment],rings[level][next],rings[level][next],rings[level+1][segment],rings[level+1][next]]: surface.add_vertex(vertex)
	surface.generate_normals()
	return surface.commit()
