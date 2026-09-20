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
