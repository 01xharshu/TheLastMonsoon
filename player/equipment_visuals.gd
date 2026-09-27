extends Node3D

var bag_rig: Skeleton3D
var bag_bone := -1
var bag_offset := Transform3D.IDENTITY

func _process(_delta: float) -> void:
	if bag_rig == null:
		var character = get_parent().get_node_or_null("CharacterVisual")
		if character == null or character.skeleton == null: return
		bag_rig = character.skeleton
		bag_bone = bag_rig.find_bone("pelvis")
		# Preserve the authored standing placement, then follow the animated waist.
		var standing := bag_rig.global_transform * bag_rig.get_bone_global_rest(bag_bone)
		bag_offset = standing.affine_inverse() * water_bag_visual.global_transform
	water_bag_visual.global_transform = bag_rig.global_transform * bag_rig.get_bone_global_pose(bag_bone) * bag_offset



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
	process_priority = 11

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
