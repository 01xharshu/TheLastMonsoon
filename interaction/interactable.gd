class_name Interactable
extends StaticBody3D


# =========================================================
# PRIMARY INTERACTION
# =========================================================
#
# This is normally activated with E.
#
# Examples:
#
# [E] Pick Up Roti
# [E] Open Door
# [E] Drink Water
# [E] Sleep
# =========================================================

@export var interaction_text: String = "Interact"
@export_enum("hand", "chest", "weapon", "gate", "loot") var interaction_icon := "hand"
@export_range(0.0, 3.0, 0.05) var hold_duration := 0.0
@export_range(0.0, 3.0, 0.05) var marker_height := 0.65
@export_enum("none", "low_reach", "kneel") var interaction_pose := "none"

func interaction_anchor() -> Vector3:
	return global_position + Vector3.UP * marker_height

func interaction_available() -> bool:
	return visible and not is_queued_for_deletion()


# =========================================================
# SECONDARY INTERACTION
# =========================================================
#
# This is normally activated with F.
#
# Most objects don't need it.
#
# Water sources do:
#
# [E] Drink Water
# [F] Fill Water Bag
# =========================================================

@export var secondary_interaction_text: String = ""


# =========================================================
# PRIMARY ACTION
# =========================================================

func interact(
	_player: CharacterBody3D
) -> void:

	print(
		"Primary interaction triggered."
	)


# =========================================================
# SECONDARY ACTION
# =========================================================

func secondary_interact(
	_player: CharacterBody3D
) -> void:

	pass


# =========================================================
# DOES THIS OBJECT HAVE A SECONDARY ACTION?
# =========================================================

func has_secondary_interaction() -> bool:

	return not (
		secondary_interaction_text
		.strip_edges()
		.is_empty()
	)

func _enter_tree() -> void:
	add_to_group("interactables")
