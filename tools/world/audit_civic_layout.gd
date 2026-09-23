extends SceneTree
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const OUT := "res://docs/world/civic_layout_audit.json"
var layout := Layout.new()
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("audit")

func require(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func audit() -> void:
	var plots: Dictionary = {}
	for name in Layout.PLOTS:
		var plot: Dictionary = Layout.PLOTS[name]
		var center: Vector2 = plot.center
		var half: Vector2 = plot.half
		var heights: Array[float] = []
		for sx in [-1.0,0.0,1.0]:
			for sz in [-1.0,0.0,1.0]:
				var p := center+Vector2(sx*half.x,sz*half.y)
				heights.append(layout.height(p.x,p.y))
				require(layout.built_area(p.x,p.y),name+" has an unreserved footprint sample")
		var spread: float = heights.max()-heights.min()
		require(spread < 0.12,name+" terrain grade varies by "+str(spread)+" m")
		plots[name] = {"center":center,"half_extent":half,"grade_m":plot.grade,"grade_spread_m":spread}
	var routes: Dictionary = {}
	for name in Layout.ROUTES:
		var path: Array = Layout.ROUTES[name]
		var length_m := 0.0
		var worst_slope := 0.0
		for i in range(path.size()-1):
			var a: Vector2 = path[i]
			var b: Vector2 = path[i+1]
			var steps := ceili(a.distance_to(b)/2.0)
			var previous := a
			for step in range(1,steps+1):
				var point: Vector2 = a.lerp(b,float(step)/steps)
				var rise := absf(layout.height(point.x,point.y)-layout.height(previous.x,previous.y))
				worst_slope = maxf(worst_slope,rise/point.distance_to(previous))
				require(layout.road_distance(point.x,point.y)<0.02,name+" missing from shared road mask")
				previous = point
			length_m += a.distance_to(b)
		var elevations: Array[float] = []
		for point in path: elevations.append(layout.height(point.x,point.y))
		routes[name] = {"length_m":length_m,"maximum_terrain_slope":worst_slope,"waypoint_elevations_m":elevations}
		require(worst_slope < 0.24,name+" has a terrain slope above 24%: "+str(worst_slope))
	# Access endpoints are explicit and auditable; subsequent route expansion must
	# preserve these connections and can add branches without moving existing plots.
	require(Layout.ROUTES["east_bridge"][2]==Layout.ROUTES["police_to_compound"][0],"Police route is disconnected from eastern bridge")
	require(Layout.ROUTES["police_to_compound"][2]==Layout.ROUTES["compound_court"][0],"Compound gate is disconnected")
	var entrances: Dictionary = {}
	for name in ["TownHall","DistrictPolice"]:
		var plot: Dictionary = Layout.PLOTS[name]
		var centre: Vector2 = plot.center
		var depth := 28.0 if name=="TownHall" else 24.0
		var start_z: float = centre.y+depth*0.5+4.0
		var end_z: float = centre.y+depth*0.5+(24.0 if name=="TownHall" else 18.0)
		var floor_y: float = plot.grade+0.45-0.04
		var end_y: float = layout.height(centre.x,end_z)
		var minimum_clearance := INF
		var maximum_slope := 0.0
		var previous_y := floor_y
		var steps: int = int(end_z-start_z)
		for step in steps+1:
			var t := float(step)/steps
			var z := lerpf(start_z,end_z,t)
			var deck := maxf(lerpf(floor_y,end_y,t),layout.height(centre.x,z)+.06)
			minimum_clearance = minf(minimum_clearance,deck-layout.height(centre.x,z))
			if step>0: maximum_slope = maxf(maximum_slope,absf(deck-previous_y))
			previous_y = deck
		require(minimum_clearance>=-0.01,name+" approach is buried by terrain")
		require(maximum_slope<=0.27,name+" approach rises too sharply over 1 m")
		entrances[name] = {"minimum_ramp_clearance_m":minimum_clearance,"maximum_ramp_slope":maximum_slope}
	var report := {"status":"PASS" if failures.is_empty() else "FAIL","layout_size_m":Layout.SIZE,"plots":plots,"routes":routes,"entrances":entrances,"failures":failures}
	var file := FileAccess.open(OUT,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	print("CIVIC LAYOUT AUDIT ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
