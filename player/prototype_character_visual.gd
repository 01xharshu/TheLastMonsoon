extends Node3D


# =========================================================
# WALK ANIMATION
# =========================================================

@export_category("Walking")

@export var walk_swing_degrees: float = 26.0

@export var walk_cycle_speed: float = 7.5


# =========================================================
# SPRINT ANIMATION
# =========================================================

@export_category("Sprinting")

@export var sprint_swing_degrees: float = 42.0

@export var sprint_cycle_speed: float = 11.0


# Because our current walk speed is around 4
# and sprint speed is around 7,
# anything above this is treated visually as sprinting.

@export var sprint_speed_threshold: float = 5.2


# =========================================================
# ANIMATION SMOOTHING
# =========================================================

@export_category("Animation")

@export var animation_blend_speed: float = 12.0


# Legs swing slightly less than arms.

@export var leg_swing_multiplier: float = 0.80


# =========================================================
# REFERENCES
# =========================================================

# CharacterVisual
# ↑ VisualRoot
# ↑ Player

@onready var player: CharacterBody3D = (
	$"../.."
)


@onready var left_arm_pivot: Node3D = (
	$LeftArmPivot
)


@onready var right_arm_pivot: Node3D = (
	$RightArmPivot
)


@onready var left_leg_pivot: Node3D = (
	$LeftLegPivot
)


@onready var right_leg_pivot: Node3D = (
	$RightLegPivot
)


# =========================================================
# INTERNAL STATE
# =========================================================

var cycle_time: float = 0.0


# =========================================================
# UPDATE
# =========================================================

func _process(
	delta: float
) -> void:

	if player == null:
		return


	_update_walk_animation(
		delta
	)


# =========================================================
# WALK / RUN ANIMATION
# =========================================================

func _update_walk_animation(
	delta: float
) -> void:

	# -----------------------------------------------------
	# HORIZONTAL MOVEMENT SPEED
	# -----------------------------------------------------

	var horizontal_speed := Vector2(
		player.velocity.x,
		player.velocity.z
	).length()


	var is_moving := (
		horizontal_speed > 0.15
		and player.is_on_floor()
	)


	# -----------------------------------------------------
	# TARGET ROTATIONS
	# -----------------------------------------------------

	var target_left_arm: float = 0.0

	var target_right_arm: float = 0.0

	var target_left_leg: float = 0.0

	var target_right_leg: float = 0.0


	# -----------------------------------------------------
	# MOVING
	# -----------------------------------------------------

	if is_moving:

		var is_sprinting := (
			horizontal_speed
			> sprint_speed_threshold
		)


		var cycle_speed := (
			sprint_cycle_speed
			if is_sprinting
			else walk_cycle_speed
		)


		var swing_degrees := (
			sprint_swing_degrees
			if is_sprinting
			else walk_swing_degrees
		)


		cycle_time += (
			delta
			* cycle_speed
		)


		var swing := (
			sin(
				cycle_time
			)
			* deg_to_rad(
				swing_degrees
			)
		)


		# -------------------------------------------------
		# NATURAL OPPOSITE ARM / LEG MOVEMENT
		# -------------------------------------------------
		#
		# Left arm forward
		# =
		# right leg forward
		#
		# Right arm forward
		# =
		# left leg forward
		# -------------------------------------------------

		target_left_arm = swing

		target_right_arm = (
			-swing
		)


		target_left_leg = (
			-swing
			* leg_swing_multiplier
		)


		target_right_leg = (
			swing
			* leg_swing_multiplier
		)


	# -----------------------------------------------------
	# SMOOTH BLENDING
	# -----------------------------------------------------

	var blend_amount := clampf(
		animation_blend_speed
		* delta,
		0.0,
		1.0
	)


	left_arm_pivot.rotation.x = lerp_angle(
		left_arm_pivot.rotation.x,
		target_left_arm,
		blend_amount
	)


	right_arm_pivot.rotation.x = lerp_angle(
		right_arm_pivot.rotation.x,
		target_right_arm,
		blend_amount
	)


	left_leg_pivot.rotation.x = lerp_angle(
		left_leg_pivot.rotation.x,
		target_left_leg,
		blend_amount
	)


	right_leg_pivot.rotation.x = lerp_angle(
		right_leg_pivot.rotation.x,
		target_right_leg,
		blend_amount
	)
