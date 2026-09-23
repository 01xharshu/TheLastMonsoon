class_name ConsumableComponent
extends Node


# =========================================================
# FOOD SETTINGS
# =========================================================

@export_category("Food")


# One Roti currently restores this much Satiety.
#
# Prototype value.
# We can rebalance all food later.

@export var roti_satiety_restore: float = 25.0


# =========================================================
# WATER SETTINGS
# =========================================================

@export_category("Water")


# One normal drink from the carried Water Bag.

@export var water_per_drink_liters: float = 0.25


# Hydration restored by that normal drink.

@export var hydration_per_drink: float = 20.0


# =========================================================
# REFERENCES
# =========================================================

@onready var survival: SurvivalComponent = (
	$"../SurvivalComponent"
)


@onready var inventory: InventoryComponent = (
	$"../InventoryComponent"
)


# =========================================================
# EAT ROTI
# =========================================================

func eat_roti() -> bool:

	# -----------------------------------------------------
	# NONE AVAILABLE
	# -----------------------------------------------------

	if not inventory.has_item(
		"roti"
	):

		inventory.request_message(
			"No Roti in Satchel"
		)

		return false


	# -----------------------------------------------------
	# ALREADY FULL
	# -----------------------------------------------------

	if (
		survival.satiety
		>= survival.max_satiety
	):

		inventory.request_message(
			"You are not hungry"
		)

		return false


	# -----------------------------------------------------
	# REMOVE ONE ROTI
	# -----------------------------------------------------

	var removed := (
		inventory.remove_item(
			"roti",
			1
		)
	)


	if not removed:
		return false


	# -----------------------------------------------------
	# RESTORE SATIETY
	# -----------------------------------------------------

	var restored_amount := (
		survival.restore_satiety(
			roti_satiety_restore
		)
	)


	inventory.request_message(
		"Ate Roti"
	)


	print(
		"Arjun ate Roti. "
		+ "Satiety restored: ",
		roundi(
			restored_amount
		)
	)


	return true


# =========================================================
# DRINK FROM CARRIED WATER BAG
# =========================================================

func drink_from_water_bag() -> bool:

	# -----------------------------------------------------
	# NO BAG
	# -----------------------------------------------------

	if not inventory.has_water_bag():

		inventory.request_message(
			"You are not carrying a Water Bag"
		)

		return false


	# -----------------------------------------------------
	# ALREADY FULLY HYDRATED
	# -----------------------------------------------------

	if (
		survival.hydration
		>= survival.max_hydration
	):

		inventory.request_message(
			"You are not thirsty"
		)

		return false


	# -----------------------------------------------------
	# EMPTY BAG
	# -----------------------------------------------------

	if (
		inventory.get_stored_water_liters()
		<= 0.0
	):

		inventory.request_message(
			"Water Bag is empty"
		)

		return false


	# -----------------------------------------------------
	# CONSUME WATER
	# -----------------------------------------------------

	var consumed_water := (
		inventory.consume_water(
			water_per_drink_liters
		)
	)


	if consumed_water <= 0.0:
		return false


	# -----------------------------------------------------
	# RESTORE HYDRATION
	# -----------------------------------------------------

	var drink_fraction := (
		consumed_water
		/ water_per_drink_liters
	)


	var hydration_amount := (
		hydration_per_drink
		* drink_fraction
	)


	var restored_hydration := (
		survival.restore_hydration(
			hydration_amount
		)
	)


	var remaining_water := (
		inventory.get_stored_water_liters()
	)


	inventory.request_message(
		"Drank Water • "
		+ "%.2f L left"
		% remaining_water
	)


	print(
		"Water consumed: ",
		consumed_water,
		" L | Hydration restored: ",
		restored_hydration
	)


	return true

func eat_fresh_mango() -> bool:
	if survival.satiety >= survival.max_satiety and survival.hydration >= survival.max_hydration:
		inventory.request_message("You are not hungry or thirsty")
		return false
	survival.restore_satiety(12.0)
	survival.restore_hydration(6.0)
	inventory.request_message("Ate mango")
	return true

func eat_mango() -> bool:
	if not inventory.has_item("mango"):
		inventory.request_message("No mangoes in Satchel")
		return false
	if survival.satiety >= survival.max_satiety and survival.hydration >= survival.max_hydration:
		inventory.request_message("You are not hungry or thirsty")
		return false
	if not inventory.remove_item("mango", 1): return false
	return eat_fresh_mango()
