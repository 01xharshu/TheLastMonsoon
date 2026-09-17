extends CharacterBody3D


# ---------------------------------------------------------
# MOVEMENT SETTINGS
# ---------------------------------------------------------

@export_category("Movement")

@export var walk_speed: float = 4.0
@export var sprint_speed: float = 7.0
@export var acceleration: float = 12.0
@export var deceleration: float = 16.0
@export var jump_velocity: float = 5.0


# ---------------------------------------------------------
# CAMERA SETTINGS
# ---------------------------------------------------------

@export_category("Camera")

@export var mouse_sensitivity: float = 0.0025
@export var min_camera_angle: float = -70.0
@export var max_camera_angle: float = 60.0


# ---------------------------------------------------------
# NODE REFERENCES
# ---------------------------------------------------------

@onready var camera_pivot: Node3D = $CameraPivot
@onready var visual_root: Node3D = $VisualRoot

@onready var interaction_ray: RayCast3D = (
	$CameraPivot/SpringArm3D/Camera3D/InteractionRay
)

@onready var interaction_label: Label = (
	$UI/InteractionLabel
)


# ---------------------------------------------------------
# INTERNAL VARIABLES
# ---------------------------------------------------------

var gravity: float = ProjectSettings.get_setting(
	"physics/3d/default_gravity"
)

var camera_pitch: float = 0.0

var current_interactable: Interactable = null


# ---------------------------------------------------------
# STARTUP
# ---------------------------------------------------------

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	interaction_label.visible = false


# ---------------------------------------------------------
# INPUT
# ---------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:

	if event is InputEventMouseMotion:
		_handle_mouse_look(event)

	if event.is_action_pressed("pause"):
		_toggle_mouse_capture()

	if event.is_action_pressed("interact"):
		_try_interact()


# ---------------------------------------------------------
# PHYSICS UPDATE
# ---------------------------------------------------------

func _physics_process(delta: float) -> void:

	_apply_gravity(delta)

	_handle_jump()

	_handle_movement(delta)

	move_and_slide()

	_update_interaction()


# ---------------------------------------------------------
# CAMERA
# ---------------------------------------------------------

func _handle_mouse_look(
	event: InputEventMouseMotion
) -> void:

	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	rotate_y(
		-event.relative.x * mouse_sensitivity
	)

	camera_pitch -= (
		event.relative.y * mouse_sensitivity
	)

	camera_pitch = clamp(
		camera_pitch,
		deg_to_rad(min_camera_angle),
		deg_to_rad(max_camera_angle)
	)

	camera_pivot.rotation.x = camera_pitch


# ---------------------------------------------------------
# MOVEMENT
# ---------------------------------------------------------

func _handle_movement(delta: float) -> void:

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
		global_transform.basis *
		input_direction
	).normalized()

	var current_speed := walk_speed

	if Input.is_action_pressed("sprint"):
		current_speed = sprint_speed

	if input_direction != Vector3.ZERO:

		velocity.x = move_toward(
			velocity.x,
			input_direction.x * current_speed,
			acceleration * delta
		)

		velocity.z = move_toward(
			velocity.z,
			input_direction.z * current_speed,
			acceleration * delta
		)

		_rotate_character_visual(
			input_direction,
			delta
		)

	else:

		velocity.x = move_toward(
			velocity.x,
			0.0,
			deceleration * delta
		)

		velocity.z = move_toward(
			velocity.z,
			0.0,
			deceleration * delta
		)


# ---------------------------------------------------------
# CHARACTER VISUAL ROTATION
# ---------------------------------------------------------

func _rotate_character_visual(
	direction: Vector3,
	delta: float
) -> void:

	if direction.length_squared() == 0:
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


# ---------------------------------------------------------
# GRAVITY
# ---------------------------------------------------------

func _apply_gravity(delta: float) -> void:

	if not is_on_floor():
		velocity.y -= gravity * delta


# ---------------------------------------------------------
# JUMP
# ---------------------------------------------------------

func _handle_jump() -> void:

	if (
		Input.is_action_just_pressed("jump")
		and is_on_floor()
	):
		velocity.y = jump_velocity


# ---------------------------------------------------------
# INTERACTION DETECTION
# ---------------------------------------------------------

func _update_interaction() -> void:

	current_interactable = null

	if not interaction_ray.is_colliding():
		interaction_label.visible = false
		return

	var collider = interaction_ray.get_collider()

	if collider is Interactable:

		current_interactable = collider

		interaction_label.text = (
			"[E] " +
			current_interactable.interaction_text
		)

		interaction_label.visible = true

	else:

		interaction_label.visible = false


# ---------------------------------------------------------
# INTERACTION ACTION
# ---------------------------------------------------------

func _try_interact() -> void:

	if current_interactable == null:
		return

	current_interactable.interact(self)


# ---------------------------------------------------------
# MOUSE CAPTURE
# ---------------------------------------------------------

func _toggle_mouse_capture() -> void:

	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:

		Input.mouse_mode = (
			Input.MOUSE_MODE_VISIBLE
		)

	else:

		Input.mouse_mode = (
			Input.MOUSE_MODE_CAPTURED
		)
