extends RefCounted

static func build(builder: Node3D, parent: Node3D, at: Vector3, yaw: float, senior := false, height := .91) -> Node3D:
	var desk := Node3D.new()
	desk.name = "OfficialPedestalDesk" if senior else "ClerkWritingDesk"
	parent.add_child(desk, true)
	desk.position = at
	desk.rotation.y = yaw
	var wood := ShaderMaterial.new()
	wood.shader = preload("res://world/suryagarh/settlements/administrative_surface.gdshader")
	wood.set_shader_parameter("tint",Color(.25,.125,.075))
	wood.set_shader_parameter("kind",2)
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(.53,.35,.13)
	brass.metallic = .65
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color(.18,.23,.13)
	builder.piece(desk,"WritingTop",Vector3(0,height-.055,0),Vector3(2.2,.11,1),wood)
	builder.piece(desk,"MouldedEdge",Vector3(0,height-.095,0),Vector3(2.24,.036,1.03),wood,false)
	builder.piece(desk,"WritingInset",Vector3(0,height+.002,0),Vector3(2.04,.005,.84),leather,false)
	for x in [-.78,.78]:
		builder.piece(desk,"PedestalPlinth",Vector3(x,.045,0),Vector3(.56,.09,.91),wood)
		for side in [-1,1]:
			builder.piece(desk,"PedestalSide",Vector3(x+side*.245,(height-.09)*.5,0),Vector3(.055,height-.09,.88),wood)
		builder.piece(desk,"PedestalBack",Vector3(x,(height-.09)*.5,.42),Vector3(.47,height-.09,.045),wood)
		for row in 3:
			var y: float = .13+float(row)*(height-.22)/3.0
			var drawer := Node3D.new()
			drawer.name = "MissionDrawer" if senior and x>0 and row==1 else "Drawer"
			desk.add_child(drawer,true)
			drawer.position = Vector3(x,y,-.43)
			builder.piece(drawer,"DrawerFront",Vector3(0,.10,0),Vector3(.465,.19,.037),wood,false)
			builder.piece(drawer,"DrawerBottom",Vector3(0,.02,.14),Vector3(.45,.028,.31),wood,false)
			builder.piece(drawer,"DrawerBack",Vector3(0,.07,.29),Vector3(.45,.09,.02),wood,false)
			for side in [-1,1]:
				builder.piece(drawer,"DrawerSide",Vector3(side*.21,.07,.14),Vector3(.025,.09,.31),wood,false)
				builder.piece(drawer,"BrassPullMount",Vector3(side*.075,.11,-.027),Vector3(.036,.036,.016),brass,false)
			builder.piece(drawer,"BrassBail",Vector3(0,.084,-.044),Vector3(.135,.018,.023),brass,false)
			for side in [-1,1]:
				builder.piece(drawer,"BrassBailEnd",Vector3(side*.067,.096,-.044),Vector3(.02,.034,.023),brass,false)
	builder.piece(desk,"KneeholeApron",Vector3(0,height-.15,.40),Vector3(1.03,.14,.07),wood,false)
	if senior:
		rug(builder,desk)
		var lamp: Node3D = preload("res://objects/household/oil_lamp_visual.tscn").instantiate()
		desk.add_child(lamp)
		lamp.position = Vector3(-.73,height,.19)
		var light := OmniLight3D.new()
		lamp.add_child(light)
		light.position.y = .18
		light.light_color = Color(1,.76,.50)
		light.light_energy = .85
		light.omni_range = 2.6
	return desk

static func rug(builder: Node3D, desk: Node3D) -> void:
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(.31,.12,.085)
	var border := StandardMaterial3D.new()
	border.albedo_color = Color(.59,.40,.22)
	builder.piece(desk,"WovenOfficeCarpet",Vector3(0,.009,0),Vector3(3.6,.018,4.15),red,false)
	for side in [-1,1]:
		builder.piece(desk,"CarpetSideBorder",Vector3(side*1.68,.019,0),Vector3(.095,.004,3.94),border,false)
		builder.piece(desk,"CarpetEndBorder",Vector3(0,.019,side*1.94),Vector3(3.45,.004,.095),border,false)
	for x in [-1.35,0,1.35]:
		for z in [-1.62,1.62]:
			var motif: Node3D = builder.piece(desk,"CarpetDiamond",Vector3(x,.022,z),Vector3(.24,.003,.24),border,false)
			motif.rotation.y = PI/4
