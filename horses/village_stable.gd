extends Node3D
## Timber and plaster village shelter with an open stall and a single tethered horse.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const Horse = preload("res://horses/stable_horse.gd")
var layout := Layout.new()

func _ready() -> void:
	position = Vector3(-260,layout.height(-260,194),194)
	var timber := _material(Color(.24,.13,.07))
	var earth := _material(Color(.52,.38,.24))
	var thatch := _material(Color(.51,.39,.20))
	var stone := _material(Color(.41,.39,.32))
	var water := _material(Color(.16,.23,.20))
	var hay := _material(Color(.64,.51,.27))
	_piece("Floor",Vector3(0,.08,0),Vector3(8,.16,8),earth)
	for x in [-3.8,3.8]:
		for z in [-3.8,3.8]:
			_piece("TimberPost",Vector3(x,1.55,z),Vector3(.23,3.1,.23),timber)
	_piece("BackWall",Vector3(0,1.0,-3.85),Vector3(8,2,.27),earth)
	for x in [-3.8,3.8]:
		_piece("SideWall",Vector3(x,1.0,0),Vector3(.27,2,8),earth)
	for x in [-2.6,2.6]:
		_piece("FrontRail",Vector3(x,1.08,3.8),Vector3(2.4,.12,.16),timber)
	for z in [-3.8,3.8]:
		_piece("CrossBeam",Vector3(0,3.08,z),Vector3(8.0,.19,.22),timber)
	for x in [-3.8,0.0,3.8]:
		_piece("Rafter",Vector3(x,3.46,0),Vector3(.14,.16,8.5),timber)
	_piece("RoofWest",Vector3(-2.08,3.56,0),Vector3(4.8,.28,9.0),thatch).rotation.z = .28
	_piece("RoofEast",Vector3(2.08,3.56,0),Vector3(4.8,.28,9.0),thatch).rotation.z = -.28
	_piece("RoofRidge",Vector3(0,4.18,0),Vector3(.32,.25,9.1),timber)
	_trough("Feed",Vector3(-2.1,0,-2.8),Vector2(2.3,.75),timber,hay)
	_trough("Water",Vector3(2.3,0,-2.8),Vector2(1.5,.85),stone,water)
	for i in 15:
		var z: float = -3.9 + float(i)*.55
		var shade: Material = _material(Color(.50+float(i%3)*.025,.38+float(i%2)*.025,.19))
		for side in [-1.0,1.0]:
			var x: float = side*(.38+float(i%2)*.02)
			_piece("ThatchCourse",Vector3(x*5.35,3.85-absf(x)*.82,z),Vector3(3.9,.035,.07),shade).rotation.z = -.28 if side>0 else .28
	var horse := Horse.new()
	horse.name = "VillageHorse"
	_place_horse.call_deferred(horse)

func _place_horse(horse: CharacterBody3D) -> void:
	get_parent().add_child(horse)
	horse.global_position = Vector3(global_position.x,layout.height(global_position.x,global_position.z+1.0)+.15,global_position.z+1.0)
	horse.rotation.y = PI

func _material(color: Color) -> Material:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	return m

func _trough(label: String, at: Vector3, footprint: Vector2, frame: Material, contents: Material) -> void:
	_piece(label+"Base",at+Vector3(0,.24,0),Vector3(footprint.x,.20,footprint.y),frame)
	_piece(label+"Contents",at+Vector3(0,.35,0),Vector3(footprint.x-.20,.025,footprint.y-.20),contents)
	for side in [-1.0,1.0]:
		_piece(label+"LongRim",at+Vector3(0,.43,side*footprint.y*.5),Vector3(footprint.x,.25,.10),frame)
		_piece(label+"EndRim",at+Vector3(side*footprint.x*.5,.43,0),Vector3(.10,.25,footprint.y),frame)

func _piece(label: String, at: Vector3, size: Vector3, mat: Material) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.position = at
	add_child(node)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	node.add_child(mesh)
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	node.add_child(body)
	return node
