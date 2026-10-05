extends Node3D
## Original timber prop; the sheet is a playable document, separate from building labels.
var notice: Interactable

func _ready() -> void:
	name = "MarketNoticeBoard"
	add_to_group("public_notice_boards")
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(.25,.15,.075)
	wood.roughness = .92
	for x in [-.53,.53]:
		_box("Post",Vector3(x,.95,0),Vector3(.11,1.9,.12),wood)
	for row in 4:
		_box("BoardSlat",Vector3(0,1.21+row*.16,.015),Vector3(1.20,.154,.065),wood)
	_box("TopCap",Vector3(0,1.84,.015),Vector3(1.28,.07,.10),wood)
	notice = preload("res://interaction/wall_notice.gd").new()
	notice.name = "MarketNews"
	notice.headline = "MARKET NEWS"
	notice.message = "Grain sellers and travellers: keep the market lane and water steps clear. Enquiries are received at the market."
	notice.position = Vector3(0,1.46,.057)
	add_child(notice)

func _box(label: String, at: Vector3, dimensions: Vector3, material: Material) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	add_child(body)
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	body.add_child(visual)
	var shape := BoxShape3D.new()
	shape.size = dimensions
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
