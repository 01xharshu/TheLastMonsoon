class_name SurvivalComponent
extends Node


# =========================================================
# HYDRATION
# =========================================================

@export_category("Hydration")

@export var max_hydration: float = 100.0

@export var starting_hydration: float = 60.0

# Lost per IN-GAME hour.
@export var hydration_loss_per_game_hour: float = 4.0


# =========================================================
# SATIETY
# =========================================================

@export_category("Satiety")

@export var max_satiety: float = 100.0

@export var starting_satiety: float = 65.0

# Lost per IN-GAME hour.
@export var satiety_loss_per_game_hour: float = 2.5


# =========================================================
# ENERGY
# =========================================================

@export_category("Energy")

@export var max_energy: float = 100.0

@export var starting_energy: float = 60.0

# Lost per IN-GAME hour while awake / as time passes.
@export var energy_loss_per_game_hour: float = 4.0


# =========================================================
# WARMTH
# =========================================================

@export_category("Warmth")

# Warmth is currently an abstract survival value.
#
# 100 = comfortably warm
# 0   = dangerously cold
#
# Later this will become more sophisticated through
# weather, rain, wetness, clothing and temperature.

@export var max_warmth: float = 100.0

@export var starting_warmth: float = 65.0


# Temporary prototype loss rate.
#
# Later the environment will decide this dynamically.
@export var warmth_loss_per_game_hour: float = 2.0


# How quickly nearby active heat sources restore warmth.
#
# This uses REAL seconds because standing beside a fire is
# an immediate continuous gameplay action.
@export var heat_warmth_per_second: float = 6.0


# =========================================================
# STAMINA
# =========================================================

@export_category("Stamina")

@export var max_stamina: float = 100.0

@export var starting_stamina: float = 100.0

@export var sprint_stamina_loss_per_second: float = 18.0

@export var stamina_recovery_per_second: float = 14.0

@export var exhaustion_recovery_threshold: float = 25.0


# =========================================================
# CURRENT VALUES
# =========================================================

var hydration: float = 60.0

var satiety: float = 65.0

var energy: float = 60.0

var warmth: float = 65.0

var stamina: float = 100.0


# =========================================================
# CURRENT STATE
# =========================================================

var is_sprinting: bool = false

var is_exhausted: bool = false


# Number of active heat sources currently affecting Arjun.
#
# We use a COUNT rather than true/false because later Arjun
# could potentially be inside the range of multiple fires.

var active_heat_sources: int = 0


# =========================================================
# REFERENCES
# =========================================================

@onready var game_time: GameTimeSystem = (
	get_node_or_null(
		"../../GameTimeSystem"
	) as GameTimeSystem
)


# =========================================================
# SIGNALS
# =========================================================

signal hydration_changed(
	current_hydration: float,
	maximum_hydration: float
)


signal satiety_changed(
	current_satiety: float,
	maximum_satiety: float
)


signal energy_changed(
	current_energy: float,
	maximum_energy: float
)


signal warmth_changed(
	current_warmth: float,
	maximum_warmth: float
)


signal stamina_changed(
	current_stamina: float,
	maximum_stamina: float
)


signal exhaustion_changed(
	exhausted: bool
)


# =========================================================
# STARTUP
# =========================================================

func _ready() -> void:

	hydration = clampf(
		starting_hydration,
		0.0,
		max_hydration
	)


	satiety = clampf(
		starting_satiety,
		0.0,
		max_satiety
	)


	energy = clampf(
		starting_energy,
		0.0,
		max_energy
	)


	warmth = clampf(
		starting_warmth,
		0.0,
		max_warmth
	)


	stamina = clampf(
		starting_stamina,
		0.0,
		max_stamina
	)


	is_sprinting = false

	is_exhausted = false

	active_heat_sources = 0


	if game_time == null:

		push_error(
			"SurvivalComponent could not find "
			+ "GameTimeSystem."
		)

	else:

		game_time.time_advanced.connect(
			_on_game_time_advanced
		)


	_emit_hydration_changed()

	_emit_satiety_changed()

	_emit_energy_changed()

	_emit_warmth_changed()

	_emit_stamina_changed()


# =========================================================
# REAL-TIME UPDATE
# =========================================================

func _process(
	delta: float
) -> void:

	_update_stamina(
		delta
	)


	_update_heat_sources(
		delta
	)


# =========================================================
# WORLD TIME ADVANCED
# =========================================================

func _on_game_time_advanced(
	game_minutes: float
) -> void:

	if game_minutes <= 0.0:
		return


	var game_hours: float = (
		game_minutes
		/ 60.0
	)


	_update_hydration_from_time(
		game_hours
	)


	_update_satiety_from_time(
		game_hours
	)


	_update_energy_from_time(
		game_hours
	)


	_update_warmth_from_time(
		game_hours
	)


# =========================================================
# HYDRATION
# =========================================================

func _update_hydration_from_time(
	game_hours: float
) -> void:

	if hydration <= 0.0:
		return


	var previous_hydration := hydration


	hydration -= (
		hydration_loss_per_game_hour
		* game_hours
	)


	hydration = clampf(
		hydration,
		0.0,
		max_hydration
	)


	if not is_equal_approx(
		previous_hydration,
		hydration
	):

		_emit_hydration_changed()


func restore_hydration(
	amount: float
) -> float:

	if amount <= 0.0:
		return 0.0


	var previous_hydration := hydration


	hydration += amount


	hydration = clampf(
		hydration,
		0.0,
		max_hydration
	)


	var restored_amount := (
		hydration
		- previous_hydration
	)


	_emit_hydration_changed()


	return restored_amount


# =========================================================
# SATIETY
# =========================================================

func _update_satiety_from_time(
	game_hours: float
) -> void:

	if satiety <= 0.0:
		return


	var previous_satiety := satiety


	satiety -= (
		satiety_loss_per_game_hour
		* game_hours
	)


	satiety = clampf(
		satiety,
		0.0,
		max_satiety
	)


	if not is_equal_approx(
		previous_satiety,
		satiety
	):

		_emit_satiety_changed()


func restore_satiety(
	amount: float
) -> float:

	if amount <= 0.0:
		return 0.0


	var previous_satiety := satiety


	satiety += amount


	satiety = clampf(
		satiety,
		0.0,
		max_satiety
	)


	var restored_amount := (
		satiety
		- previous_satiety
	)


	_emit_satiety_changed()


	return restored_amount


# =========================================================
# ENERGY
# =========================================================

func _update_energy_from_time(
	game_hours: float
) -> void:

	if energy <= 0.0:
		return


	var previous_energy := energy


	energy -= (
		energy_loss_per_game_hour
		* game_hours
	)


	energy = clampf(
		energy,
		0.0,
		max_energy
	)


	if not is_equal_approx(
		previous_energy,
		energy
	):

		_emit_energy_changed()


func restore_energy(
	amount: float
) -> float:

	if amount <= 0.0:
		return 0.0


	var previous_energy := energy


	energy += amount


	energy = clampf(
		energy,
		0.0,
		max_energy
	)


	var restored_amount := (
		energy
		- previous_energy
	)


	_emit_energy_changed()


	return restored_amount


# =========================================================
# WARMTH LOSS
# =========================================================

func _update_warmth_from_time(
	game_hours: float
) -> void:

	if warmth <= 0.0:
		return


	var previous_warmth := warmth


	warmth -= (
		warmth_loss_per_game_hour
		* game_hours
	)


	warmth = clampf(
		warmth,
		0.0,
		max_warmth
	)


	if not is_equal_approx(
		previous_warmth,
		warmth
	):

		_emit_warmth_changed()


# =========================================================
# HEAT SOURCES
# =========================================================

func register_heat_source() -> void:

	active_heat_sources += 1


func unregister_heat_source() -> void:

	active_heat_sources = maxi(
		0,
		active_heat_sources - 1
	)


func _update_heat_sources(
	delta: float
) -> void:

	if active_heat_sources <= 0:
		return


	if warmth >= max_warmth:
		return


	var previous_warmth := warmth


	# Multiple fires could theoretically provide more heat.
	#
	# For now each active source contributes equally.

	warmth += (
		heat_warmth_per_second
		* float(active_heat_sources)
		* delta
	)


	warmth = clampf(
		warmth,
		0.0,
		max_warmth
	)


	if not is_equal_approx(
		previous_warmth,
		warmth
	):

		_emit_warmth_changed()


# =========================================================
# STAMINA
# =========================================================

func _update_stamina(
	delta: float
) -> void:

	var previous_stamina := stamina


	if (
		is_sprinting
		and not is_exhausted
	):

		stamina -= (
			sprint_stamina_loss_per_second
			* delta
		)


	else:

		stamina += (
			stamina_recovery_per_second
			* delta
		)


	stamina = clampf(
		stamina,
		0.0,
		max_stamina
	)


	if (
		stamina <= 0.0
		and not is_exhausted
	):

		is_exhausted = true

		is_sprinting = false


		exhaustion_changed.emit(
			true
		)


	if (
		is_exhausted
		and stamina
		>= exhaustion_recovery_threshold
	):

		is_exhausted = false


		exhaustion_changed.emit(
			false
		)


	if not is_equal_approx(
		previous_stamina,
		stamina
	):

		_emit_stamina_changed()


# =========================================================
# SPRINT CONTROL
# =========================================================

func set_sprinting(
	value: bool
) -> void:

	if is_exhausted:

		is_sprinting = false

		return


	if stamina <= 0.0:

		is_sprinting = false

		return


	is_sprinting = value


func can_sprint() -> bool:

	return (
		not is_exhausted
		and stamina > 0.0
	)


# =========================================================
# SIGNAL HELPERS
# =========================================================

func _emit_hydration_changed() -> void:

	hydration_changed.emit(
		hydration,
		max_hydration
	)


func _emit_satiety_changed() -> void:

	satiety_changed.emit(
		satiety,
		max_satiety
	)


func _emit_energy_changed() -> void:

	energy_changed.emit(
		energy,
		max_energy
	)


func _emit_warmth_changed() -> void:

	warmth_changed.emit(
		warmth,
		max_warmth
	)


func _emit_stamina_changed() -> void:

	stamina_changed.emit(
		stamina,
		max_stamina
	)
