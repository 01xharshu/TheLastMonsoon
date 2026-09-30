extends "res://tools/assets/build_household_batch.gd"
## Batch 1B: baked original assets, removable parts and future interaction markers.

func lathe(label: String, profile: Array[Vector2], mat: Material, depth := 1.0) -> ArrayMesh:
	surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(profile.size()-1):
		for segment in 64:
			var a: float = TAU*segment/64.0
			var b: float = TAU*(segment+1)/64.0
			var p := Vector3(profile[ring].x*cos(a),profile[ring].y,profile[ring].x*sin(a)*depth)
			var q := Vector3(profile[ring+1].x*cos(a),profile[ring+1].y,profile[ring+1].x*sin(a)*depth)
			var r := Vector3(profile[ring+1].x*cos(b),profile[ring+1].y,profile[ring+1].x*sin(b)*depth)
			var s := Vector3(profile[ring].x*cos(b),profile[ring].y,profile[ring].x*sin(b)*depth)
			triangle(p,r,q)
			triangle(p,s,r)
	return finish(label,mat)

func disk(label: String, radius: float, height: float, mat: Material) -> Mesh:
	return lathe(label,[Vector2(0,0),Vector2(radius,0),Vector2(radius,height),Vector2(0,height)],mat)

func marker(parent: Node3D, label: String, at: Vector3) -> void:
	var point := Marker3D.new()
	point.name = label
	point.position = at
	parent.add_child(point)

func packed(node: Node3D, path: String) -> void:
	own(node,node)
	var scene := PackedScene.new()
	assert(scene.pack(node)==OK)
	assert(ResourceSaver.save(scene,path)==OK)
	node.free()

func merge_parts(parent: Node3D, label: String, mat: Material) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for child in parent.get_children():
		if not child is MeshInstance3D: continue
		tool.append_from(child.mesh,0,child.transform)
		child.free()
	var result := tool.commit()
	result.surface_set_material(0,mat)
	assert(ResourceSaver.save(result,OUT+label+".res")==OK)
	mesh_node(parent,label,ResourceLoader.load(OUT+label+".res","",ResourceLoader.CACHE_MODE_REPLACE))

func pot() -> void:
	var clay := ShaderMaterial.new()
	clay.shader = load(OUT+"terracotta_surface.gdshader")
	var shell := lathe("water_pot",[
		Vector2(0,0),Vector2(.13,0),Vector2(.15,.025),Vector2(.21,.09),
		Vector2(.285,.22),Vector2(.31,.38),Vector2(.30,.49),Vector2(.265,.60),
		Vector2(.19,.69),Vector2(.175,.745),Vector2(.19,.77),Vector2(.19,.795),
		Vector2(.16,.80),Vector2(.15,.77),Vector2(.15,.735),Vector2(.165,.69),
		Vector2(.24,.60),Vector2(.275,.49),Vector2(.284,.38),Vector2(.26,.22),
		Vector2(.185,.09),Vector2(.12,.032),Vector2(0,.032)],clay)
	var visual := Node3D.new()
	visual.name = "WaterPotVisual"
	mesh_node(visual,"EarthenShell",shell)
	var water := material(Color(.10,.14,.12))
	water.roughness = .15
	mesh_node(visual,"StoredWater",disk("pot_water",.245,.002,water),Vector3(0,.565,0))
	marker(visual,"Mouth",Vector3(0,.8,0))
	marker(visual,"WaterSurface",Vector3(0,.567,0))
	marker(visual,"LeftGrip",Vector3(-.18,.70,0))
	marker(visual,"RightGrip",Vector3(.18,.70,0))
	packed(visual,"res://objects/household/water_pot_visual.tscn")

func pouch() -> void:
	var leather := ShaderMaterial.new()
	leather.shader = load(OUT+"leather_surface.gdshader")
	var visual := Node3D.new()
	visual.name = "WaterPouchVisual"
	var outline: Array[Vector2] = [Vector2(0,0),Vector2(.065,.008),Vector2(.11,.05),Vector2(.13,.12),Vector2(.125,.21),Vector2(.105,.265),Vector2(.055,.29),Vector2(.032,.31),Vector2(.028,.335),Vector2(0,.335)]
	mesh_node(visual,"LeatherBody",lathe("water_pouch",outline,leather,.50))
	var seam := Node3D.new()
	visual.add_child(seam)
	var cord := material(Color(.22,.115,.055))
	for side in [-1.0,1.0]:
		for i in range(1,7):
			var a := Vector3(outline[i].x*side,outline[i].y,0)
			var b := Vector3(outline[i+1].x*side,outline[i+1].y,0)
			tube(seam,"EdgeBinding",a,b,.0035,cord)
			for stitch in 4:
				var p: Vector3 = a.lerp(b,float(stitch)/4.0)
				tube(seam,"Stitch",p+Vector3(-.003,.003,-.004),p+Vector3(.003,-.003,.004),.0012,cord)
	var last := Vector3(-.065,.275,0)
	for i in range(1,25):
		var angle: float = PI+PI*i/24.0
		var next := Vector3(cos(angle)*.065,.275-sin(angle)*.135,0)
		tube(seam,"CarryLoop",last,next,.006,cord)
		last = next
	merge_parts(seam,"pouch_seams_loop",cord)
	seam.name = "BindingAndLoop"
	var wood := material(Color(.32,.19,.085))
	mesh_node(visual,"Stopper",lathe("pouch_stopper",[Vector2(0,0),Vector2(.022,0),Vector2(.027,.018),Vector2(.029,.026),Vector2(0,.026)],wood),Vector3(0,.329,0))
	marker(visual,"Mouth",Vector3(0,.335,0))
	marker(visual,"RightGrip",Vector3(.10,.18,.025))
	marker(visual,"LeftGrip",Vector3(-.10,.18,.025))
	marker(visual,"BeltLoop",Vector3(0,.41,0))
	packed(visual,"res://objects/household/water_pouch_visual.tscn")

func lamp() -> void:
	var brass := ShaderMaterial.new()
	brass.shader = load(OUT+"aged_brass_surface.gdshader")
	var shell := lathe("oil_lamp",[Vector2(0,0),Vector2(.075,0),Vector2(.08,.012),Vector2(.105,.024),Vector2(.12,.05),Vector2(.125,.07),Vector2(.12,.082),Vector2(.105,.082),Vector2(.10,.06),Vector2(.08,.035),Vector2(0,.028)],brass)
	var visual := Node3D.new()
	visual.name = "OilLampVisual"
	mesh_node(visual,"Reservoir",shell)
	var spout := BoxMesh.new()
	spout.size = Vector3(.038,.017,.11)
	spout.material = brass
	mesh_node(visual,"WickSpout",spout,Vector3(0,.056,.135))
	var oil := material(Color(.045,.03,.01))
	oil.roughness = .22
	mesh_node(visual,"Oil",disk("lamp_oil",.096,.002,oil),Vector3(0,.055,0))
	var wick := material(Color(.13,.075,.02))
	tube(visual,"Wick",Vector3(0,.065,.115),Vector3(0,.072,.185),.004,wick)
	var fire := material(Color(1,.48,.055))
	fire.emission_enabled = true
	fire.emission = Color(1,.38,.04)
	fire.emission_energy_multiplier = 2.0
	mesh_node(visual,"Flame",lathe("lamp_flame",[Vector2(0,0),Vector2(.008,.009),Vector2(.013,.024),Vector2(.01,.043),Vector2(.004,.065),Vector2(0,.083)],fire),Vector3(0,.072,.18))
	marker(visual,"WickContact",Vector3(0,.073,.18))
	marker(visual,"LeftGrip",Vector3(-.105,.04,0))
	marker(visual,"RightGrip",Vector3(.105,.04,0))
	packed(visual,"res://objects/household/oil_lamp_visual.tscn")

func build() -> void:
	pot()
	pouch()
	lamp()
	print("WATER/LIGHT BATCH: pot, pouch, lamp and future contact markers built")
	quit()
