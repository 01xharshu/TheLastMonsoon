class_name Interactable
extends StaticBody3D


# =========================================================
# PRIMARY INTERACTION
# =========================================================
#
# Main interaction normally used with E.
#
# Examples:
#
# E -> Pick up
# E -> Open chest
# E -> Drink
# E -> Use
# =========================================================

@export var interaction_text: String = "Interact"


# This tells the UI what visual symbol this object should use.
#
# Existing types remain supported:
# hand
# chest
# weapon
# gate
# loot
#
# New types added:
# ammo
# medicine
# food
# water
# horse
# vehicle
#
@export_enum(
	"hand",
	"chest",
	"weapon",
	"gate",
	"loot",
	"ammo",
	"medicine",
	"food",
	"water",
	"horse",
	"vehicle"
)
var interaction_icon: String = "hand"


# If this is 0, pressing E performs the action immediately.
#
# If greater than 0, the player must HOLD the interaction
# button for this many seconds.
#
@export_range(0.0, 3.0, 0.05)
var hold_duration: float = 0.0


# Controls how high above the object's origin
# the interaction marker appears.
#
@export_range(0.0, 3.0, 0.05)
var marker_height: float = 0.65


# Optional animation/pose used by certain interactions.
#
@export_enum(
	"none",
	"low_reach",
	"kneel"
)
var interaction_pose: String = "none"


# =========================================================
# INTERACTION MARKER POSITION
# =========================================================

func interaction_anchor() -> Vector3:

	return (
		global_position
		+ Vector3.UP * marker_height
	)


# =========================================================
# CAN THIS OBJECT CURRENTLY BE USED?
# =========================================================

func interaction_available() -> bool:

	return (
		visible
		and not is_queued_for_deletion()
	)


# =========================================================
# SECONDARY INTERACTION
# =========================================================
#
# Example:
#
# E -> Drink water
# Q/F -> Fill water bag
#
# Most objects leave this empty.
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


# =========================================================
# REGISTER AS AN INTERACTABLE
# =========================================================

func _enter_tree() -> void:

	add_to_group(
		"interactables"
	)
