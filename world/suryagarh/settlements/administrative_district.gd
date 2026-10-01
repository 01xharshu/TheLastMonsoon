extends RefCounted
## Fictional district offices; construction candidate, staffing and service loops pending.
var b: Node3D
var district: Node3D
var shell_builder = preload("res://world/suryagarh/settlements/cantonment.gd").new()
func build(builder: Node3D) -> void:
	b = builder
	district = Node3D.new()
	district.name = "AdministrativeDistrict"
	district.position = Vector3(520,10,120)
	b.add_child(district)
	district.set_meta("location_numbers",[4,5,6])
	shell_builder.b = b
	shell_builder.district = district
	var collector := room("Collectorate",Vector3(0,0,-25),Vector2(30,14),"COLLECTORATE")
	for x in [-10.0,0.0,10.0]:
		desk(collector,Vector3(x,0.24,-3))
	for x in [-5.0,5.0]: b.piece(collector,"OfficePartition",Vector3(x,1.5,-3),Vector3(0.18,2.5,7),b.plaster)
	for x in [-11.0,11.0]: bench(collector,Vector3(x,0.24,4))
	var treasury := room("DistrictTreasury",Vector3(-43,0,12),Vector2(22,18),"DISTRICT TREASURY")
	for x in [-6.0,6.0]: desk(treasury,Vector3(x,0.24,2))
	for side in [-1,1]:
		b.piece(treasury,"StrongroomPartition",Vector3(side*6.25,1.9,-3),Vector3(9.5,3.35,0.35),b.brick)
		for x in [-7.0,-4.0,4.0,7.0]:
			if signf(x) != side: continue
			var crate: Node3D = load("res://objects/household/storage/crate.tscn").instantiate()
			treasury.add_child(crate)
			crate.position = Vector3(x,0.24,-6)
	var court := room("BritishCourthouse",Vector3(39,0,10),Vector2(32,22),"DISTRICT COURTHOUSE")
	b.piece(court,"JudgesDais",Vector3(0,0.33,-7.5),Vector3(12,0.18,4.5),b.wood)
	desk(court,Vector3(0,0.42,-7.5))
	for x in [-7.0,7.0]:
		for z in [-2.0,2.0,6.0]: bench(court,Vector3(x,0.24,z))
	desk(court,Vector3(11,0.24,-7))
	for node in district.get_children():
		if node is Node3D: b.merge_visuals(node)
func room(id: String, at: Vector3, size: Vector2, title: String) -> Node3D:
	var node: Node3D = shell_builder.shell(id,at,size,title)
	node.remove_from_group("cantonment_buildings")
	node.add_to_group("administrative_buildings")
	# Raise the roof eaves above the masonry and close both triangular gables.
	for part in node.get_children():
		if part.get_child_count() == 0 or not part.get_child(0) is MeshInstance3D: continue
		var mesh: Mesh = part.get_child(0).mesh
		if not mesh is BoxMesh: continue
		if is_equal_approx(mesh.size.y,0.16): part.position.y = 3.7+size.x*0.03
		if is_equal_approx(mesh.size.x,0.25): part.position.y = 3.7+size.x*0.06
	for z in [-size.y/2,size.y/2]:
		b.piece(node,"EaveHeader",Vector3(0,3.6375,z),Vector3(size.x,0.125,0.4),b.plaster)
		gable(node,size.x,z)
	# Long shaded veranda, supported by physical columns; central path remains clear.
	b.piece(node,"VerandaFloor",Vector3(0,0.12,size.y/2+2),Vector3(size.x+0.6,0.24,4),b.stone)
	b.piece(node,"VerandaRoof",Vector3(0,3.15,size.y/2+2),Vector3(size.x+1,0.16,4.8),b.tile)
	for x in [-size.x/2+1,-size.x/4,size.x/4,size.x/2-1]: b.column(node,Vector3(x,1.7,size.y/2+3.6),2.9)
	node.get_node("Entrance").position.z = size.y/2+5
	# Replace the solid rear wall with genuine window openings.
	var rear: Node = node.get_node("RearWall")
	node.remove_child(rear)
	rear.free()
	b.piece(node,"WindowSillWall",Vector3(0,0.825,-size.y/2),Vector3(size.x,1.2,0.4),b.plaster)
	b.piece(node,"WindowHeader",Vector3(0,3.175,-size.y/2),Vector3(size.x,0.8,0.4),b.plaster)
	var bays := int(size.x/4)
	for i in range(bays+1):
		var x: float = -size.x/2 + size.x*i/bays
		b.piece(node,"WindowPier",Vector3(x,2.1,-size.y/2),Vector3(1.6,1.35,0.4),b.plaster)
		if i < bays:
			var mid: float = x+size.x/bays/2
			for offset in [-0.5,0.0,0.5]: b.piece(node,"WindowBar",Vector3(mid+offset,2.1,-size.y/2),Vector3(0.035,1.35,0.035),b.iron,false)
	return node
func desk(parent: Node3D, at: Vector3) -> void:
	b.piece(parent,"WritingDesk",at+Vector3(0,0.78,0),Vector3(2.2,0.12,1.0),b.wood)
	for x in [-0.9,0.9]:
		for z in [-0.35,0.35]: b.piece(parent,"DeskLeg",at+Vector3(x,0.36,z),Vector3(0.1,0.72,0.1),b.wood)
	b.piece(parent,"Ledger",at+Vector3(-0.45,0.865,0),Vector3(0.4,0.05,0.3),b.ochre,false)
	b.piece(parent,"WritingSheet",at+Vector3(0.45,0.842,0),Vector3(0.35,0.004,0.25),b.plaster,false)
func bench(parent: Node3D, at: Vector3) -> void:
	b.piece(parent,"WaitingBench",at+Vector3(0,0.45,0),Vector3(4,0.12,0.6),b.wood)
	for x in [-1.7,1.7]: b.piece(parent,"BenchLeg",at+Vector3(x,0.21,0),Vector3(0.15,0.42,0.5),b.wood)
func gable(parent: Node3D, width: float, z: float) -> void:
	var vertices: Array[Vector3] = []
	for face in [-0.2,0.2]:
		vertices.append(Vector3(-width/2,3.7,z+face))
		vertices.append(Vector3(width/2,3.7,z+face))
		vertices.append(Vector3(0,3.7+width*0.06,z+face))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for triangle in [[0,2,1],[3,4,5],[0,1,4],[0,4,3],[1,2,5],[1,5,4],[2,0,3],[2,3,5]]:
		for i in triangle: st.add_vertex(vertices[i])
	st.generate_normals()
	st.index()
	var visual := MeshInstance3D.new()
	visual.mesh = st.commit()
	visual.material_override = b.plaster
	parent.add_child(visual)
	var body := StaticBody3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = PackedVector3Array(vertices)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
