extends SceneTree
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const Reference = preload("res://tools/world/layout_height_reference.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var current := Layout.new()
	var reference := Reference.new()
	var points: Array[Vector2] = []
	for x in range(-864,865,12):
		for z in range(-864,865,12): points.append(Vector2(x,z))
	for lane in Layout.GRADED_LANES:
		var route: Array = Layout.ROUTES[lane]
		for index in route.size()-1:
			var a: Vector2 = route[index]
			var b: Vector2 = route[index+1]
			var normal := (b-a).normalized().orthogonal()
			for step in 21:
				for offset in [-9.001,-9.0,-8.999,-3.001,-3.0,-2.999,0.0,2.999,3.0,3.001,8.999,9.0,9.001]:
					points.append(a.lerp(b,step/20.0)+normal*offset)
	for bounds in current.graded_lane_bounds + current.graded_plot_bounds:
		for x in [bounds.position.x-.001,bounds.position.x,bounds.end.x,bounds.end.x+.001]:
			for z in [bounds.position.y-.001,bounds.position.y,bounds.end.y,bounds.end.y+.001]: points.append(Vector2(x,z))
	for plot in Layout.PLOTS.values():
		for distance in [0.0,11.0,21.999,22.0,22.001]:
			for side in [-1.0,1.0]:
				points.append(plot.center+Vector2(side*(plot.half.x+distance),0))
				points.append(plot.center+Vector2(0,side*(plot.half.y+distance)))
	var maximum_error := 0.0
	for point in points:
		maximum_error = maxf(maximum_error,absf(current.height(point.x,point.y)-reference.height(point.x,point.y)))
	var old_times: Array[int] = []
	var new_times: Array[int] = []
	var checksum := 0.0
	for round_index in 5:
		for variant in ([0,1] if round_index%2==0 else [1,0]):
			var sampler = reference if variant==0 else current
			var start := Time.get_ticks_usec()
			for point in points: checksum += sampler.height(point.x,point.y)
			(old_times if variant==0 else new_times).append(Time.get_ticks_usec()-start)
	old_times.sort()
	new_times.sort()
	var passed := maximum_error < .0000001
	if not passed: push_error("Terrain height changed by %s metres" % maximum_error)
	print("TERRAIN QUERY BUDGET ",JSON.stringify({"status":"PASS" if passed else "FAIL","points":points.size(),"max_height_error_m":maximum_error,"reference_us":old_times[2],"bounded_us":new_times[2],"checksum":checksum,"scope":"world grid, lane falloff and query bounds parity; same-run terrain query cost"}))
	await root.get_node("SaveManager").quit_game(0 if passed else 1)
