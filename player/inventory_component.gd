class_name InventoryComponent
extends Node


# =========================================================
# SIGNALS
# =========================================================

signal item_added(
	item_id: String,
	amount: int,
	new_total: int
)


signal item_removed(
	item_id: String,
	amount: int,
	new_total: int
)


signal inventory_changed


# Water amount changed.
signal water_changed(
	current_liters: float,
	maximum_liters: float
)


# Temporary messages shown by our HUD notification.
signal message_requested(
	message: String
)


# =========================================================
# WATER BAG SETTINGS
# =========================================================

@export_category("Water Bag")


# For the prototype, one Water Bag carries 2 litres.
#
# Later different containers can have different capacities.
@export var water_bag_capacity_liters: float = 2.0


# =========================================================
# INVENTORY DATA
# =========================================================

var items: Dictionary = {}


# Total water currently carried inside Water Bags.
var stored_water_liters: float = 0.0


# =========================================================
# ADD ITEM
# =========================================================

func add_item(
	item_id: String,
	amount: int = 1
) -> bool:

	if item_id.is_empty():
		return false


	if amount <= 0:
		return false


	if not items.has(
		item_id
	):

		items[item_id] = 0


	items[item_id] += amount


	var new_total: int = int(
		items[item_id]
	)


	item_added.emit(
		item_id,
		amount,
		new_total
	)


	inventory_changed.emit()


	# Adding another Water Bag changes the total
	# available water capacity.

	if item_id == "water_bag":

		_emit_water_changed()


	print(
		"Inventory added: ",
		item_id,
		" x",
		amount,
		" | Total: ",
		new_total
	)


	return true


# =========================================================
# REMOVE ITEM
# =========================================================

func remove_item(
	item_id: String,
	amount: int = 1
) -> bool:

	if amount <= 0:
		return false


	if not items.has(
		item_id
	):

		return false


	var current_amount: int = int(
		items[item_id]
	)


	if current_amount < amount:
		return false


	current_amount -= amount


	if current_amount <= 0:

		items.erase(
			item_id
		)

		current_amount = 0


	else:

		items[item_id] = current_amount


	# If Water Bags are removed, make sure stored water
	# can never exceed the remaining capacity.

	if item_id == "water_bag":

		stored_water_liters = minf(
			stored_water_liters,
			get_total_water_capacity_liters()
		)

		_emit_water_changed()


	item_removed.emit(
		item_id,
		amount,
		current_amount
	)


	inventory_changed.emit()


	return true


# =========================================================
# ITEM CHECKING
# =========================================================

func has_item(
	item_id: String,
	amount: int = 1
) -> bool:

	return (
		get_item_count(
			item_id
		)
		>= amount
	)


func get_item_count(
	item_id: String
) -> int:

	if not items.has(
		item_id
	):

		return 0


	return int(
		items[item_id]
	)


# =========================================================
# WATER BAG
# =========================================================

func has_water_bag() -> bool:

	return (
		get_item_count(
			"water_bag"
		)
		> 0
	)


func get_total_water_capacity_liters() -> float:

	var bag_count: int = (
		get_item_count(
			"water_bag"
		)
	)


	return (
		float(bag_count)
		* water_bag_capacity_liters
	)


func get_stored_water_liters() -> float:

	return stored_water_liters


func get_available_water_capacity_liters() -> float:

	return maxf(
		0.0,
		get_total_water_capacity_liters()
		- stored_water_liters
	)


# =========================================================
# FILL WATER
# =========================================================

func add_water(
	amount_liters: float
) -> float:

	if amount_liters <= 0.0:
		return 0.0


	if not has_water_bag():
		return 0.0


	var available_capacity := (
		get_available_water_capacity_liters()
	)


	if available_capacity <= 0.0:
		return 0.0


	var amount_added := minf(
		amount_liters,
		available_capacity
	)


	stored_water_liters += (
		amount_added
	)


	_emit_water_changed()


	return amount_added


# =========================================================
# REMOVE / DRINK WATER
# =========================================================

func consume_water(
	amount_liters: float
) -> float:

	if amount_liters <= 0.0:
		return 0.0


	if stored_water_liters <= 0.0:
		return 0.0


	var amount_consumed := minf(
		amount_liters,
		stored_water_liters
	)


	stored_water_liters -= (
		amount_consumed
	)


	stored_water_liters = maxf(
		0.0,
		stored_water_liters
	)


	_emit_water_changed()


	return amount_consumed


# =========================================================
# TEMPORARY HUD MESSAGE
# =========================================================

func request_message(
	message: String
) -> void:

	if message.is_empty():
		return


	message_requested.emit(
		message
	)


# =========================================================
# WATER SIGNAL
# =========================================================

func _emit_water_changed() -> void:

	water_changed.emit(
		stored_water_liters,
		get_total_water_capacity_liters()
	)


# =========================================================
# DEBUG
# =========================================================

func print_inventory() -> void:

	print(
		"----- INVENTORY -----"
	)


	if items.is_empty():

		print(
			"Empty"
		)


	else:

		for item_id in items:

			print(
				item_id,
				" x",
				items[item_id]
			)


	print(
		"Water: ",
		stored_water_liters,
		" / ",
		get_total_water_capacity_liters(),
		" L"
	)
