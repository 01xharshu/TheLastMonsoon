extends Interactable


# =========================================================
# SLEEP SETTINGS
# =========================================================

@export_category("Sleeping")


# How long one sleep interaction lasts.
@export var sleep_hours: float = 8.0


# Amount of Energy restored for each hour slept.
#
# 12.5 × 8
# =
# 100 Energy maximum potential restoration.
@export var energy_restore_per_hour: float = 12.5


# Don't allow sleeping when Arjun is almost completely
# rested.
@export var minimum_tiredness_required: float = 5.0


# =========================================================
# STARTUP
# =========================================================

func _ready() -> void:

	interaction_text = (
		"Sleep 8 Hours"
	)


# =========================================================
# INTERACTION
# =========================================================

func interact(
	player: CharacterBody3D
) -> void:

	# -----------------------------------------------------
	# FIND SURVIVAL SYSTEM
	# -----------------------------------------------------

	var survival := (
		player.get_node_or_null(
			"SurvivalComponent"
		) as SurvivalComponent
	)


	if survival == null:

		push_warning(
			"Charpai could not find "
			+ "SurvivalComponent."
		)

		return


	# -----------------------------------------------------
	# FIND WORLD CLOCK
	# -----------------------------------------------------

	var world := (
		player.get_parent()
	)


	var game_time := (
		world.get_node_or_null(
			"GameTimeSystem"
		) as GameTimeSystem
	)


	if game_time == null:

		push_warning(
			"Charpai could not find "
			+ "GameTimeSystem."
		)

		return


	# -----------------------------------------------------
	# ARE WE TIRED ENOUGH?
	# -----------------------------------------------------

	var tiredness := (
		survival.max_energy
		- survival.energy
	)


	if tiredness < minimum_tiredness_required:

		print(
			"Arjun is not tired enough to sleep."
		)

		return


	# -----------------------------------------------------
	# ADVANCE THE WORLD
	# -----------------------------------------------------
	#
	# This is important:
	#
	# advancing time also causes Hydration,
	# Satiety and Energy to naturally change.
	# -----------------------------------------------------

	game_time.advance_hours(
		sleep_hours
	)


	# -----------------------------------------------------
	# RESTORE ENERGY
	# -----------------------------------------------------

	var energy_to_restore := (
		sleep_hours
		* energy_restore_per_hour
	)


	var restored_energy := (
		survival.restore_energy(
			energy_to_restore
		)
	)


	print(
		"Arjun slept for ",
		sleep_hours,
		" hours. Energy restored: ",
		roundi(
			restored_energy
		)
	)
