class_name SuryagarhLayout
extends RefCounted
## Metres, Y-up. Stable deterministic source shared by baking, runtime and validation.
const SIZE: float = 1728.0
const HALF: float = SIZE / 2.0
const TILE: float = 144.0
const GRID: int = 48
const STEP: float = TILE / GRID
const WATER_LEVEL: float = 0.0
const SPAWN: Vector2 = Vector2(-230.0, 180.0)
const SITES: Dictionary = {
	"Bhairavpur reserve": Vector2(-310, 230),
	"Agricultural plains": Vector2(-390, -90),
	"River approach": Vector2(0, 165),
	"Trading settlement reserve": Vector2(-320, -470),
	"Cantonment reserve": Vector2(340, 290),
	"Old fort reserve": Vector2(510, -390),
	"Wooded ridge": Vector2(620, -260),
}
var noise := FastNoiseLite.new()

func _init() -> void:
	noise.seed = 1857
	noise.frequency = 0.005
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.46

func river_x(z: float) -> float:
	return 60.0 + 76.0 * sin(z * 0.0045) + 22.0 * sin(z * 0.011)

func river_width(z: float) -> float:
	return 25.0 + 5.0 * sin(z * 0.008 + 1.0)

func road_x(z: float) -> float:
	return -210.0 + 42.0 * sin(z * 0.005)

func hill(x: float, z: float, cx: float, cz: float, rx: float, rz: float, h: float) -> float:
	return h * exp(-pow((x - cx) / rx, 2.0) - pow((z - cz) / rz, 2.0))

func height(x: float, z: float) -> float:
	var n: float = noise.get_noise_2d(x, z)
	var h: float = 7.0 + n * 7.0 + 1.7 * sin(x * 0.012) * cos(z * 0.009)
	var upland: float = hill(x, z, 570, -440, 250, 380, 126)
	upland += hill(x, z, 770, 120, 175, 260, 74)
	upland += hill(x, z, -760, -650, 210, 230, 47)
	upland *= 1.0 + n * 0.5
	h += upland
	# Continuous channel and smooth banks; the water surface stays level.
	var d: float = absf(x - river_x(z))
	var channel: float = -4.5 + 0.65 * sin(z * 0.023)
	var bank: float = smoothstep(river_width(z) - 9.0, river_width(z) + 37.0, d)
	h = lerpf(channel, h, bank)
	# Flatten the village reserve gently without creating an abrupt shelf.
	var village: float = 1.0 - smoothstep(58.0, 130.0, Vector2(x + 310, z - 230).length())
	h = lerpf(h, 7.2, village)
	return h

func normal(x: float, z: float) -> Vector3:
	return Vector3(height(x - 1.0, z) - height(x + 1.0, z), 2.0,
		height(x, z - 1.0) - height(x, z + 1.0)).normalized()

func road_distance(x: float, z: float) -> float:
	var main: float = absf(x - road_x(z))
	# A lane linking the village/plain road to the west riverbank.
	var lane: float = absf(z - (160.0 + 12.0 * sin(x * 0.017)))
	if x < -280.0 or x > river_x(z) - river_width(z) - 18.0:
		lane = 10000.0
	return minf(main, lane)

func field_mask(x: float, z: float) -> float:
	return (1.0 - smoothstep(-125.0, -80.0, x)) * smoothstep(-730.0, -660.0, x) * (1.0 - smoothstep(470.0, 570.0, absf(z)))
