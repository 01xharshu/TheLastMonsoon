extends "res://tools/assets/build_paper_supply_batch.gd"
func instance_prop(parent: Node3D, path: String, label: String, at: Vector3) -> Node3D:
	var prop: Node3D = load(path).instantiate()
	prop.name = label
	prop.position = at
	parent.add_child(prop)
	return prop
func part(parent: Node3D, label: String, size_: Vector3, at: Vector3, mat_: Material, solid := true) -> void:
	box(parent,label,size_,at,mat_)
	if solid:
		var body := StaticBody3D.new()
		body.name = label+"Body"
		body.position = at
		parent.add_child(body)
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size_
		collider.shape = shape
		body.add_child(collider)
func pack_set(node: Node3D, filename: String) -> void:
	own_set(node,node)
	var packed := PackedScene.new()
	assert(packed.pack(node) == OK)
	assert(ResourceSaver.save(packed,"res://objects/household/sets/"+filename+".tscn") == OK)
	node.free()
func own_set(node: Node, top: Node) -> void:
	for child in node.get_children():
		child.owner = top
		if child.scene_file_path.is_empty(): own_set(child,top)
func build() -> void:
	var wood := material(Color(.24,.13,.065))
	var clay := material(Color(.38,.23,.14))
	var iron := material(Color(.07,.065,.055))
	var desk := Node3D.new()
	desk.name = "RecordsDeskSet"
	part(desk,"TableTop",Vector3(1.35,.065,.72),Vector3(0,.755,0),wood)
	for x in [-.57,.57]:
		for z in [-.26,.26]:
			part(desk,"Leg",Vector3(.075,.7225,.075),Vector3(x,.36125,z),wood)
	part(desk,"BackBrace",Vector3(1.18,.07,.055),Vector3(0,.26,-.26),wood)
	instance_prop(desk,"res://objects/household/supplies/record_folio.tscn","Folio",Vector3(-.18,.7875,0))
	instance_prop(desk,"res://objects/household/supplies/folded_letter.tscn","Letter",Vector3(.35,.7875,.12))
	instance_prop(desk,"res://objects/household/oil_lamp_visual.tscn","Lamp",Vector3(.45,.7875,-.20))
	instance_prop(desk,"res://objects/household/storage/stool.tscn","Stool",Vector3(0,0,.87))
	marker(desk,"StandingApproach",Vector3(.83,0,.70))
	marker(desk,"ReadingTarget",Vector3(-.18,.81,0))
	pack_set(desk,"records_desk")
	var cooking := Node3D.new()
	cooking.name = "CookingCornerSet"
	part(cooking,"ClayBase",Vector3(.64,.09,.55),Vector3(-.4,.045,-.2),clay)
	for x in [-.65,-.15]:
		part(cooking,"HearthCheek",Vector3(.13,.21,.50),Vector3(x,.195,-.2),clay)
	part(cooking,"HearthBack",Vector3(.40,.21,.12),Vector3(-.4,.195,-.39),clay)
	var pan := CylinderMesh.new()
	pan.top_radius = .24
	pan.bottom_radius = .24
	pan.height = .012
	pan.radial_segments = 48
	pan.material = iron
	mesh_node(cooking,"IronGriddle",pan,Vector3(-.4,.308,-.2))
	tube(cooking,"GriddleHandle",Vector3(-.17,.308,-.2),Vector3(.02,.308,-.2),.013,iron)
	instance_prop(cooking,"res://objects/household/water_pot_visual.tscn","WaterPot",Vector3(.65,0,-.36))
	instance_prop(cooking,"res://objects/household/grain_sack.tscn","GrainSack",Vector3(-1.10,0,-.20))
	instance_prop(cooking,"res://objects/household/storage/basket.tscn","Basket",Vector3(.50,0,.47))
	marker(cooking,"CookApproach",Vector3(-.4,0,.62))
	marker(cooking,"GriddleGrip",Vector3(.02,.308,-.2))
	marker(cooking,"CookingSurface",Vector3(-.4,.315,-.2))
	marker(cooking,"PotApproach",Vector3(.65,0,.70))
	pack_set(cooking,"cooking_corner")
	print("ACTIVITY SETS: records desk and cooking corner built")
	quit()
