extends "res://tools/assets/build_activity_sets.gd"
const CRAFT = "res://objects/household/craft/"
func rod(parent: Node3D, label: String, a: Vector3, b: Vector3, radius: float, mat_: Material) -> void:
	tube(parent,label,a,b,radius,mat_)
	parent.get_child(parent.get_child_count()-1).mesh.radial_segments = 24
func save_tool(node: Node3D, filename: String) -> void:
	own_set(node,node)
	var packed := PackedScene.new()
	assert(packed.pack(node) == OK)
	assert(ResourceSaver.save(packed,CRAFT+filename+".tscn") == OK)
	node.free()
func build() -> void:
	var wood := material(Color(.40,.25,.12))
	var dark := material(Color(.22,.13,.06))
	var iron := material(Color(.16,.17,.17))
	iron.metallic = .65
	iron.roughness = .55
	var yarn := material(Color(.72,.64,.47))
	var tool := Node3D.new()
	tool.name = "WoodenMallet"
	rod(tool,"Head",Vector3(-.10,.055,-.10),Vector3(.10,.055,-.10),.055,wood)
	rod(tool,"Handle",Vector3(0,.035,-.1),Vector3(0,.035,.24),.018,dark)
	marker(tool,"Grip",Vector3(0,.035,.12))
	marker(tool,"StrikeFace",Vector3(.1,.055,-.1))
	save_tool(tool,"wooden_mallet")
	tool = Node3D.new()
	tool.name = "WoodChisel"
	box(tool,"Blade",Vector3(.023,.006,.17),Vector3(0,.007,-.095),iron)
	box(tool,"CuttingBevel",Vector3(.023,.002,.018),Vector3(0,.004,-.171),iron)
	rod(tool,"Tang",Vector3(0,.019,-.02),Vector3(0,.019,.06),.008,iron)
	rod(tool,"Handle",Vector3(0,.022,.025),Vector3(0,.022,.19),.022,wood)
	marker(tool,"Grip",Vector3(0,.022,.11))
	marker(tool,"CuttingEdge",Vector3(0,.005,-.18))
	save_tool(tool,"wood_chisel")
	tool = Node3D.new()
	tool.name = "WoodenHandPlane"
	for side in [-1.0,1.0]:
		box(tool,"BodyEnd",Vector3(.065,.045,.09),Vector3(0,.0225,side*.075),wood)
		box(tool,"ThroatCheek",Vector3(.010,.045,.060),Vector3(side*.0275,.0225,0),wood)
	for side in [-1.0,1.0]:
		box(tool,"SoleEnd",Vector3(.066,.004,.107),Vector3(0,.002,side*.0675),dark)
	var blade := box(tool,"Iron",Vector3(.044,.006,.11),Vector3(0,.0357,.01),iron)
	blade.rotation.x = -.65
	var wedge := box(tool,"Wedge",Vector3(.035,.014,.055),Vector3(0,.055,.029),dark)
	wedge.rotation.x = -.65
	marker(tool,"FrontGrip",Vector3(0,.045,-.09))
	marker(tool,"RearGrip",Vector3(0,.045,.09))
	marker(tool,"Grip",Vector3(0,.045,.09))
	marker(tool,"CuttingContact",Vector3(0,0,-.015))
	save_tool(tool,"wood_hand_plane")
	tool = Node3D.new()
	tool.name = "WeavingShuttle"
	for side in [-1.0,1.0]:
		var points := [Vector3(-.026,0,side*.07),Vector3(.026,0,side*.07),Vector3(0,0,side*.13),Vector3(-.026,.022,side*.07),Vector3(.026,.022,side*.07),Vector3(0,.022,side*.13)]
		surface = SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for face in [[0,2,1],[3,4,5],[0,1,4],[0,4,3],[1,2,5],[1,5,4],[2,0,3],[2,3,5]]:
			if side>0: triangle(points[face[0]],points[face[1]],points[face[2]])
			else: triangle(points[face[0]],points[face[2]],points[face[1]])
		surface.generate_normals()
		var tip_mesh := surface.commit()
		tip_mesh.surface_set_material(0,wood)
		mesh_node(tool,"TaperedTip",tip_mesh)
	for side in [-1.0,1.0]:
		box(tool,"SideRail",Vector3(.007,.022,.14),Vector3(side*.023,.011,0),wood)
	rod(tool,"Spindle",Vector3(0,.012,-.07),Vector3(0,.012,.07),.004,dark)
	rod(tool,"WoundYarn",Vector3(0,.012,-.05),Vector3(0,.012,.05),.01,yarn)
	marker(tool,"Grip",Vector3(.023,.014,0))
	marker(tool,"ThreadExit",Vector3(.027,.012,.035))
	save_tool(tool,"weaving_shuttle")
	tool = Node3D.new()
	tool.name = "YarnSpool"
	for y in [.004,.116]: rod(tool,"Flange",Vector3(0,y-.004,0),Vector3(0,y+.004,0),.065,wood)
	rod(tool,"Core",Vector3(0,.008,0),Vector3(0,.112,0),.018,dark)
	rod(tool,"Yarn",Vector3(0,.009,0),Vector3(0,.111,0),.050,yarn)
	marker(tool,"Grip",Vector3(.052,.06,0))
	marker(tool,"ThreadExit",Vector3(.05,.075,0))
	save_tool(tool,"yarn_spool")
	for craft in ["carpenter","weaver"]:
		var set_ := Node3D.new()
		set_.name = craft.capitalize()+"WorkSurface"
		part(set_,"Top",Vector3(1.30,.055,.65),Vector3(0,.7525,0),wood)
		for x in [-.55,.55]:
			for z in [-.24,.24]: part(set_,"Leg",Vector3(.075,.725,.075),Vector3(x,.3625,z),dark)
		part(set_,"RearBrace",Vector3(1.12,.07,.06),Vector3(0,.30,-.24),dark)
		if craft == "carpenter":
			box(set_,"Workpiece",Vector3(.46,.045,.16),Vector3(-.30,.8025,-.10),wood)
			var plane := instance_prop(set_,CRAFT+"wood_hand_plane.tscn","Plane",Vector3(-.30,.825,-.10))
			plane.rotation.y = PI/2
			instance_prop(set_,CRAFT+"wood_chisel.tscn","Chisel",Vector3(.11,.78,.03))
			instance_prop(set_,CRAFT+"wooden_mallet.tscn","Mallet",Vector3(.40,.78,0))
		else:
			instance_prop(set_,CRAFT+"weaving_shuttle.tscn","Shuttle",Vector3(-.24,.78,.15))
			instance_prop(set_,CRAFT+"yarn_spool.tscn","Spool",Vector3(.25,.78,-.08))
			box(set_,"FoldedCloth",Vector3(.30,.018,.22),Vector3(-.28,.789,-.16),yarn)
		marker(set_,"Approach",Vector3(0,0,.85))
		marker(set_,"WorkContact",Vector3(-.3,.825,-.1) if craft=="carpenter" else Vector3(-.24,.792,.05))
		pack_set(set_,craft+"_work_surface")
	print("CRAFT: five tool visuals and two work surfaces built")
	quit()
