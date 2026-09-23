extends DirectionalLight3D
## Sun, moon, sky, ambient light and fog share the same continuous world clock.
@export var daytime_sun_energy := 1.0
@export var nighttime_sun_energy := 0.0
@export var sun_azimuth_degrees := -30.0
@export var maximum_moon_energy := 0.18
@onready var game_time: GameTimeSystem = $"../GameTimeSystem"
@onready var moon: DirectionalLight3D = $"../Moon"
var environment: Environment
var sky_material: ProceduralSkyMaterial

func _ready() -> void:
	var world_environment := get_node_or_null("../WorldEnvironment") as WorldEnvironment
	if world_environment and world_environment.environment:
		environment = world_environment.environment.duplicate(true)
		world_environment.environment = environment
		if environment.sky and environment.sky.sky_material is ProceduralSkyMaterial:
			sky_material = environment.sky.sky_material
	shadow_enabled = true
	_update_day_night_lighting()

func _process(_delta: float) -> void:
	_update_day_night_lighting()

func _update_day_night_lighting() -> void:
	if game_time == null or moon == null: return
	var fraction := game_time.get_time_of_day_fraction()
	var elevation := sin((fraction - 0.25) * TAU)
	rotation_degrees = Vector3(90.0 - fraction * 360.0, sun_azimuth_degrees, 0)
	moon.rotation_degrees = Vector3(rotation_degrees.x + 180.0, sun_azimuth_degrees, 0)
	light_energy = lerpf(nighttime_sun_energy, daytime_sun_energy, smoothstep(0.0, 0.65, elevation))
	moon.light_energy = maximum_moon_energy * smoothstep(0.0, 0.5, -elevation)
	light_color = Color(1.0, 0.52, 0.27).lerp(Color(1.0, 0.95, 0.84), smoothstep(0.0, 0.45, elevation))
	var daylight := smoothstep(-0.18, 0.3, elevation)
	var twilight := (1.0 - smoothstep(0.0, 0.3, absf(elevation))) * 0.6
	var horizon := Color(0.035, 0.05, 0.095).lerp(Color(0.66, 0.7, 0.67), daylight)
	horizon = horizon.lerp(Color(0.65, 0.32, 0.19), twilight)
	if environment:
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color(0.32, 0.42, 0.65).lerp(Color(0.65, 0.72, 0.78), daylight)
		environment.ambient_light_energy = lerpf(0.10, 0.55, daylight)
		environment.fog_light_color = horizon
		environment.fog_light_energy = lerpf(0.12, 0.65, daylight)
	if sky_material:
		sky_material.sky_top_color = Color(0.006, 0.012, 0.035).lerp(Color(0.24, 0.36, 0.43), daylight)
		sky_material.sky_horizon_color = horizon
		sky_material.ground_horizon_color = horizon
		sky_material.ground_bottom_color = Color(0.012, 0.017, 0.026).lerp(Color(0.19, 0.22, 0.16), daylight)
