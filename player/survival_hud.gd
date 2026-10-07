extends Control


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

func _draw() -> void:
	var centre := Vector2(72,72)
	draw_arc(centre,9,0,TAU,24,Color(0.92,0.88,0.76,0.45),1,true)
	for axis in [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]:
		draw_line(centre+axis*12,centre+axis*18,Color(0.92,0.88,0.76,0.45),1,true)
	draw_circle(centre,2,Color(0.92,0.88,0.76))

func _ready() -> void:
	var rings := [hydration_ring,satiety_ring,stamina_ring,energy_ring]
	var positions := [Vector2(48,0),Vector2(0,48),Vector2(96,48),Vector2(48,96)]
	for i in 4:
		rings[i].position = positions[i]
		rings[i].size = Vector2(48,48)

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
