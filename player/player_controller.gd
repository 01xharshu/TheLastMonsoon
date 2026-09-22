extends CharacterBody3D


# =========================================================
# MOVEMENT SETTINGS
# =========================================================

@export_category("Movement")

@export var walk_speed: float = 4.0

@export var sprint_speed: float = 7.0

@export var acceleration: float = 12.0

@export var deceleration: float = 16.0

@export var jump_velocity: float = 5.0

@export var swim_speed: float = 2.6
var is_swimming := false
var water_surface := 0.0

func set_water_state(active: bool, surface: float) -> void:
	is_swimming = active
	water_surface = surface


# =========================================================
# CAMERA SETTINGS
# =========================================================

@export_category("Camera")

@export var mouse_sensitivity: float = 0.0025

@export var min_camera_angle: float = -70.0

@export var max_camera_angle: float = 60.0


# =========================================================
# NODE REFERENCES
# =========================================================

@onready var camera_pivot: Node3D = (
	$CameraPivot
)


@onready var visual_root: Node3D = (
	$VisualRoot
)


@onready var interaction_ray: RayCast3D = (
	$CameraPivot/SpringArm3D/Camera3D/InteractionRay
)


# =========================================================
# INTERACTION UI
# =========================================================

@onready var primary_interaction_label: Label = (
	$UI/HUDRoot/PrimaryInteractionLabel
)


@onready var secondary_interaction_label: Label = (
	$UI/HUDRoot/SecondaryInteractionLabel
)


# =========================================================
# PLAYER SYSTEMS
# =========================================================

@onready var survival: SurvivalComponent = (
	$SurvivalComponent
)


@onready var inventory: InventoryComponent = (
	$InventoryComponent
)


@onready var consumables: ConsumableComponent = (
	$ConsumableComponent
)


@onready var inventory_ui = (
	$UI/HUDRoot/InventoryPanel
)


# =========================================================
# INTERNAL VARIABLES
# =========================================================

var gravity: float = ProjectSettings.get_setting(
	"physics/3d/default_gravity"
)


var camera_pitch: float = 0.0


var current_interactable: Interactable = null


# =========================================================
# STARTUP
# =========================================================

func _ready() -> void:

	Input.mouse_mode = (
		Input.MOUSE_MODE_CAPTURED
	)


	interaction_ray.add_exception(
		self
	)


	primary_interaction_label.visible = false

	secondary_interaction_label.visible = false


# =========================================================
# INPUT
# =========================================================

func _unhandled_input(
	event: InputEvent
) -> void:

	# InventoryPanel handles TAB itself.
	#
	# While the inventory is open, gameplay input
	# should not control Arjun.

	if inventory_ui.is_open() or get_meta("map_open", false) or get_meta("weapon_wheel_open", false):
		return


	# -----------------------------------------------------
	# CAMERA
	# -----------------------------------------------------

	if event is InputEventMouseMotion:

		_handle_mouse_look(
			event
		)


	# -----------------------------------------------------
	# ESCAPE
	# -----------------------------------------------------

	if event.is_action_pressed(
		"pause"
	):

		_toggle_mouse_capture()


	# -----------------------------------------------------
	# E — PRIMARY INTERACTION
	# -----------------------------------------------------

	if event.is_action_pressed(
		"interact"
	):

		_try_primary_interaction()


	# -----------------------------------------------------
	# F — SECONDARY INTERACTION
	# -----------------------------------------------------

	if event.is_action_pressed(
		"secondary_interact"
	):

		_try_secondary_interaction()


	# -----------------------------------------------------
	# 0 — QUICK DRINK
	# -----------------------------------------------------

	if event.is_action_pressed(
		"drink_water"
	):

		consumables.drink_from_water_bag()


# =========================================================
# PHYSICS
# =========================================================

func _physics_process(
	delta: float
) -> void:

	# -----------------------------------------------------
	# INVENTORY OPEN
	# -----------------------------------------------------

	if inventory_ui.is_open() or get_meta("map_open", false) or get_meta("weapon_wheel_open", false):

		_apply_gravity(
			delta
		)


		survival.set_sprinting(
			false
		)


		velocity.x = move_toward(
			velocity.x,
			0.0,
			deceleration
			* delta
		)


		velocity.z = move_toward(
			velocity.z,
			0.0,
			deceleration
			* delta
		)


		move_and_slide()


		_hide_interaction_labels()


		return


	# -----------------------------------------------------
	# NORMAL GAMEPLAY
	# -----------------------------------------------------

	_apply_gravity(
		delta
	)


	_handle_jump()


	_handle_movement(
		delta
	)


	move_and_slide()


	_update_interaction()


# =========================================================
# CAMERA
# =========================================================

func _handle_mouse_look(
	event: InputEventMouseMotion
) -> void:

	if (
		Input.mouse_mode
		!= Input.MOUSE_MODE_CAPTURED
	):

		return


	rotate_y(
		-event.relative.x
		* mouse_sensitivity
	)


	camera_pitch -= (
		event.relative.y
		* mouse_sensitivity
	)


	camera_pitch = clampf(
		camera_pitch,
		deg_to_rad(
			min_camera_angle
		),
		deg_to_rad(
			max_camera_angle
		)
	)


	camera_pivot.rotation.x = (
		camera_pitch
	)


# =========================================================
# MOVEMENT
# =========================================================

func _handle_movement(
	delta: float
) -> void:

	var input_vector := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)


	var input_direction := Vector3(
		input_vector.x,
		0.0,
		input_vector.y
	)


	input_direction = (
		global_transform.basis
		* input_direction
	).normalized()


	# -----------------------------------------------------
	# SPRINT
	# -----------------------------------------------------

	var wants_to_sprint := (
		Input.is_action_pressed(
			"sprint"
		)
		and input_direction
		!= Vector3.ZERO
	)


	var is_sprinting := (
		wants_to_sprint
		and survival.can_sprint()
		and not is_swimming
	)


	survival.set_sprinting(
		is_sprinting
	)


	# -----------------------------------------------------
	# SPEED
	# -----------------------------------------------------

	var current_speed := swim_speed if is_swimming else walk_speed


	if is_sprinting:

		current_speed = (
			sprint_speed
		)


	# -----------------------------------------------------
	# MOVING
	# -----------------------------------------------------

	if input_direction != Vector3.ZERO:

		velocity.x = move_toward(
			velocity.x,
			input_direction.x
			* current_speed,
			acceleration
			* delta
		)


		velocity.z = move_toward(
			velocity.z,
			input_direction.z
			* current_speed,
			acceleration
			* delta
		)


		_rotate_character_visual(
			input_direction,
			delta
		)


	# -----------------------------------------------------
	# STOPPING
	# -----------------------------------------------------

	else:

		survival.set_sprinting(
			false
		)


		velocity.x = move_toward(
			velocity.x,
			0.0,
			deceleration
			* delta
		)


		velocity.z = move_toward(
			velocity.z,
			0.0,
			deceleration
			* delta
		)


# =========================================================
# VISUAL ROTATION
# =========================================================

func _rotate_character_visual(
	direction: Vector3,
	delta: float
) -> void:

	if (
		direction.length_squared()
		== 0.0
	):

		return


	var target_angle := atan2(
		direction.x,
		direction.z
	)


	visual_root.rotation.y = lerp_angle(
		visual_root.rotation.y,
		target_angle,
		10.0 * delta
	)


# =========================================================
# GRAVITY
# =========================================================

func _apply_gravity(
	delta: float
) -> void:

	if is_swimming:
		# Damped buoyancy keeps the head above the surface, even with inventory open.
		var target_y := water_surface - 0.25
		velocity.y = move_toward(velocity.y, clampf((target_y - global_position.y) * 4.0, -2.0, 3.0), delta * 10.0)
	elif not is_on_floor():

		velocity.y -= (
			gravity
			* delta
		)


# =========================================================
# JUMP
# =========================================================

func _handle_jump() -> void:

	if (
		Input.is_action_just_pressed(
			"jump"
		)
		and is_on_floor()
		and not is_swimming
	):

		velocity.y = (
			jump_velocity
		)


# =========================================================
# INTERACTION DETECTION
# =========================================================

func _update_interaction() -> void:

	current_interactable = null


	if not interaction_ray.is_colliding():

		_hide_interaction_labels()

		return


	var collider := (
		interaction_ray.get_collider()
	)


	if collider is Interactable:

		current_interactable = (
			collider as Interactable
		)


		# PRIMARY

		primary_interaction_label.text = (
			"[E] "
			+ current_interactable.interaction_text
		)


		primary_interaction_label.visible = true


		# SECONDARY

		if (
			current_interactable
			.has_secondary_interaction()
		):

			secondary_interaction_label.text = (
				"[F] "
				+ current_interactable
				.secondary_interaction_text
			)


			secondary_interaction_label.visible = true


		else:

			secondary_interaction_label.visible = false


	else:

		_hide_interaction_labels()


# =========================================================
# HIDE INTERACTION LABELS
# =========================================================

func _hide_interaction_labels() -> void:

	primary_interaction_label.visible = false

	secondary_interaction_label.visible = false


# =========================================================
# E — PRIMARY
# =========================================================

func _try_primary_interaction() -> void:

	if current_interactable == null:
		return


	current_interactable.interact(
		self
	)


# =========================================================
# F — SECONDARY
# =========================================================

func _try_secondary_interaction() -> void:

	if current_interactable == null:
		return


	if not (
		current_interactable
		.has_secondary_interaction()
	):

		return


	current_interactable.secondary_interact(
		self
	)


# =========================================================
# MOUSE CAPTURE
# =========================================================

func _toggle_mouse_capture() -> void:

	if (
		Input.mouse_mode
		== Input.MOUSE_MODE_CAPTURED
	):

		Input.mouse_mode = (
			Input.MOUSE_MODE_VISIBLE
		)


	else:

		Input.mouse_mode = (
			Input.MOUSE_MODE_CAPTURED
		)
