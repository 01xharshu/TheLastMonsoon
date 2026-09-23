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

@export_range(0.05, 0.6, 0.01) var max_walk_step_height: float = 0.38
@export_range(0.0, 0.5, 0.01) var ground_snap_distance: float = 0.3
var step_lift: float = 0.0

@export var swim_speed: float = 2.6
var is_swimming := false
var water_surface := 0.0

func set_water_state(active: bool, surface: float) -> void:
	is_swimming = active and (get_meta("mounted_vehicle") if has_meta("mounted_vehicle") else null) == null and not get_meta("climbing",false)
	water_surface = surface


# =========================================================
# CAMERA SETTINGS
# =========================================================

@export_category("Camera")

@export var mouse_sensitivity: float = 0.0025

@export var min_camera_angle: float = -70.0

@export var max_camera_angle: float = 60.0

var first_person := false
var first_person_view: Node3D
var third_person_height: float
var third_person_distance: float

func set_first_person(enabled: bool) -> void:
	first_person = enabled
	if enabled and first_person_view == null:
		first_person_view = preload("res://player/first_person_view.gd").new()
		$CameraPivot/SpringArm3D/Camera3D.add_child(first_person_view)
		first_person_view.setup($VisualRoot/CharacterVisual)
	if first_person_view:
		first_person_view.visible = enabled
	visual_root.visible = not enabled
	camera_pivot.position.y = 0.68 if enabled else third_person_height
	$CameraPivot/SpringArm3D.spring_length = 0.0 if enabled else third_person_distance
	$CameraPivot/SpringArm3D/Camera3D.near = 0.03 if enabled else 0.05
	# Reset immediately rather than waiting for the spring arm's next physics update.
	$CameraPivot/SpringArm3D/Camera3D.position.z = 0.0 if enabled else third_person_distance


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

@onready var river_water = $RiverWaterComponent


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
	if not inventory.has_water_bag():
		inventory.add_item("water_bag", 1)
	floor_snap_length = ground_snap_distance

	third_person_height = camera_pivot.position.y
	third_person_distance = $CameraPivot/SpringArm3D.spring_length
	$CameraPivot/SpringArm3D.add_excluded_object(get_rid())

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

	if inventory_ui.is_open() or get_meta("map_open", false) or get_meta("weapon_wheel_open", false) or get_meta("scroll_open", false) or get_meta("river_action", "") != "":
		return


	# -----------------------------------------------------
	# CAMERA
	# -----------------------------------------------------

	if event.is_action_pressed("toggle_view"):
		set_first_person(not first_person)
		get_viewport().set_input_as_handled()

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

		if get_parent().has_node("GameMenu"):
			get_parent().get_node("GameMenu").toggle()
		else:
			_toggle_mouse_capture()
		get_viewport().set_input_as_handled()


	# -----------------------------------------------------
	# E — PRIMARY INTERACTION
	# -----------------------------------------------------

	if event.is_action_pressed(
		"interact"
	):

		if (get_meta("mounted_vehicle") if has_meta("mounted_vehicle") else null)==null and not get_meta("climbing",false):
			if Input.is_key_pressed(KEY_SHIFT):
				_try_secondary_interaction()
			else:
				_try_primary_interaction()


	# -----------------------------------------------------
	# F — SECONDARY INTERACTION
	# -----------------------------------------------------

	if event.is_action_pressed(
		"secondary_interact"
	):

		$RideComponent.try_toggle()


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
	if get_meta("river_action", "") != "":
		velocity = Vector3.ZERO
		survival.set_sprinting(false)
		move_and_slide()
		_hide_interaction_labels()
		return

	if (get_meta("mounted_vehicle") if has_meta("mounted_vehicle") else null) != null or get_meta("climbing",false):
		velocity = Vector3.ZERO
		survival.set_sprinting(false)
		_hide_interaction_labels()
		return

	# -----------------------------------------------------
	# INVENTORY OPEN
	# -----------------------------------------------------

	if inventory_ui.is_open() or get_meta("map_open", false) or get_meta("weapon_wheel_open", false) or get_meta("scroll_open", false):

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


	var intended_horizontal := Vector3(velocity.x, 0.0, velocity.z) * delta
	move_and_slide()
	_try_walk_step(delta, intended_horizontal)


	_update_interaction()


func _try_walk_step(delta: float, horizontal: Vector3) -> void:
	step_lift = move_toward(step_lift, 0.0, delta * 4.0)
	if is_swimming or not is_on_floor() or velocity.y > 0.0:
		return
	if horizontal.length_squared() < 0.0001:
		return
	# Only step when the normal slide was blocked in the intended direction.
	var traveled := get_position_delta()
	if Vector2(traveled.x, traveled.z).dot(Vector2(horizontal.x, horizontal.z)) > horizontal.length_squared() * 0.8:
		return
	var space := get_world_3d().direct_space_state
	var raised := global_transform.translated(Vector3.UP * max_walk_step_height)
	if test_move(global_transform, Vector3.UP * max_walk_step_height):
		return
	if test_move(raised, horizontal):
		return
	var capsule: CapsuleShape3D = $CollisionShape3D.shape
	var probe_forward: Vector3 = horizontal.normalized() * (capsule.radius + 0.08)
	var probe_at: Vector3 = raised.origin + horizontal + probe_forward
	var query := PhysicsRayQueryParameters3D.create(probe_at + Vector3.UP * 0.05, probe_at - Vector3.UP * 1.05)
	query.exclude = [get_rid()]
	var floor_hit := space.intersect_ray(query)
	if floor_hit.is_empty() or floor_hit.normal.dot(Vector3.UP) < cos(floor_max_angle):
		return
	var rise: float = floor_hit.position.y + capsule.height * 0.5 - global_position.y
	if rise < 0.025 or rise > max_walk_step_height + 0.02:
		return
	global_position = Vector3(global_position.x + horizontal.x, global_position.y + rise, global_position.z + horizontal.z)
	step_lift = maxf(step_lift, rise)
	velocity.y = 0.0


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


	# Orbit the camera without rotating the actor or its visual children.
	camera_pivot.rotate_y(
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

func _process(delta: float) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or inventory_ui.is_open() or get_meta("map_open",false) or get_meta("weapon_wheel_open",false):
		return
	var stick := Input.get_vector("look_left","look_right","look_up","look_down")
	if stick.length_squared() < .0001:
		return
	camera_pivot.rotate_y(-stick.x * 2.4 * delta)
	camera_pitch = clampf(camera_pitch - stick.y * 1.9 * delta,deg_to_rad(min_camera_angle),deg_to_rad(max_camera_angle))
	camera_pivot.rotation.x = camera_pitch


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


	# Movement follows camera yaw only; looking up/down cannot change speed.
	input_direction = (
		Basis(Vector3.UP, camera_pivot.global_rotation.y)
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


	visual_root.global_rotation.y = lerp_angle(
		visual_root.global_rotation.y,
		target_angle,
		1.0 - exp(-10.0 * delta)
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
	if Input.is_action_just_pressed("jump") and $ClimbComponent.try_start():
		return

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

func _find_interactable() -> Interactable:
	var forward: Vector3 = -camera_pivot.global_basis.z if first_person else visual_root.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var best: Interactable
	var best_score := -INF
	var origin := global_position + Vector3.UP * 0.2
	for node in get_tree().get_nodes_in_group("interactables"):
		if not is_instance_valid(node) or node.is_queued_for_deletion(): continue
		var candidate := node as Interactable
		if candidate == null: continue
		var offset := candidate.global_position - global_position
		var distance := offset.length()
		if distance > 2.6: continue
		var flat := Vector3(offset.x, 0, offset.z)
		var alignment := forward.dot(flat.normalized()) if flat.length() > 0.1 else 1.0
		if alignment < 0.65: continue
		var query := PhysicsRayQueryParameters3D.create(origin, candidate.global_position)
		query.exclude = [get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider != candidate: continue
		var score := alignment * 2.0 - distance * 0.25
		if score > best_score:
			best = candidate
			best_score = score
	return best

func _update_interaction() -> void:
	current_interactable = _find_interactable()
	if current_interactable == null:
		if river_water.can_use_river():
			primary_interaction_label.text = "[E] Drink river water"
			primary_interaction_label.visible = true
			secondary_interaction_label.text = "[Shift+E] Fill water pouch"
			secondary_interaction_label.visible = inventory.has_water_bag() and inventory.get_available_water_capacity_liters() > 0.0
		else:
			_hide_interaction_labels()
		return
	primary_interaction_label.text = "[E] " + current_interactable.interaction_text
	primary_interaction_label.visible = true
	secondary_interaction_label.visible = current_interactable.has_secondary_interaction()
	secondary_interaction_label.text = "[Shift+E] " + current_interactable.secondary_interaction_text


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

	current_interactable = _find_interactable()

	if current_interactable == null:
		river_water.start_drink()
		return


	current_interactable.interact(
		self
	)


# =========================================================
# F — SECONDARY
# =========================================================

func _try_secondary_interaction() -> void:

	current_interactable = _find_interactable()

	if current_interactable == null:
		river_water.start_fill()
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
