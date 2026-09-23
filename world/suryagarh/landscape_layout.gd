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
## Surveyed plot centres and footprint half-extents. Keep building placement, grading,
## nature clearance and the map tied to these coordinates as the world grows.
const PLOTS: Dictionary = {
	"Bhairavpur": {"center": Vector2(-310, 230), "half": Vector2(45, 32), "grade": 7.2},
	"TownHall": {"center": Vector2(-320, -470), "half": Vector2(27, 16), "grade": 8.0},
	"DistrictPolice": {"center": Vector2(320, 120), "half": Vector2(20, 22), "grade": 10.0},
	"CompanyCompound": {"center": Vector2(345, 300), "half": Vector2(67, 63), "grade": 12.0},
}
## Each spur ends at an actual entrance or joins another route. A road endpoint
## may terminate at a doorstep, but cannot silently stop inside a building.
const ROUTES: Dictionary = {
	"town_hall": [Vector2(-240, -470), Vector2(-275, -432), Vector2(-320, -432)],
	"east_bridge": [Vector2(273, 165), Vector2(300, 165), Vector2(320, 150)],
	"police_to_compound": [Vector2(320, 150), Vector2(345, 234), Vector2(345, 252)],
	"compound_court": [Vector2(345, 252), Vector2(345, 301)],
	"compound_stores": [Vector2(345, 275), Vector2(376, 298)],
}
const SITES: Dictionary = {
	"Bhairavpur village": Vector2(-310, 230),
	"Agricultural plains": Vector2(-390, -90),
	"River approach": Vector2(0, 165),
	"Trading settlement reserve": Vector2(-320, -470),
	"Company compound": Vector2(340, 290),
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
	return 55.0 + 8.0 * sin(z * 0.008 + 1.0)

func road_x(z: float) -> float:
	return -210.0 + 42.0 * sin(z * 0.005)

func hill(x: float, z: float, cx: float, cz: float, rx: float, rz: float, h: float) -> float:
	return h * exp(-pow((x - cx) / rx, 2.0) - pow((z - cz) / rz, 2.0))

func height(x: float, z: float) -> float:
	var h := base_height(x,z)
	# The hall spur is a surveyed walking grade. Its centre follows the terrain
	# at the route vertices and cuts/fills only a narrow corridor between them.
	if x > -330.0 and x < -235.0 and z > -476.0 and z < -426.0:
		var route: Array = ROUTES["town_hall"]
		var point := Vector2(x,z)
		var nearest := INF
		var target := h
		for i in range(route.size()-1):
			var a: Vector2 = route[i]
			var b: Vector2 = route[i+1]
			var ab: Vector2 = b-a
			var t := clampf((point-a).dot(ab)/ab.length_squared(),0.0,1.0)
			var d := point.distance_to(a+ab*t)
			if d < nearest:
				nearest = d
				target = lerpf(base_height(a.x,a.y),base_height(b.x,b.y),t)
		h = lerpf(h,target,1.0-smoothstep(2.0,7.0,nearest))
	# The hall's final fourteen metres meet its raised porch at a steady grade.
	# This prevents the entrance ramp from diving below the terrain mid-span.
	if x > -327.0 and x < -313.0 and z >= -452.0 and z <= -432.0:
		var t := (z+452.0)/20.0
		var target := lerpf(PLOTS["TownHall"].grade,base_height(-320.0,-432.0),t)
		h = lerpf(h,target,1.0-smoothstep(3.0,7.0,absf(x+320.0)))
	return h

func base_height(x: float, z: float) -> float:
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
	for plot in PLOTS.values():
		if plot.center == Vector2(-310, 230): continue
		var edge: float = maxf(absf(x-plot.center.x)-plot.half.x, absf(z-plot.center.y)-plot.half.y)
		h = lerpf(h, plot.grade, 1.0-smoothstep(0.0, 22.0, edge))
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
	var distance: float = minf(main, lane)
	var point := Vector2(x,z)
	for route in ROUTES.values():
		for i in range(route.size()-1):
			distance = minf(distance, segment_distance(point, route[i], route[i+1]))
	return distance

func segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b-a
	return point.distance_to(a+ab*clampf((point-a).dot(ab)/ab.length_squared(),0.0,1.0))

func plot_clearance(x: float,z: float) -> float:
	var distance := INF
	for plot in PLOTS.values():
		var dx: float = maxf(absf(x-plot.center.x)-plot.half.x,0.0)
		var dz: float = maxf(absf(z-plot.center.y)-plot.half.y,0.0)
		distance = minf(distance,Vector2(dx,dz).length())
	return distance

func field_mask(x: float, z: float) -> float:
	return (1.0 - smoothstep(-125.0, -80.0, x)) * smoothstep(-730.0, -660.0, x) * (1.0 - smoothstep(470.0, 570.0, absf(z)))

func built_area(x: float,z: float) -> bool:
	return plot_clearance(x,z) < 8.0 or (absf(z-235)<5 and x>river_x(z)-river_width(z)-50 and x<river_x(z)-river_width(z)+8)
