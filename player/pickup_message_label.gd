extends Label

const ItemCatalog = preload("res://interaction/item_catalog.gd")


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
	inventory.collection_message_requested.connect(_show_reward)
	inventory.water_collected.connect(func(amount: float):
		var overlay: Node = get_parent().get_node_or_null("InteractionOverlay")
		if overlay != null: overlay.show_collection("water", amount))


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

	var overlay: Node = get_parent().get_node_or_null("InteractionOverlay")
	if overlay != null:
		overlay.show_collection(item_id, amount)


# =========================================================
# GENERAL MESSAGE
# =========================================================

func _on_message_requested(
	message: String
) -> void:
	_show_reward(message)

func _show_reward(message: String, icon: String = "item") -> void:
	var overlay: Node = get_parent().get_node_or_null("InteractionOverlay")
	if overlay != null:
		overlay.show_rewards([message], [icon])


# =========================================================
# DISPLAY NAMES
# =========================================================

func _get_display_name(
	item_id: String
) -> String:

	return ItemCatalog.display_name(item_id)
