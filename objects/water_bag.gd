extends Interactable


# =========================================================
# ITEM INFORMATION
# =========================================================

@export_category("Item")

@export var item_id: String = "water_bag"

@export var pickup_amount: int = 1


# =========================================================
# STARTUP
# =========================================================

func _ready() -> void:
	interaction_icon = "water"
	hold_duration = .65
	interaction_pose = "low_reach"
	marker_height = .3

	interaction_text = (
		"Pick Up Water Bag"
	)


	# Water Bag itself has no F action.

	secondary_interaction_text = ""


# =========================================================
# PICK UP
# =========================================================

func interact(
	player: CharacterBody3D
) -> void:

	if is_queued_for_deletion(): return

	var inventory := (
		player.get_node_or_null(
			"InventoryComponent"
		) as InventoryComponent
	)


	if inventory == null:

		push_warning(
			"WaterBag could not find "
			+ "InventoryComponent."
		)

		return


	var added := (
		inventory.add_item(
			item_id,
			pickup_amount
		)
	)


	if not added:
		return


	print(
		"Arjun collected a Water Bag."
	)


	# Remove world version.
	#
	# The carried visual will appear on Arjun separately.

	queue_free()
