extends "res://world/suryagarh/landscape_layout.gd"
## Pre-bounds terrain sampler retained only for parity and cost validation.
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
		var police: Dictionary = PLOTS["DistrictPolice"]
		var police_edge: float = maxf(absf(x-police.center.x)-police.half.x,absf(z-police.center.y)-police.half.y)
		var clear_of_police: float = smoothstep(0.0,8.0,maxf(0.0,police_edge))
		# Adjacent switchbacks must keep their own full-width walking grade.
		# The descending trail used to overwrite the higher access strip here.
		var clear_of_access := 1.0
		if x > 438.0 and x < 587.0 and z > -273.0 and z < -228.0:
			var access_distance := INF
			var access: Array = ROUTES["fort_access"]
			for i in range(access.size()-1):
				access_distance = minf(access_distance,segment_distance(trail_point,access[i],access[i+1]))
			clear_of_access = smoothstep(3.5,8.0,access_distance)
		h = lerpf(h,trail_target,(1.0-smoothstep(3.0,14.0,nearest_trail))*clear_of_police*clear_of_access)
	if z > 492.0 and z < 658.0 and x > -218.0 and x < -170.0:
		var route: Array = ROUTES["port_approach"]
		var point := Vector2(x,z)
		var nearest := INF
		var target := h
		for i in range(route.size()-1):
			var a: Vector2 = route[i]
			var b: Vector2 = route[i+1]
			var t := clampf((point-a).dot(b-a)/(b-a).length_squared(),0.0,1.0)
			var d := point.distance_to(a.lerp(b,t))
			if d < nearest:
				nearest = d
				target = lerpf(base_height(a.x,a.y),base_height(b.x,b.y),t)
		h = lerpf(h,target,1.0-smoothstep(3.0,9.0,nearest))
	# Surveyed residential avenue cuts through the ridge at the office grade.
	# Market access meets the military terrace without a step in the saved terrain.
	for id in ["civil_lines_avenue","collector_bungalow_drive","officer_bungalow_drive","cantonment_bazaar_lane"]:
		var lane: Array = ROUTES[id]
		var lane_distance := INF
		for i in range(lane.size()-1): lane_distance = minf(lane_distance,segment_distance(Vector2(x,z),lane[i],lane[i+1]))
		h = lerpf(h,8.5 if id == "cantonment_bazaar_lane" else 10.0,1.0-smoothstep(3.0,9.0,lane_distance))
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
	var channel: float = -4.5 + 0.65 * sin(z * 0.023) - 8.0 * smoothstep(500.0,850.0,z)
	var bank: float = smoothstep(river_width(z) - 9.0, river_width(z) + 37.0, d)
	h = lerpf(channel, h, bank)
	# A shared surveyed terrace supports the expanded houses, market and fields.
	var village_plot: Dictionary = PLOTS["Bhairavpur"]
	var village_edge: float = maxf(absf(x-village_plot.center.x)-village_plot.half.x, absf(z-village_plot.center.y)-village_plot.half.y)
	var village: float = 1.0 - smoothstep(0.0, 30.0, village_edge)
	h = lerpf(h, 7.2, village)
	for plot in PLOTS.values():
		if plot.center == village_plot.center or plot.center == FORT_CENTER: continue
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

