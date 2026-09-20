extends DirectionalLight3D


# =========================================================
# SUN SETTINGS
# =========================================================

@export_category("Sun")


@export var daytime_sun_energy: float = 1.0


@export var nighttime_sun_energy: float = 0.0


@export var sun_azimuth_degrees: float = -30.0


# =========================================================
# MOON SETTINGS
# =========================================================

@export_category("Moon")


@export var maximum_moon_energy: float = 0.12


# =========================================================
# REFERENCES
# =========================================================
#
# Scene hierarchy:
#
# TestWorld
# ├── Sun
# ├── Moon
# └── GameTimeSystem
#
#
# Sun is directly inside TestWorld.
#
# Therefore:
#
# ../GameTimeSystem
#
# means:
#
# Sun
# ↑ TestWorld
# ↓ GameTimeSystem
#
#
# ../Moon works the same way.
# =========================================================

@onready var game_time: GameTimeSystem = (
	$"../GameTimeSystem"
)


@onready var moon: DirectionalLight3D = (
	$"../Moon"
)


# =========================================================
# STARTUP
# =========================================================

func _ready() -> void:

	if game_time == null:

		push_error(
			"Sun could not find GameTimeSystem."
		)

		return


	if moon == null:

		push_error(
			"Sun could not find Moon."
		)

		return


	shadow_enabled = true

	moon.shadow_enabled = true


	_update_day_night_lighting()


# =========================================================
# UPDATE
# =========================================================

func _process(
	_delta: float
) -> void:

	if game_time == null:
		return


	if moon == null:
		return


	_update_day_night_lighting()


# =========================================================
# DAY / NIGHT LIGHTING
# =========================================================

func _update_day_night_lighting() -> void:

	var time_fraction := (
		game_time.get_time_of_day_fraction()
	)


	# =====================================================
	# SUN POSITION
	# =====================================================

	var sun_pitch := (
		90.0
		- (
			time_fraction
			* 360.0
		)
	)


	rotation_degrees = Vector3(
		sun_pitch,
		sun_azimuth_degrees,
		0.0
	)


	# =====================================================
	# MOON POSITION
	# =====================================================

	var moon_pitch := (
		sun_pitch
		+ 180.0
	)


	moon.rotation_degrees = Vector3(
		moon_pitch,
		sun_azimuth_degrees,
		0.0
	)


	# =====================================================
	# SUNLIGHT
	# =====================================================

	var daylight_amount := sin(
		(
			time_fraction
			- 0.25
		)
		* TAU
	)


	daylight_amount = clampf(
		daylight_amount,
		0.0,
		1.0
	)


	light_energy = lerpf(
		nighttime_sun_energy,
		daytime_sun_energy,
		daylight_amount
	)


	# =====================================================
	# MOONLIGHT
	# =====================================================

	var moonlight_amount := -sin(
		(
			time_fraction
			- 0.25
		)
		* TAU
	)


	moonlight_amount = clampf(
		moonlight_amount,
		0.0,
		1.0
	)


	moon.light_energy = (
		maximum_moon_energy
		* moonlight_amount
	)
