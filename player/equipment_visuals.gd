extends Node3D

var bag_rig: Skeleton3D
var bag_bone := -1
var bag_offset := Transform3D.IDENTITY
var previous_local_velocity := Vector3.ZERO
var bag_sway_x := 0.0
var bag_sway_z := 0.0

func _process(delta: float) -> void:
	if bag_rig == null:
		var character = get_parent().get_node_or_null("CharacterVisual")
		if character == null or character.skeleton == null: return
		bag_rig = character.skeleton
		bag_bone = bag_rig.find_bone("pelvis")
		if bag_bone < 0: return
		# Preserve the authored standing placement, then follow the animated waist.
		var standing := bag_rig.global_transform * bag_rig.get_bone_global_rest(bag_bone)
		bag_offset = standing.affine_inverse() * water_bag_visual.global_transform
	water_bag_visual.global_transform = bag_rig.global_transform * bag_rig.get_bone_global_pose(bag_bone) * bag_offset
	var actor: CharacterBody3D = get_parent().get_parent()
	var local_velocity: Vector3 = actor.global_basis.inverse() * actor.velocity
	var local_acceleration := (local_velocity - previous_local_velocity) / maxf(delta, 0.001)
	previous_local_velocity = local_velocity
	var motion := clampf(Vector2(local_velocity.x, local_velocity.z).length() / 4.0, 0.0, 1.0)
	var character: Node = get_parent().get_node("CharacterVisual")
	var target_x := clampf(-local_acceleration.z * 0.016, -0.22, 0.22) + sin(character.phase) * 0.09 * motion
	var target_z := clampf(-local_acceleration.x * 0.016, -0.22, 0.22) + cos(character.phase) * 0.06 * motion
	var response := 1.0 - exp(-7.0 * delta)
	bag_sway_x = lerpf(bag_sway_x, target_x, response)
	bag_sway_z = lerpf(bag_sway_z, target_z, response)
	water_bag_visual.rotation.x += bag_sway_x
	water_bag_visual.rotation.z += bag_sway_z



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
