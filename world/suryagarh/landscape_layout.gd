class_name SuryagarhLayout
extends RefCounted
const FortShape = preload("res://world/ruined_fort/fort_shape.gd")
const FORT_CENTER := Vector2(520.0, -350.0)
const FORT_BASE_HEIGHT := 120.0
const FORT_ACCESS_GRADES := [109.8, 112.1, 117.5, 120.0]
const FORT_TRAIL_GRADES := [10.5, 13.7, 31.3, 38.0, 42.0, 46.0, 56.0, 68.0, 76.0, 79.5, 82.0, 89.0, 93.0, 98.5, 109.8]
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
	"GovernmentHouse": {"center": Vector2(-390, -110), "half": Vector2(96, 92), "grade": 8.5},
	"OldFort": {"center": FORT_CENTER, "half": Vector2(60, 50), "grade": FORT_BASE_HEIGHT},
}
## Each spur ends at an actual entrance or joins another route. A road endpoint
## may terminate at a doorstep, but cannot silently stop inside a building.
const ROUTES: Dictionary = {
	"town_hall": [Vector2(-240, -470), Vector2(-275, -432), Vector2(-320, -432)],
	"east_bridge": [Vector2(273, 165), Vector2(300, 165), Vector2(320, 150)],
	"police_to_compound": [Vector2(320, 150), Vector2(345, 234), Vector2(345, 252)],
	"compound_court": [Vector2(345, 252), Vector2(345, 301)],
	"compound_stores": [Vector2(345, 275), Vector2(376, 298)],
	"government_house_road": [Vector2(-214, -18), Vector2(-300, -18), Vector2(-390, -18)],
	"government_house_avenue": [Vector2(-390, -18), Vector2(-390, -123)],
	"fort_trail": [Vector2(320, 150), Vector2(380, 90), Vector2(460, 10), Vector2(480, 0), Vector2(490, -10), Vector2(500, -20), Vector2(520, -50), Vector2(510, -120), Vector2(550, -140), Vector2(550, -170), Vector2(510, -170), Vector2(480, -180), Vector2(490, -200), Vector2(510, -230), Vector2(465, -250)],
	"fort_access": [Vector2(465, -250), Vector2(565, -255), Vector2(460, -283), Vector2(520, -303)],
}
const SITES: Dictionary = {
	"Bhairavpur village": Vector2(-310, 230),
	"Agricultural plains": Vector2(-540, -90),
	"River approach": Vector2(0, 165),
	"Trading settlement reserve": Vector2(-320, -470),
	"Company compound": Vector2(340, 290),
	"Old fort reserve": FORT_CENTER,
	"Government House": Vector2(-390, -110),
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
	# Follow a surveyed, gently graded mountain trail from the east bridge road.
	if x > 306.0 and x < 566.0 and z > -266.0 and z < 164.0:
		var trail: Array = ROUTES["fort_trail"]
		var trail_point := Vector2(x,z)
		var nearest_trail := INF
		var trail_target := h
		for i in range(trail.size()-1):
			var a: Vector2 = trail[i]
			var b: Vector2 = trail[i+1]
			var ab: Vector2 = b-a
			var t: float = clampf((trail_point-a).dot(ab)/ab.length_squared(),0.0,1.0)
			var dist: float = trail_point.distance_to(a+ab*t)
			if dist < nearest_trail:
				nearest_trail = dist
				trail_target = lerpf(FORT_TRAIL_GRADES[i],FORT_TRAIL_GRADES[i+1],t)
		h = lerpf(h,trail_target,1.0-smoothstep(3.0,14.0,nearest_trail))
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
		if plot.center == Vector2(-310, 230) or plot.center == FORT_CENTER: continue
		var edge: float = maxf(absf(x-plot.center.x)-plot.half.x, absf(z-plot.center.y)-plot.half.y)
		h = lerpf(h, plot.grade, 1.0-smoothstep(0.0, 22.0, edge))
	# The residence's east-west carriage road eases into its surveyed terrace.
	if x > -294.0 and x <= -214.0 and absf(z+18.0) < 11.0:
		var t := (x+294.0)/80.0
		var target := lerpf(PLOTS["GovernmentHouse"].grade,6.4,t)
		h = lerpf(h,target,1.0-smoothstep(3.0,11.0,absf(z+18.0)))
	# Native world terrain is the fort floor: no second overlapping terrain sheet.
	var local_x: float = x - FORT_CENTER.x
	var local_z: float = z - FORT_CENTER.y
	var fort_edge: float = maxf(absf(local_x) - 60.0, absf(local_z) - 50.0)
	var fort_weight: float = 1.0 - smoothstep(0.0, 120.0, fort_edge)
	if fort_weight > 0.0:
		h = lerpf(h, FORT_BASE_HEIGHT + FortShape.height_at(clampf(local_x,-60.0,60.0), clampf(local_z,-50.0,50.0)), fort_weight)
	# A winding cut-and-fill dirt approach keeps the hill entrance walkable.
	if x > 438.0 and x < 587.0 and z > -323.0 and z < -228.0:
		var road: Array = ROUTES["fort_access"]
		var weighted_height := 0.0
		var total_weight := 0.0
		var nearest_road := INF
		var sample := Vector2(x,z)
		for i in range(road.size()-1):
			var a: Vector2 = road[i]
			var b: Vector2 = road[i+1]
			var ab: Vector2 = b-a
			var t: float = clampf((sample-a).dot(ab)/ab.length_squared(),0.0,1.0)
			var road_dist: float = sample.distance_to(a+ab*t)
			nearest_road = minf(nearest_road,road_dist)
			var weight: float = exp(-road_dist*road_dist/85.0)
			weighted_height += lerpf(FORT_ACCESS_GRADES[i],FORT_ACCESS_GRADES[i+1],t)*weight
			total_weight += weight
		if total_weight > 0.0001:
			h = lerpf(h,weighted_height/total_weight,1.0-smoothstep(4.0,21.0,nearest_road))
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
