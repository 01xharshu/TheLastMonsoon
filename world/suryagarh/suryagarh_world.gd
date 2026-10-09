extends Node3D
## Base landscape runtime. Player, inventory and survival continue using their existing scene.
const Startup = preload("res://systems/world_startup.gd")
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const REVIEW_POINTS: Array[Vector2] = [Vector2(-230,180), Vector2(12,155), Vector2(470,-250), Vector2(-440,-200), Vector2(520,-300), Vector2(344,-105), Vector2(-167,642)]
const REVIEW_NAMES: Array[String] = ["Bhairavpur approach", "Riverbank", "Eastern wooded hills", "Agricultural plains", "Old fort approach", "Forest biome patch", "Hooghly Reach Port"]
var layout = Layout.new()
var review_index: int = 0
var overview: bool = false
var startup_tree_task := -1
var last_safe_position := Vector3.ZERO
@onready var player: CharacterBody3D = $Player
@onready var player_camera: Camera3D = $Player/CameraPivot/SpringArm3D/Camera3D
@onready var survey_camera: Camera3D = $SurveyCamera
@onready var location_label: Label = $LandscapeUI/Location

func _enter_tree() -> void:
	if Startup.current != null: hide()

func _ready() -> void:
	var startup_task := Startup.begin("World")
	await Startup.wait_others(self, startup_task)
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
	startup_tree_task = Startup.begin("Terrain supports")
	_repair_tree_trunks.call_deferred()
	move_to_review_point(0)
	last_safe_position = player.position
	var river_dynamics:=preload('res://world/suryagarh/river_dynamics.gd').new()
	add_child(river_dynamics)
	await Startup.checkpoint(self, "Preparing life in Suryagarh…")
	var errands := preload("res://world/suryagarh/errands/errand_system.gd").new()
	errands.name = "ErrandSystem"
	add_child(errands)
	await Startup.checkpoint(self, "Preparing life in Suryagarh…")
	preload("res://world/suryagarh/settlements/asset_first_placement.gd").new().integrate(self)
	await Startup.checkpoint(self, "Preparing life in Suryagarh…")
	var combat_encounters := preload("res://world/suryagarh/combat_encounters.gd").new()
	combat_encounters.name="CombatEncounters"
	add_child(combat_encounters)
	await Startup.checkpoint(self, "Preparing life in Suryagarh…")
	add_child(preload("res://world/suryagarh/city_route_population.gd").new())
	await Startup.checkpoint(self, "Preparing life in Suryagarh…")
	add_child(preload("res://world/suryagarh/settlements/village_daily_activities.gd").new())
	await Startup.checkpoint(self, "Preparing life in Suryagarh…")
	add_child(preload("res://world/suryagarh/settlements/civic_resident_posts.gd").new())
	await Startup.checkpoint(self, "Preparing life in Suryagarh…")
	add_child(preload("res://world/suryagarh/settlements/draft_animal_yards.gd").new())
	await Startup.checkpoint(self, "Preparing life in Suryagarh…")
	var muddy_roads:=preload("res://world/suryagarh/muddy_road_travel.gd").new()
	muddy_roads.name="MuddyRoadTravel";add_child(muddy_roads)
	await Startup.checkpoint(self, "Preparing life in Suryagarh…")
	add_child(preload("res://world/suryagarh/sky_birds.gd").new())
	await Startup.checkpoint(self, "Preparing life in Suryagarh…")
	add_child(preload("res://world/suryagarh/settlements/chacha_house.gd").new())
	await Startup.checkpoint(self, "Preparing life in Suryagarh…")
	add_child(preload("res://story/dev_inquiry.gd").new())
	await Startup.checkpoint(self, "Preparing life in Suryagarh…")
	add_child(preload("res://world/suryagarh/settlements/story_community.gd").new())
	await Startup.checkpoint(self, "Preparing life in Suryagarh…")
	add_child(preload("res://story/dev_story.gd").new())
	await Startup.checkpoint(self, "Preparing life in Suryagarh…")
	await Startup.wait_others(self, startup_task)
	Startup.finish(startup_task)
	SaveManager.call_deferred("apply_pending",self)
	print("SURYAGARH READY | 1728 x 1728 m | 8 GB memory target | surface swimming enabled")

func move_to_review_point(index: int) -> void:
	review_index = posmod(index, REVIEW_POINTS.size())
	var p: Vector2 = REVIEW_POINTS[review_index]
	player.position = Vector3(p.x, layout.height(p.x,p.y)+1.1, p.y)
	player.velocity = Vector3.ZERO
	player.rotation.y = -PI * 0.5 if REVIEW_NAMES[review_index] == "Forest biome patch" else -0.85
	player.camera_pitch = deg_to_rad(-10.0)
	player.get_node("CameraPivot").rotation.x = player.camera_pitch
	location_label.text = "SURYAGARH  /  " + REVIEW_NAMES[review_index] + "\nLandscape foundation · 2.986 km²"

func _unhandled_key_input(event: InputEvent) -> void:
	if player.get_meta("map_open", false) or player.has_meta("mounted_vehicle") or player.get_meta("climbing",false): return
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
	if $HooghlyPort.is_dry_ship_interior(p): deep_enough = false
	var entry_height := 0.65 if player.is_swimming else 0.3
	player.set_meta('river_current',preload('res://world/suryagarh/river_dynamics.gd').current_at(p) if deep_enough else Vector3.ZERO)
	player.set_water_state(deep_enough and p.y < Layout.WATER_LEVEL + entry_height, Layout.WATER_LEVEL)

func _repair_tree_trunks() -> void:
	await Startup.wait_for(self, "Terrain collision")
	await get_tree().physics_frame
	await preload("res://world/suryagarh/tree_trunk_collision.gd").repair_landscape($Landscape)
	Startup.finish(startup_tree_task)
