extends Node3D
## Standalone bow draw study; carry, aiming and release belong to later gameplay work.
const BOW = preload("res://environment/weapons/period_bow/period_bow.glb")
const ARROW = preload("res://environment/weapons/period_arrow/period_arrow.glb")
var draw_fraction := 0.0
var model: Node3D
var arrow: Node3D
var upper_string: MeshInstance3D
var lower_string: MeshInstance3D

func _ready() -> void:
	model = BOW.instantiate()
	add_child(model)
	var resting_cord := model.find_child("Taut natural cord", true, false)
	if resting_cord: resting_cord.hide()
	var cord_material := StandardMaterial3D.new()
	cord_material.albedo_color = Color(0.65,0.55,0.38)
	cord_material.roughness = 0.92
	upper_string = _segment(cord_material)
	lower_string = _segment(cord_material)
	arrow = ARROW.instantiate()
	add_child(arrow)
	arrow.rotation.z = -PI/2
	set_draw_fraction(0.0)

func _segment(material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = 0.0018
	shape.bottom_radius = 0.0018
	shape.height = 1.0
	shape.radial_segments = 8
	node.mesh = shape
	node.material_override = material
	add_child(node)
	return node

func set_draw_fraction(value: float) -> void:
	draw_fraction = clampf(value,0.0,1.0)
	if not is_instance_valid(upper_string): return
	var nock := Vector3(-0.12 - 0.30*draw_fraction,0,0)
	_place_segment(lower_string, Vector3(-0.12,-0.65,0), nock)
	_place_segment(upper_string, nock, Vector3(-0.12,0.65,0))
	arrow.position = nock
	arrow.visible = draw_fraction > 0.02

func _place_segment(segment: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var span := to-from
	segment.transform = Transform3D(Basis(Quaternion(Vector3.UP,span.normalized())).scaled(Vector3(1,span.length(),1)),(from+to)*0.5)
