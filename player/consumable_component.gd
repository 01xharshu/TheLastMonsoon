class_name ConsumableComponent
extends Node
signal mango_eaten
signal item_used(kind: String)


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
	if not _can_use_item(): return false

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


	item_used.emit("roti")
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
	if not _can_use_item(): return false

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


	item_used.emit("water")
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
	mango_eaten.emit()
	inventory.request_message("Ate mango")
	return true

func eat_mango() -> bool:
	if not _can_use_item(): return false
	if not inventory.has_item("mango"):
		inventory.request_message("No mangoes in Satchel")
		return false
	if survival.satiety >= survival.max_satiety and survival.hydration >= survival.max_hydration:
		inventory.request_message("You are not hungry or thirsty")
		return false
	if not inventory.remove_item("mango", 1): return false
	return eat_fresh_mango()

# Gameplay prototype; visible dressing/hand-contact animation remains a final-pass task.
@export var bandage_health_restore: float = 25.0

func use_bandage() -> bool:
	if not _can_use_item(): return false
	var actor: CharacterBody3D = get_parent()
	if actor.health <= 0.0:
		inventory.request_message("Cannot bandage while incapacitated")
		return false
	if actor.health >= actor.MAX_HEALTH:
		inventory.request_message("No wounds to bandage")
		return false
	var item := "medkit" if inventory.has_item("medkit") else "bandage"
	if not inventory.has_item(item):
		inventory.request_message("No bandages in Satchel")
		return false
	var restored: float = minf(bandage_health_restore, actor.MAX_HEALTH - actor.health)
	if restored <= 0.0 or not inventory.remove_item(item,1):
		return false
	actor.health += restored
	item_used.emit("bandage")
	inventory.collection_message_requested.emit("Bandaged wound  ·  +%d health" % int(restored), "medicine")
	return true

func _can_use_item() -> bool:
	var actor: CharacterBody3D = get_parent()
	if actor.get_meta("item_use", "") != "" or actor.get_meta("climbing", false) or actor.get_meta("rest_action", "") != "" or actor.get_meta("river_action", "") != "" or (actor.has_meta("mounted_vehicle") and actor.get_meta("mounted_vehicle") != null) or actor.is_swimming:
		return false
	var pose: Node = actor.get_node_or_null("InteractionPoseComponent")
	if pose != null and not pose.carried_action.is_empty(): return false
	for name in ["RifleCombat", "PistolCombat", "DoubleGunCombat"]:
		var firearm: Node = actor.get_node_or_null(name)
		if firearm != null and firearm.reload_remaining > 0.0: return false
	return true

func _ready() -> void:
	var animation := Node.new()
	animation.name = "ItemUseAnimation"
	animation.set_script(load("res://player/item_use_animation.gd"))
	add_child(animation)
