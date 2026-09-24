extends Interactable


# =========================================================
# ITEM INFORMATION
# =========================================================

@export_category("Item")

@export var item_id: String = "roti"

@export var pickup_amount: int = 1


# =========================================================
# STARTUP
# =========================================================

func _ready() -> void:
	hold_duration = .65
	interaction_pose = "low_reach"
	marker_height = .25

	interaction_text = (
		"Pick Up Roti"
	)


# =========================================================
# INTERACTION
# =========================================================

func interact(
	player: CharacterBody3D
) -> void:

	# Find Arjun's InventoryComponent.

	var inventory := (
		player.get_node_or_null(
			"InventoryComponent"
		) as InventoryComponent
	)


	if inventory == null:

		push_warning(
			"Roti could not find "
			+ "InventoryComponent."
		)

		return


	# Add Roti to inventory.

	var successfully_added := (
		inventory.add_item(
			item_id,
			pickup_amount
		)
	)


	if not successfully_added:
		return


	print(
		"Arjun collected Roti."
	)


	# Remove physical Roti from world.

	queue_free()
