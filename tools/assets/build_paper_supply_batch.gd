extends "res://tools/assets/build_household_batch.gd"
## Generic original props; content and gameplay are assigned by their eventual scenes.
const DEST = "res://objects/household/supplies/"
func box(parent: Node3D, label: String, size_: Vector3, at: Vector3, mat_: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size_
	mesh.material = mat_
	return mesh_node(parent,label,mesh,at)

func marker(parent: Node3D, label: String, at: Vector3) -> void:
	var point := Marker3D.new()
	point.name = label
	point.position = at
	parent.add_child(point)

func save_visual(node: Node3D, filename: String) -> void:
	own(node,node)
	var packed := PackedScene.new()
	assert(packed.pack(node) == OK)
	assert(ResourceSaver.save(packed,DEST+filename+".tscn") == OK)
	node.free()

func build() -> void:
	var paper := material(Color(.78,.70,.51))
	var edge := material(Color(.53,.43,.28))
	var cord := material(Color(.30,.22,.12))
	var cover := material(Color(.25,.12,.07))
	var letter := Node3D.new()
	letter.name = "FoldedLetter"
	box(letter,"FoldedPaper",Vector3(.18,.004,.115),Vector3(0,.002,0),paper)
	var flap := box(letter,"OpeningFlap",Vector3(.18,.002,.054),Vector3(0,.005,-.029),paper)
	flap.rotation.x = -.035
	box(letter,"FoldCrease",Vector3(.175,.0006,.0007),Vector3(0,.006,-.003),edge)
	marker(letter,"LeftGrip",Vector3(-.08,.004,0))
	marker(letter,"RightGrip",Vector3(.08,.004,0))
	marker(letter,"FlapGrip",Vector3(0,.006,-.003))
	save_visual(letter,"folded_letter")
	var folio := Node3D.new()
	folio.name = "OpenRecordFolio"
	for side in [-1.0,1.0]:
		box(folio,"Cover",Vector3(.205,.009,.28),Vector3(side*.108,.0045,0),cover)
		box(folio,"PageBlock",Vector3(.196,.012,.267),Vector3(side*.108,.015,0),paper)
		for line in 5:
			box(folio,"PageEdge",Vector3(.197,.0005,.001),Vector3(side*.108,.01+line*.002,.134),edge)
		# Ruled blank record sheet: no invented handwriting or quest text.
		for row in 12:
			box(folio,"Rule",Vector3(.16,.0004,.0012),Vector3(side*.108,.0212,-.105+row*.018),edge)
	box(folio,"Spine",Vector3(.012,.012,.28),Vector3(0,.006,0),cover)
	marker(folio,"LeftGrip",Vector3(-.20,.015,0))
	marker(folio,"RightGrip",Vector3(.20,.015,0))
	marker(folio,"PageTurnGrip",Vector3(.199,.022,.12))
	marker(folio,"ReadingTarget",Vector3(0,.023,0))
	save_visual(folio,"record_folio")
	var parcel := Node3D.new()
	parcel.name = "TiedSupplyParcel"
	box(parcel,"WrappedContents",Vector3(.27,.085,.18),Vector3(0,.0425,0),paper)
	for x in [-.06,.06]:
		for pair in [[Vector3(x,.088,-.092),Vector3(x,.088,.092)],[Vector3(x,0,-.092),Vector3(x,.088,-.092)],[Vector3(x,0,.092),Vector3(x,.088,.092)]]:
			tube(parcel,"Twine",pair[0],pair[1],.0025,cord)
	tube(parcel,"CrossTie",Vector3(-.137,.089,0),Vector3(.137,.089,0),.0025,cord)
	tube(parcel,"KnotTail",Vector3(.06,.092,0),Vector3(.085,.094,.032),.003,cord)
	marker(parcel,"LeftGrip",Vector3(-.137,.043,0))
	marker(parcel,"RightGrip",Vector3(.137,.043,0))
	marker(parcel,"TieGrip",Vector3(.06,.094,0))
	save_visual(parcel,"supply_parcel")
	# Capture the existing medical supply visual, without its reward script or collider.
	var fixture := Node3D.new()
	root.add_child(fixture)
	var pickup: Node3D = load("res://world/suryagarh/settlements/medical_supply.gd").new()
	fixture.add_child(pickup)
	var bandage := Node3D.new()
	bandage.name = "BandageRoll"
	for child in pickup.get_children():
		if child is MeshInstance3D:
			pickup.remove_child(child)
			bandage.add_child(child)
			child.position.y += .002
	marker(bandage,"LeftGrip",Vector3(-.06,.055,0))
	marker(bandage,"RightGrip",Vector3(.06,.055,0))
	marker(bandage,"LooseStripGrip",Vector3(.12,.005,.13))
	save_visual(bandage,"bandage_roll")
	fixture.free()
	print("PAPER/SUPPLY: four visual prefabs built; no new gameplay")
	quit()
