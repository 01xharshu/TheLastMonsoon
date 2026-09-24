extends CharacterBody3D
var inventory: InventoryComponent

func _ready() -> void:
	inventory = InventoryComponent.new()
	inventory.name = "InventoryComponent"
	add_child(inventory)
