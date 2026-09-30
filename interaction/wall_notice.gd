extends Interactable
## Reading temporarily removes a posted sheet; closing presses it back.
@export var headline := "DISTRICT NOTICE"
@export_multiline var message := "Travellers are asked to report road obstructions at the district office."
var paper: MeshInstance3D
var reading := false
func _ready() -> void:
	interaction_text = "Take down and read notice"
	marker_height = .30
	interaction_max_distance = 1.25
	add_to_group("wall_notices")
	paper = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(.38,.50,.006)
	paper.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(.79,.71,.53)
	mat.roughness = .95
	paper.material_override = mat
	add_child(paper)
	var text := Label3D.new()
	text.text = headline + "\n────────\nDISTRICT OFFICE\n\nPUBLIC INFORMATION"
	text.font = preload("res://assets/ui/fonts/MFBOldstyle-Regular.otf")
	text.font_size = 28
	text.pixel_size = .0008
	text.modulate = Color(.20,.14,.08)
	text.outline_size = 0
	text.position.z = .005
	paper.add_child(text)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(.40,.52,.035)
	collider.shape = shape
	add_child(collider)

func interaction_available() -> bool:
	return not reading and super.interaction_available()

func interact(actor: CharacterBody3D) -> void:
	var scroll: Control = actor.get_node("UI/IdentityScroll")
	if not interaction_available() or not scroll.can_open(): return
	if actor.global_position.distance_to(global_position) > 1.5: return
	reading = true
	scroll.open_notice(self)
