extends Interactable
## A single period supplies chest inside the walled compound.
var opened := false
var lid: Node3D

func _ready() -> void:
	interaction_text = "Open supply chest"
	interaction_icon = "chest"
	hold_duration = 1.1
	interaction_pose = "kneel"
	marker_height = .78
	add_to_group("treasure_chests")
	_build()

func _material(color: Color, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = .88
	return m

func _box(parent: Node3D, label: String, at: Vector3, size: Vector3, material: Material) -> void:
	var visual := MeshInstance3D.new()
	visual.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.position = at
	visual.material_override = material
	parent.add_child(visual)

func _build() -> void:
	var wood := _material(Color(.27,.15,.075))
	var iron := _material(Color(.19,.19,.17),.35)
	var pale := _material(Color(.49,.34,.15))
	_box(self,"ChestBase",Vector3(0,.42,0),Vector3(1.45,.72,.92),wood)
	_box(self,"InsetFront",Vector3(0,.44,-.466),Vector3(1.12,.46,.026),pale)
	for x in [-.62,.62]:
		_box(self,"CornerStrap",Vector3(x,.42,-.478),Vector3(.072,.72,.038),iron)
		_box(self,"EndStrap",Vector3(x,.42,.478),Vector3(.072,.72,.038),iron)
	for y in [.15,.72]:
		_box(self,"IronBand",Vector3(0,y,-.49),Vector3(1.49,.055,.04),iron)
	_box(self,"LockPlate",Vector3(0,.54,-.503),Vector3(.16,.19,.035),iron)
	lid = Node3D.new()
	lid.name = "HingedLid"
	lid.position = Vector3(0,.82,.46)
	add_child(lid)
	_box(lid,"LidBoard",Vector3(0,.055,-.46),Vector3(1.52,.13,1.02),wood)
	for x in [-.61,.61]:
		_box(lid,"LidStrap",Vector3(x,.13,-.46),Vector3(.078,.022,1.04),iron)
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.5,.85,1.0)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = .43
	add_child(collider)

func interaction_available() -> bool:
	return not opened and super.interaction_available()

func interact(actor: CharacterBody3D) -> void:
	if opened or actor.global_position.distance_to(global_position) > 2.8: return
	opened = true
	lid.create_tween().tween_property(lid,"rotation:x",1.15,.42)
	var prizes := {"paper_cartridges":6,"pistol_ball":4,"rupees":26}
	for item in prizes:
		actor.inventory.add_item(item,int(prizes[item]))
	actor.get_node("UI/HUDRoot/InteractionOverlay").show_rewards(["Paper cartridges  +6","Pistol balls  +4","Rupees  +26"])
	actor.inventory.message_requested.emit("Supply chest opened")

func restore_opened() -> void:
	opened = true
	if lid != null: lid.rotation.x = 1.15
