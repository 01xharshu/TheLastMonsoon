extends Interactable


# =========================================================
# WATER SOURCE SETTINGS
# =========================================================

@export_category("Water Source")


@export var water_available_per_fill: float = 10.0
var breakage: StaticBody3D


# =========================================================
# STARTUP
# =========================================================

func _ready() -> void:
	interaction_icon = "water"
	interaction_text = "Fill Water Bag"
	secondary_interaction_text = ""
	# Only the earthen vessel scene is fragile; the village masonry well uses
	# this same water-source script and must retain its normal behaviour.
	var shells := find_children("EarthenShell","MeshInstance3D",true,false)
	if not shells.is_empty():
		var component = preload("res://objects/household/breakable_earthenware.gd").new()
		component.visual_root = self
		component.vessel_size = 1.8
		component.position = to_local(shells[0].global_position)
		breakage = component
		add_child(component)
		component.broken.connect(func(_reason):
			water_available_per_fill = 0.0
			collision_layer = 0
			interaction_text = "Broken water pot")

func take_damage(amount: float) -> void:
	if breakage: breakage.take_damage(amount)

func interact(player: CharacterBody3D) -> void:
	_fill_water_bag(player)

func secondary_interact(_player: CharacterBody3D) -> void:
	# Direct drinking and secondary filling are retired; use the Satchel to drink.
	pass

func _fill_water_bag(player: CharacterBody3D) -> void:
	if water_available_per_fill <= 0:
		return

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


	WorldAudio.play_at("water_fill",global_position)
	var current_water := (
		inventory.get_stored_water_liters()
	)


	var maximum_water := (
		inventory
		.get_total_water_capacity_liters()
	)


	# Successful fill notification comes from InventoryComponent.water_collected.


	print(
		"Water Bag filled by ",
		amount_added,
		" L."
	)
