extends Interactable
## One fruit, consumed once: E stores it, Shift+E eats it on the spot.
var collected := false

func _ready() -> void:
	interaction_text = "Pick up mango"
	secondary_interaction_text = "Eat mango"
	hold_duration = .65
	interaction_pose = "low_reach"
	marker_height = .1
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.14
	shape.shape = sphere
	add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.10
	mesh.height = 0.27
	visual.mesh = mesh
	visual.rotation.z = 0.4
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.93, 0.53, 0.07)
	material.roughness = 0.75
	visual.material_override = material
	add_child(visual)

func interact(player: CharacterBody3D) -> void:
	if collected: return
	if player.inventory.add_item("mango", 1):
		collected = true
		player.inventory.request_message("Picked up mango · eat it from the Satchel")
		queue_free()

func secondary_interact(player: CharacterBody3D) -> void:
	if collected: return
	if player.consumables.eat_fresh_mango():
		collected = true
		queue_free()
