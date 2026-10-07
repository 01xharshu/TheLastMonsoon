extends Interactable
## World fruit is collected here; eating happens from the Satchel.
signal harvested(forage_id: String)
@export var forage_id := ""
var collected := false

func _ready() -> void:
	interaction_text = "Pick up mango"
	interaction_icon = "mango"
	secondary_interaction_text = ""
	hold_duration = .65
	interaction_pose = "low_reach"
	interaction_max_distance = 1.1
	marker_height = .1
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.14
	shape.shape = sphere
	add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.13
	visual.mesh = mesh
	visual.position.y = -0.07
	visual.name = "FruitVisual"
	visual.rotation.z = 0.4
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.93, 0.53, 0.07)
	material.roughness = 0.75
	visual.material_override = material
	add_child(visual)

func interact(player: CharacterBody3D) -> void:
	if collected: return
	if player.inventory.add_item("mango", 1):
		player.get_node("InteractionPoseComponent").complete_mango(false)
		_finish_collection()

func secondary_interact(_player: CharacterBody3D) -> void:
	# Kept for older callers; world fruit can only be eaten after collection.
	pass

func _finish_collection() -> void:
	collected = true
	harvested.emit(forage_id)
	queue_free()

func pickup_point() -> Vector3:
	# The palm meets the upper skin of the grounded, hand-sized fruit.
	return to_global(Vector3(0, -0.015, 0))
