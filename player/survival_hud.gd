extends HBoxContainer


# =========================================================
# SURVIVAL SYSTEM
# =========================================================

@onready var survival: SurvivalComponent = (
	$"../../../SurvivalComponent"
)


# =========================================================
# RINGS
# =========================================================

@onready var hydration_ring: CircularStat = (
	$HydrationRing
)


@onready var satiety_ring: CircularStat = (
	$SatietyRing
)


@onready var stamina_ring: CircularStat = (
	$StaminaRing
)


@onready var energy_ring: CircularStat = (
	$EnergyRing
)


# =========================================================
# STARTUP
# =========================================================

func _ready() -> void:

	mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


	# -----------------------------------------------------
	# ASSIGN ICON TYPES
	# -----------------------------------------------------

	hydration_ring.icon_type = 0

	satiety_ring.icon_type = 1

	stamina_ring.icon_type = 2

	energy_ring.icon_type = 3


	# -----------------------------------------------------
	# CONNECT SURVIVAL SIGNALS
	# -----------------------------------------------------

	survival.hydration_changed.connect(
		_on_hydration_changed
	)


	survival.satiety_changed.connect(
		_on_satiety_changed
	)


	survival.stamina_changed.connect(
		_on_stamina_changed
	)


	survival.energy_changed.connect(
		_on_energy_changed
	)


	# -----------------------------------------------------
	# INITIAL VALUES
	# -----------------------------------------------------

	_on_hydration_changed(
		survival.hydration,
		survival.max_hydration
	)


	_on_satiety_changed(
		survival.satiety,
		survival.max_satiety
	)


	_on_stamina_changed(
		survival.stamina,
		survival.max_stamina
	)


	_on_energy_changed(
		survival.energy,
		survival.max_energy
	)


# =========================================================
# HYDRATION
# =========================================================

func _on_hydration_changed(
	current_value: float,
	maximum_value: float
) -> void:

	hydration_ring.set_stat_value(
		current_value,
		maximum_value
	)


# =========================================================
# SATIETY
# =========================================================

func _on_satiety_changed(
	current_value: float,
	maximum_value: float
) -> void:

	satiety_ring.set_stat_value(
		current_value,
		maximum_value
	)


# =========================================================
# STAMINA
# =========================================================

func _on_stamina_changed(
	current_value: float,
	maximum_value: float
) -> void:

	stamina_ring.set_stat_value(
		current_value,
		maximum_value
	)


# =========================================================
# ENERGY
# =========================================================

func _on_energy_changed(
	current_value: float,
	maximum_value: float
) -> void:

	energy_ring.set_stat_value(
		current_value,
		maximum_value
	)
