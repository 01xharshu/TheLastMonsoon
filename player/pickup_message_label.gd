extends Label


# =========================================================
# INVENTORY REFERENCE
# =========================================================

@onready var inventory: InventoryComponent = (
	$"../../../InventoryComponent"
)


# =========================================================
# STARTUP
# =========================================================

func _ready() -> void:

	mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


	visible = false


	inventory.item_added.connect(
		_on_item_added
	)


	inventory.message_requested.connect(
		_on_message_requested
	)


# =========================================================
# ITEM PICKUP
# =========================================================

func _on_item_added(
	item_id: String,
	amount: int,
	_new_total: int
) -> void:

	var display_name := (
		_get_display_name(
			item_id
		)
	)


	_show_reward(display_name + "  +" + str(amount))


# =========================================================
# GENERAL MESSAGE
# =========================================================

func _on_message_requested(
	message: String
) -> void:
	_show_reward(message)

func _show_reward(message: String) -> void:
	var overlay: Node = get_parent().get_node_or_null("InteractionOverlay")
	if overlay != null:
		overlay.show_rewards([message])


# =========================================================
# DISPLAY NAMES
# =========================================================

func _get_display_name(
	item_id: String
) -> String:

	match item_id:
		"paper_cartridges":
			return "Paper Cartridges"
		"pistol_ball":
			return "Pistol Balls"

		"roti":
			return "Roti"

		"water_bag":
			return "Water Bag"

		_:
			return item_id.capitalize()
