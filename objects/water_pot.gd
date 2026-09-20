extends Interactable


# =========================================================
# WATER SOURCE SETTINGS
# =========================================================

@export_category("Water Source")


@export var direct_drink_hydration: float = 20.0


@export var water_available_per_fill: float = 10.0


# =========================================================
# STARTUP
# =========================================================

func _ready() -> void:

	# E
	interaction_text = (
		"Drink Water"
	)


	# F
	secondary_interaction_text = (
		"Fill Water Bag"
	)


# =========================================================
# E — DRINK DIRECTLY
# =========================================================

func interact(
	player: CharacterBody3D
) -> void:

	var survival := (
		player.get_node_or_null(
			"SurvivalComponent"
		) as SurvivalComponent
	)


	var inventory := (
		player.get_node_or_null(
			"InventoryComponent"
		) as InventoryComponent
	)


	if survival == null:

		push_warning(
			"Water source could not find "
			+ "SurvivalComponent."
		)

		return


	if (
		survival.hydration
		>= survival.max_hydration
	):

		if inventory != null:

			inventory.request_message(
				"You are not thirsty"
			)

		return


	var restored_amount := (
		survival.restore_hydration(
			direct_drink_hydration
		)
	)


	if inventory != null:

		inventory.request_message(
			"Drank directly from water source"
		)


	print(
		"Arjun drank directly from the source. "
		+ "Hydration restored: ",
		restored_amount
	)


# =========================================================
# F — FILL WATER BAG
# =========================================================

func secondary_interact(
	player: CharacterBody3D
) -> void:

	var inventory := (
		player.get_node_or_null(
			"InventoryComponent"
		) as InventoryComponent
	)


	if inventory == null:

		push_warning(
			"Water source could not find "
			+ "InventoryComponent."
		)

		return


	if not inventory.has_water_bag():

		inventory.request_message(
			"You need a Water Bag"
		)

		return


	var available_capacity := (
		inventory
		.get_available_water_capacity_liters()
	)


	if available_capacity <= 0.0:

		inventory.request_message(
			"Water Bag is already full"
		)

		return


	var amount_added := (
		inventory.add_water(
			minf(
				water_available_per_fill,
				available_capacity
			)
		)
	)


	if amount_added <= 0.0:
		return


	var current_water := (
		inventory.get_stored_water_liters()
	)


	var maximum_water := (
		inventory
		.get_total_water_capacity_liters()
	)


	inventory.request_message(
		"Water Bag filled • "
		+ "%.1f / %.1f L"
		% [
			current_water,
			maximum_water
		]
	)


	print(
		"Water Bag filled by ",
		amount_added,
		" L."
	)
