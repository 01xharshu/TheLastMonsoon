extends Node3D
## Base landscape runtime. Player, inventory and survival continue using their existing scene.
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const REVIEW_POINTS: Array[Vector2] = [Vector2(-230,180), Vector2(12,155), Vector2(470,-250), Vector2(-440,-200)]
const REVIEW_NAMES: Array[String] = ["Bhairavpur approach", "Riverbank", "Eastern wooded hills", "Agricultural plains"]
var layout = Layout.new()
var review_index: int = 0
var overview: bool = false
var last_safe_position := Vector3.ZERO
@onready var player: CharacterBody3D = $Player
@onready var player_camera: Camera3D = $Player/CameraPivot/SpringArm3D/Camera3D
@onready var survey_camera: Camera3D = $SurveyCamera
@onready var location_label: Label = $LandscapeUI/Location

func _ready() -> void:
	# Default budget: 8 GB total device memory, 720p; measured validation in docs/world.
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	get_viewport().use_taa = false
	if not OS.is_debug_build():
		$LandscapeUI/ReviewHelp.text = "WASD move · Shift run · Space jump"
	$Moon.shadow_enabled = false
	player_camera.far = 2200.0
	$LandscapeUI/Location.visible = false
	$LandscapeUI/ReviewHelp.visible = false
	move_to_review_point(0)
	last_safe_position = player.position
	print("SURYAGARH READY | 1728 x 1728 m | 8 GB memory target | surface swimming enabled")

func move_to_review_point(index: int) -> void:
	review_index = posmod(index, REVIEW_POINTS.size())
	var p: Vector2 = REVIEW_POINTS[review_index]
	player.position = Vector3(p.x, layout.height(p.x,p.y)+1.1, p.y)
	player.velocity = Vector3.ZERO
	player.rotation.y = -0.85
	player.camera_pitch = -0.12
	player.get_node("CameraPivot").rotation.x = -0.12
	location_label.text = "SURYAGARH  /  " + REVIEW_NAMES[review_index] + "\nLandscape foundation · 2.986 km²"

func _unhandled_key_input(event: InputEvent) -> void:
	if player.get_meta("map_open", false): return
	if not OS.is_debug_build() or not event.is_pressed() or event.is_echo(): return
	if event is InputEventKey and event.keycode == KEY_F3:
		overview = not overview
		survey_camera.current = overview
		player_camera.current = not overview
		player.set_physics_process(not overview)
		player.set_process_unhandled_input(not overview)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if overview else Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.keycode == KEY_F4 and not overview:
		move_to_review_point(review_index + 1)
		get_viewport().set_input_as_handled()

func _physics_process(_delta: float) -> void:
	var p: Vector3 = player.position
	# Physical edge containment is independent of terrain visuals beyond the playable footprint.
	if absf(p.x) > Layout.HALF - 4.0 or absf(p.z) > Layout.HALF - 4.0:
		player.position.x = clampf(p.x, -Layout.HALF+4, Layout.HALF-4)
		player.position.z = clampf(p.z, -Layout.HALF+4, Layout.HALF-4)
		player.velocity.x = 0
		player.velocity.z = 0
	# Use depth and body height so walking across the bridge never triggers swimming.
	var deep_enough := layout.height(p.x, p.z) < Layout.WATER_LEVEL - 1.0
	var entry_height := 0.65 if player.is_swimming else 0.3
	player.set_water_state(deep_enough and p.y < Layout.WATER_LEVEL + entry_height, Layout.WATER_LEVEL)
