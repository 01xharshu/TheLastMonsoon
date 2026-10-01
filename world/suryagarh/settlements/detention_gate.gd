extends Interactable
var locked := false
var opened := true
var leaf: Node3D
func _ready() -> void:
	add_to_group("police_cell_gates")
	interaction_text = "Close cell gate"
	interaction_icon = "gate"
	leaf = Node3D.new()
	add_child(leaf)
	leaf.rotation.y = -PI*0.5
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(.13,.13,.11)
	iron.metallic = .65
	iron.roughness = .8
	for x in range(7):
		box(Vector3(-1.56+x*.25,1.35,0),Vector3(.045,2.7,.045),iron)
	for y in [.1,1.3,2.6]: box(Vector3(-.82,y,0),Vector3(1.64,.07,.07),iron)
	var body := StaticBody3D.new()
	leaf.add_child(body)
	var shape := CollisionShape3D.new()
	var collision := BoxShape3D.new()
	collision.size = Vector3(1.64,2.7,.09)
	shape.shape = collision
	shape.position = Vector3(-.82,1.35,0)
	body.add_child(shape)
func box(at: Vector3, size: Vector3, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	var geometry := BoxMesh.new()
	geometry.size = size
	mesh.mesh = geometry
	mesh.material_override = mat
	mesh.position = at
	leaf.add_child(mesh)
func set_locked(value: bool) -> void:
	locked = value
	set_open(not value)
func set_open(value: bool) -> void:
	opened = value
	create_tween().tween_property(leaf,"rotation:y",-PI*.5 if value else 0.0,.65)
	interaction_text = "Open cell gate" if not value else "Close cell gate"
func interact(_actor: CharacterBody3D) -> void:
	if not locked: set_open(not opened)
func interaction_available() -> bool:
	return not locked
