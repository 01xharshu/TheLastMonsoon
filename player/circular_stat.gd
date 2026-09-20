class_name CircularStat
extends Control


# =========================================================
# ICON TYPE
# =========================================================
#
# 0 = Hydration
# 1 = Satiety / Food
# 2 = Stamina
# 3 = Energy / Sleep
# =========================================================

@export_enum(
	"Hydration",
	"Satiety",
	"Stamina",
	"Energy"
)
var icon_type: int = 0:
	set(value):

		icon_type = value

		queue_redraw()


# =========================================================
# CURRENT VALUE
# =========================================================

var current_value: float = 100.0

var maximum_value: float = 100.0


# =========================================================
# VISUAL SETTINGS
# =========================================================

@export_category("Ring")

@export var ring_width: float = 5.0


@export var healthy_color: Color = Color(
	0.91,
	0.88,
	0.82,
	1.0
)


@export var low_color: Color = Color(
	0.86,
	0.62,
	0.25,
	1.0
)


@export var critical_color: Color = Color(
	0.82,
	0.22,
	0.18,
	1.0
)


@export var empty_ring_color: Color = Color(
	1.0,
	1.0,
	1.0,
	0.14
)


@export var icon_color: Color = Color(
	0.94,
	0.91,
	0.85,
	1.0
)


# =========================================================
# STARTUP
# =========================================================

func _ready() -> void:

	custom_minimum_size = Vector2(
		64.0,
		64.0
	)


	mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)


	queue_redraw()


# =========================================================
# SET VALUE
# =========================================================

func set_stat_value(
	value: float,
	maximum: float
) -> void:

	maximum_value = maxf(
		maximum,
		1.0
	)


	current_value = clampf(
		value,
		0.0,
		maximum_value
	)


	queue_redraw()


# =========================================================
# DRAW
# =========================================================

func _draw() -> void:

	var center := (
		size
		* 0.5
	)


	var radius := (
		minf(
			size.x,
			size.y
		)
		* 0.5
		- 7.0
	)


	var percentage := (
		current_value
		/ maximum_value
	)


	percentage = clampf(
		percentage,
		0.0,
		1.0
	)


	# -----------------------------------------------------
	# EMPTY / BACKGROUND RING
	# -----------------------------------------------------

	draw_arc(
		center,
		radius,
		0.0,
		TAU,
		64,
		empty_ring_color,
		ring_width,
		true
	)


	# -----------------------------------------------------
	# ACTIVE RING
	# -----------------------------------------------------

	if percentage > 0.0:

		var start_angle := (
			-PI
			/ 2.0
		)


		var end_angle := (
			start_angle
			+ (
				TAU
				* percentage
			)
		)


		draw_arc(
			center,
			radius,
			start_angle,
			end_angle,
			64,
			_get_ring_color(
				percentage
			),
			ring_width,
			true
		)


	# -----------------------------------------------------
	# CENTER ICON
	# -----------------------------------------------------

	_draw_icon(
		center
	)


# =========================================================
# RING COLOUR
# =========================================================

func _get_ring_color(
	percentage: float
) -> Color:

	# Critical:
	#
	# 0% - 20%

	if percentage <= 0.20:

		return critical_color


	# Low:
	#
	# 20% - 40%

	if percentage <= 0.40:

		return low_color


	# Normal

	return healthy_color


# =========================================================
# DRAW ICON
# =========================================================

func _draw_icon(
	center: Vector2
) -> void:

	match icon_type:

		0:
			_draw_hydration_icon(
				center
			)

		1:
			_draw_food_icon(
				center
			)

		2:
			_draw_stamina_icon(
				center
			)

		3:
			_draw_energy_icon(
				center
			)


# =========================================================
# HYDRATION ICON
# =========================================================
#
# Simple water-drop silhouette.
# =========================================================

func _draw_hydration_icon(
	center: Vector2
) -> void:

	var points := PackedVector2Array(
		[
			center + Vector2(
				0.0,
				-11.0
			),

			center + Vector2(
				6.5,
				-2.0
			),

			center + Vector2(
				8.0,
				3.0
			),

			center + Vector2(
				6.0,
				8.0
			),

			center + Vector2(
				0.0,
				11.0
			),

			center + Vector2(
				-6.0,
				8.0
			),

			center + Vector2(
				-8.0,
				3.0
			),

			center + Vector2(
				-6.5,
				-2.0
			)
		]
	)


	draw_colored_polygon(
		points,
		icon_color
	)


# =========================================================
# FOOD ICON
# =========================================================
#
# Simple plate symbol.
# =========================================================

func _draw_food_icon(
	center: Vector2
) -> void:

	draw_circle(
		center,
		9.0,
		icon_color,
		false,
		2.2,
		true
	)


	draw_circle(
		center,
		4.0,
		icon_color,
		false,
		1.8,
		true
	)


# =========================================================
# STAMINA ICON
# =========================================================
#
# Lightning bolt.
# =========================================================

func _draw_stamina_icon(
	center: Vector2
) -> void:

	var points := PackedVector2Array(
		[
			center + Vector2(
				1.0,
				-12.0
			),

			center + Vector2(
				-7.0,
				1.0
			),

			center + Vector2(
				-2.0,
				1.0
			),

			center + Vector2(
				-4.0,
				11.0
			),

			center + Vector2(
				8.0,
				-3.0
			),

			center + Vector2(
				2.0,
				-3.0
			)
		]
	)


	draw_colored_polygon(
		points,
		icon_color
	)


# =========================================================
# ENERGY ICON
# =========================================================
#
# Crescent / sleep symbol.
# =========================================================

func _draw_energy_icon(
	center: Vector2
) -> void:

	var points := PackedVector2Array(
		[
			center + Vector2(
				4.0,
				-11.0
			),

			center + Vector2(
				-2.0,
				-9.0
			),

			center + Vector2(
				-6.0,
				-5.0
			),

			center + Vector2(
				-7.0,
				0.0
			),

			center + Vector2(
				-5.0,
				6.0
			),

			center + Vector2(
				0.0,
				10.0
			),

			center + Vector2(
				6.0,
				9.0
			),

			center + Vector2(
				2.0,
				6.0
			),

			center + Vector2(
				0.0,
				2.0
			),

			center + Vector2(
				0.0,
				-2.0
			),

			center + Vector2(
				2.0,
				-7.0
			)
		]
	)


	draw_colored_polygon(
		points,
		icon_color
	)
