extends Interactable


# =========================================================
# WATER SOURCE SETTINGS
# =========================================================

@export_category("Water Source")


@export var water_available_per_fill: float = 10.0


# =========================================================
# STARTUP
# =========================================================

func _ready() -> void:
	interaction_icon = "water"
	interaction_text = "Fill Water Bag"
	secondary_interaction_text = ""

func interact(player: CharacterBody3D) -> void:
	_fill_water_bag(player)

func secondary_interact(_player: CharacterBody3D) -> void:
	# Direct drinking and secondary filling are retired; use the Satchel to drink.
	pass

func _fill_water_bag(player: CharacterBody3D) -> void:

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
