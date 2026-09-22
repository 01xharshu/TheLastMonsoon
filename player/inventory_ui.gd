extends PanelContainer


# =========================================================
# PLAYER SYSTEMS
# =========================================================

@onready var inventory: InventoryComponent = (
	$"../../../InventoryComponent"
)


@onready var survival: SurvivalComponent = (
	$"../../../SurvivalComponent"
)


@onready var consumables: ConsumableComponent = (
	$"../../../ConsumableComponent"
)


# =========================================================
# UI REFERENCES
# =========================================================

@onready var roti_label: Label = (
	$ContentMargin/Content/RotiRow/RotiLabel
)


@onready var eat_roti_button: Button = (
	$ContentMargin/Content/RotiRow/EatRotiButton
)


@onready var water_label: Label = (
	$ContentMargin/Content/WaterRow/WaterLabel
)


@onready var drink_water_button: Button = (
	$ContentMargin/Content/WaterRow/DrinkWaterButton
)


@onready var water_progress_bar: ProgressBar = (
	$ContentMargin/Content/WaterProgressBar
)


# =========================================================
# STARTUP
# =========================================================

func _ready() -> void:

	visible = false


	# -----------------------------------------------------
	# BUTTONS
	# -----------------------------------------------------

	eat_roti_button.pressed.connect(
		_on_eat_roti_pressed
	)


	drink_water_button.pressed.connect(
		_on_drink_water_pressed
	)


	# -----------------------------------------------------
	# INVENTORY UPDATES
	# -----------------------------------------------------

	inventory.inventory_changed.connect(
		_refresh_inventory
	)


	inventory.water_changed.connect(
		_on_water_changed
	)


	# -----------------------------------------------------
	# SURVIVAL UPDATES
	# -----------------------------------------------------

	survival.satiety_changed.connect(
		_on_satiety_changed
	)


	survival.hydration_changed.connect(
		_on_hydration_changed
	)


	_refresh_inventory()


# =========================================================
# INPUT
# =========================================================

func _input(
	event: InputEvent
) -> void:

	if get_parent().get_parent().get_parent().get_meta("map_open", false) or get_parent().get_parent().get_parent().get_meta("weapon_wheel_open", false):
		return

	if event.is_action_pressed(
		"toggle_inventory"
	):

		toggle_inventory()


		# Prevent the same input from reaching gameplay.

		get_viewport().set_input_as_handled()


# =========================================================
# OPEN / CLOSE
# =========================================================

func toggle_inventory() -> void:

	if visible:

		close_inventory()


	else:

		open_inventory()


func open_inventory() -> void:

	visible = true


	Input.mouse_mode = (
		Input.MOUSE_MODE_VISIBLE
	)


	_refresh_inventory()


func close_inventory() -> void:

	visible = false


	Input.mouse_mode = (
		Input.MOUSE_MODE_CAPTURED
	)


func is_open() -> bool:

	return visible


# =========================================================
# REFRESH
# =========================================================

func _refresh_inventory() -> void:

	_refresh_roti()

	_refresh_water()


# =========================================================
# ROTI
# =========================================================

func _refresh_roti() -> void:

	var roti_count := (
		inventory.get_item_count(
			"roti"
		)
	)


	roti_label.text = (
		"Roti    × "
		+ str(
			roti_count
		)
	)


	eat_roti_button.disabled = (
		roti_count <= 0
		or survival.satiety
		>= survival.max_satiety
	)


func _on_eat_roti_pressed() -> void:

	consumables.eat_roti()


	_refresh_inventory()


# =========================================================
# WATER
# =========================================================

func _refresh_water() -> void:

	# -----------------------------------------------------
	# NO BAG
	# -----------------------------------------------------

	if not inventory.has_water_bag():

		water_label.text = (
			"Water Bag — Not Carried"
		)


		water_progress_bar.value = 0.0


		drink_water_button.disabled = true


		return


	# -----------------------------------------------------
	# HAS BAG
	# -----------------------------------------------------

	var current_water := (
		inventory.get_stored_water_liters()
	)


	var maximum_water := (
		inventory
		.get_total_water_capacity_liters()
	)


	water_label.text = (
		"Water Bag    "
		+ "%.2f / %.2f L"
		% [
			current_water,
			maximum_water
		]
	)


	# -----------------------------------------------------
	# BAR
	# -----------------------------------------------------

	if maximum_water <= 0.0:

		water_progress_bar.value = 0.0


	else:

		water_progress_bar.value = (
			current_water
			/ maximum_water
			* 100.0
		)


	# -----------------------------------------------------
	# DRINK BUTTON
	# -----------------------------------------------------

	drink_water_button.disabled = (
		current_water <= 0.0
		or survival.hydration
		>= survival.max_hydration
	)


func _on_drink_water_pressed() -> void:

	consumables.drink_from_water_bag()


	_refresh_inventory()


# =========================================================
# SIGNAL RESPONSES
# =========================================================

func _on_water_changed(
	_current_liters: float,
	_maximum_liters: float
) -> void:

	_refresh_water()


func _on_satiety_changed(
	_current_satiety: float,
	_maximum_satiety: float
) -> void:

	_refresh_roti()


func _on_hydration_changed(
	_current_hydration: float,
	_maximum_hydration: float
) -> void:

	_refresh_water()
