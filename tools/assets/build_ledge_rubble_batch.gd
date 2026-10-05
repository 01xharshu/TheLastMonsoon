extends "res://tools/assets/build_obstacle_batch.gd"
## Original beveled stone geometry; deterministic, no downloaded source.
func stone(parent: Node3D, label: String, at: Vector3, size_: Vector3, yaw: float, seed_: int, mat_: Material) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	body.rotation.y = yaw
	parent.add_child(body)
	var profile := [Vector2(-.38,-.5),Vector2(.37,-.5),Vector2(.5,-.36),Vector2(.5,.36),Vector2(.36,.5),Vector2(-.37,.5),Vector2(-.5,.35),Vector2(-.5,-.37)]
	var points := PackedVector3Array()
	for ring in 4:
		var inset: float = .88 if ring in [0,3] else 1.0
		var y: float = [0.0,.06,.94,1.0][ring]*size_.y
		for i in 8:
			var p: Vector2 = profile[i]*inset
			var jitter := .008*sin(float(i*13+seed_*7))
			points.append(Vector3((p.x+jitter)*size_.x,y,(p.y-jitter)*size_.z))
	surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in 3:
		for i in 8:
			var a := ring*8+i
			var b := ring*8+(i+1)%8
			triangle_outward(points[a],points[b+8],points[b])
			triangle_outward(points[a],points[a+8],points[b+8])
	for i in range(1,7):
		triangle_outward(points[0],points[i],points[i+1])
		triangle_outward(points[24],points[24+i+1],points[24+i])
	surface.generate_normals()
	surface.index()
	var mesh := surface.commit()
	mesh.surface_set_material(0,mat_)
	mesh_node(body,"StoneMesh",mesh)
	var collider := CollisionShape3D.new()
	var hull := ConvexPolygonShape3D.new()
	hull.points = points
	collider.shape = hull
	body.add_child(collider)
func ledge(label: String, height: float, filename: String) -> void:
	var node := Node3D.new()
	node.name = label
	var mat_ := material(Color(.43,.41,.35))
	for row in 2:
		for i in 4:
			stone(node,"LedgeStone",Vector3(-.675+i*.45,row*height*.5,0),Vector3(.45,height*.5,.75),0,i+row*4,mat_)
	marker(node,"LeftPalm",Vector3(-.26,height,.34))
	marker(node,"RightPalm",Vector3(.26,height,.34))
	marker(node,"LeftSole",Vector3(-.17,height,.08))
	marker(node,"RightSole",Vector3(.17,height,.08))
	marker(node,"TopClearance",Vector3(0,height,-.12))
	marker(node,"Landing",Vector3(0,0,-1.1))
	node.set_meta("interaction_status","solid geometry; no new climb controller")
	save_obstacle(node,filename)
func build() -> void:
	ledge("LowStoneLedge",.45,"low_stone_ledge")
	ledge("WaistStoneLedge",.9,"waist_stone_ledge")
	var rubble := Node3D.new()
	rubble.name = "StoneRubblePile"
	var shades := [material(Color(.40,.38,.32)),material(Color(.48,.44,.37)),material(Color(.34,.33,.29))]
	for i in 9:
		var x: float = (i%3-1)*.43
		var z: float = (i/3-1)*.37
		stone(rubble,"FallenStone",Vector3(x,0,z),Vector3(.42,.16+.045*(i%3),.35),.16*sin(i*2),i,shades[i%3])
	for i in 4:
		stone(rubble,"UpperStone",Vector3(-.43 if i%2==0 else .43,.16 if i%2==0 else .25,-.37 if i<2 else .37),Vector3(.32,.15,.28),.4+i*.27,20+i,shades[i%3])
	marker(rubble,"StepOverReference",Vector3(0,.40,0))
	rubble.set_meta("interaction_status","decorative solid rubble; not loot")
	save_obstacle(rubble,"stone_rubble")
	print("LEDGE/RUBBLE: three reusable candidates built")
	quit()

func triangle_outward(a: Vector3, b: Vector3, c: Vector3) -> void:
	triangle(a,c,b)
