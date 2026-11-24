extends CharacterBody3D
var inventory: InventoryComponent

func _ready() -> void:
	inventory = InventoryComponent.new()
	inventory.name = "InventoryComponent"
	add_child(inventory)

func nearby_interactables(_marker_range := 0.0) -> Array[Node]:
	return get_tree().get_nodes_in_group("interactables")
