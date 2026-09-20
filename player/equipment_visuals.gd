extends Node3D


# =========================================================
# INVENTORY
# =========================================================

@onready var inventory: InventoryComponent = (
	$"../../InventoryComponent"
)


# =========================================================
# CARRIED VISUALS
# =========================================================

@onready var water_bag_visual: Node3D = (
	$WaterBagVisual
)


# =========================================================
# STARTUP
# =========================================================

func _ready() -> void:

	if inventory == null:

		push_error(
			"EquipmentVisuals could not find "
			+ "InventoryComponent."
		)

		return


	# Whenever inventory contents change,
	# check which equipment should appear.

	inventory.inventory_changed.connect(
		_refresh_equipment_visuals
	)


	_refresh_equipment_visuals()


# =========================================================
# REFRESH
# =========================================================

func _refresh_equipment_visuals() -> void:

	# Water Bag should only be visible after Arjun
	# actually owns one.

	water_bag_visual.visible = (
		inventory.has_water_bag()
	)
