extends Label


# =========================================================
# INVENTORY REFERENCE
# =========================================================

@onready var inventory: InventoryComponent = (
	$"../../../InventoryComponent"
)


# =========================================================
# DISPLAY SETTINGS
# =========================================================

@export var display_duration: float = 1.8


var display_timer: float = 0.0


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
# UPDATE
# =========================================================

func _process(
	delta: float
) -> void:

	if not visible:
		return


	display_timer -= delta


	if display_timer <= 0.0:

		visible = false


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


	if amount <= 1:

		_show_message(
			display_name
			+ " collected"
		)


	else:

		_show_message(
			display_name
			+ " x"
			+ str(amount)
			+ " collected"
		)


# =========================================================
# GENERAL MESSAGE
# =========================================================

func _on_message_requested(
	message: String
) -> void:

	_show_message(
		message
	)


# =========================================================
# SHOW MESSAGE
# =========================================================

func _show_message(
	message: String
) -> void:

	text = message


	display_timer = (
		display_duration
	)


	visible = true


# =========================================================
# DISPLAY NAMES
# =========================================================

func _get_display_name(
	item_id: String
) -> String:

	match item_id:

		"roti":
			return "Roti"

		"water_bag":
			return "Water Bag"

		_:
			return item_id.capitalize()
