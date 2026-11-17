extends Interactable
## Delivered household cloth is sold from the merchant's workplace counter.
const PRICE := 4
var service: Node
var display: MeshInstance3D
var refresh_elapsed := 0.0

func _ready() -> void:
	interaction_text = "Buy cotton bundle · 4 rupees"
	interaction_max_distance = 2.6
	marker_height = .2
	collision_layer = 1 << 29
	collision_mask = 0
	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = .18
	collider.shape = shape
	add_child(collider)
	display = MeshInstance3D.new()
	display.name = "CottonBundle"
	var mesh := CylinderMesh.new()
	mesh.top_radius = .12
	mesh.bottom_radius = .12
	mesh.height = .58
	display.mesh = mesh
	display.rotation.z = PI * .5
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(.55,.43,.28)
	cloth.roughness = .95
	display.material_override = cloth
	add_child(display)
	_refresh_display()

func _process(delta: float) -> void:
	refresh_elapsed += delta
	if refresh_elapsed < .5: return
	refresh_elapsed = 0.0
	_refresh_display()

func _refresh_display() -> void:
	if not is_instance_valid(service) or not is_instance_valid(display): return
	var record: Dictionary = service.ledger._record(service.role_id)
	display.visible = int(record.get("cloth_delivered",0)) > int(record.get("cloth_sold",0))

func interaction_available() -> bool:
	return super.interaction_available() and is_instance_valid(service) and service.interaction_available() and service.person.get_meta("household_action", "") == "work"

func interact(actor: CharacterBody3D) -> void:
	if actor != service.ledger.player or not interaction_available() or actor.global_position.distance_to(global_position) > interaction_max_distance:
		return
	var ledger: Node = service.ledger
	if not ledger._business_open(service):
		ledger.message("The merchant sells cloth from 9 in the morning to 5 in the afternoon.")
		return
	var record: Dictionary = ledger._record(service.role_id)
	var remaining := maxi(0, int(record.get("cloth_delivered", 0)) - int(record.get("cloth_sold", 0)))
	if remaining == 0:
		ledger.message("The household has no cloth bundles for sale today.")
		return
	var inventory: InventoryComponent = actor.get_node("InventoryComponent")
	if not inventory.remove_item("rupees", PRICE):
		ledger.message("A cotton bundle costs 4 rupees.")
		return
	if not inventory.add_item("salvaged_cloth", 1):
		inventory.add_item("rupees", PRICE)
		return
	record["cloth_sold"] = int(record.get("cloth_sold", 0)) + 1
	_refresh_display()
	ledger.message("Bought one cotton bundle · 4 rupees.")
