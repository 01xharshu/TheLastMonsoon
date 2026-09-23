class_name GameTimeSystem
extends Node


# =========================================================
# SIGNALS
# =========================================================

signal time_changed(
	day: int,
	hour: int,
	minute: int
)


signal day_changed(
	day: int
)


# Tells simulation systems exactly how much
# in-game time passed.
signal time_advanced(
	game_minutes: float
)


# =========================================================
# CLOCK SETTINGS
# =========================================================

@export_category("Clock")


@export_range(0, 23, 1)
var starting_hour: int = 6


@export_range(0, 59, 1)
var starting_minute: int = 0


# 600 real seconds = 1440 game minutes (one full day).
@export var game_minutes_per_real_second: float = 2.4


@export var clock_paused: bool = false


# =========================================================
# CONSTANTS
# =========================================================

const MINUTES_PER_HOUR: int = 60

const HOURS_PER_DAY: int = 24

const MINUTES_PER_DAY: int = (
	MINUTES_PER_HOUR
	* HOURS_PER_DAY
)


# =========================================================
# CURRENT TIME
# =========================================================

var current_day: int = 1

var current_hour: int = 6

var current_minute: int = 0


var total_game_minutes: float = 0.0


var last_reported_absolute_minute: int = -1


# =========================================================
# STARTUP
# =========================================================

func _ready() -> void:

	total_game_minutes = float(
		starting_hour
		* MINUTES_PER_HOUR
		+ starting_minute
	)


	_update_readable_time(
		true
	)


# =========================================================
# NORMAL CLOCK UPDATE
# =========================================================

func _process(
	delta: float
) -> void:

	if clock_paused:
		return


	var advanced_minutes: float = (
		game_minutes_per_real_second
		* delta
	)


	_advance_game_minutes(
		advanced_minutes
	)


# =========================================================
# PUBLIC TIME-SKIPPING FUNCTIONS
# =========================================================
#
# Other systems can call these.
#
# Example:
#
# sleeping:
#
# game_time.advance_hours(8)
#
# travelling:
#
# game_time.advance_minutes(45)
# =========================================================

func advance_minutes(
	minutes: float
) -> void:

	if minutes <= 0.0:
		return


	_advance_game_minutes(
		minutes
	)


func advance_hours(
	hours: float
) -> void:

	if hours <= 0.0:
		return


	advance_minutes(
		hours
		* float(MINUTES_PER_HOUR)
	)


# =========================================================
# INTERNAL TIME ADVANCEMENT
# =========================================================

func _advance_game_minutes(
	minutes: float
) -> void:

	if minutes <= 0.0:
		return


	total_game_minutes += (
		minutes
	)


	# SurvivalComponent and future simulation systems
	# receive the SAME amount of elapsed game time.
	time_advanced.emit(
		minutes
	)


	_update_readable_time(
		false
	)


# =========================================================
# UPDATE DAY / HOUR / MINUTE
# =========================================================

func _update_readable_time(
	force_update: bool
) -> void:

	var absolute_minute: int = int(
		floor(
			total_game_minutes
		)
	)


	if (
		not force_update
		and absolute_minute
		== last_reported_absolute_minute
	):
		return


	last_reported_absolute_minute = (
		absolute_minute
	)


	# -----------------------------------------------------
	# DAY
	# -----------------------------------------------------

	var new_day: int = (
		int(
			floor(
				float(absolute_minute)
				/ float(MINUTES_PER_DAY)
			)
		)
		+ 1
	)


	# -----------------------------------------------------
	# MINUTES WITHIN CURRENT DAY
	# -----------------------------------------------------

	var minute_of_day: int = (
		absolute_minute
		% MINUTES_PER_DAY
	)


	# -----------------------------------------------------
	# HOUR
	# -----------------------------------------------------

	var new_hour: int = int(
		floor(
			float(minute_of_day)
				/ float(MINUTES_PER_HOUR)
		)
	)


	# -----------------------------------------------------
	# MINUTE
	# -----------------------------------------------------

	var new_minute: int = (
		minute_of_day
		% MINUTES_PER_HOUR
	)


	# -----------------------------------------------------
	# DAY CHANGE
	# -----------------------------------------------------

	if new_day != current_day:

		current_day = new_day


		day_changed.emit(
			current_day
		)


	current_hour = new_hour

	current_minute = new_minute


	time_changed.emit(
		current_day,
		current_hour,
		current_minute
	)


# =========================================================
# TIME-OF-DAY FRACTION
# =========================================================

func get_time_of_day_fraction() -> float:

	var minute_inside_day: float = fmod(
		total_game_minutes,
		float(MINUTES_PER_DAY)
	)


	return (
		minute_inside_day
		/ float(MINUTES_PER_DAY)
	)


# =========================================================
# FORMATTED TIME
# =========================================================

func get_formatted_time() -> String:

	var display_hour: int = (
		current_hour
		% 12
	)


	var suffix: String = "AM"


	if current_hour >= 12:

		suffix = "PM"


	if display_hour == 0:

		display_hour = 12


	return (
		"%02d:%02d %s"
		% [
			display_hour,
			current_minute,
			suffix
		]
	)


func get_day_text() -> String:

	return (
		"DAY %d"
		% current_day
	)
