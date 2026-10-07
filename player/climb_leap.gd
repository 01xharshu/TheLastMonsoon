extends RefCounted
## Wall-relative launch/catch choreography. Each launch resolves a reachable layer.
var c: Node
var phase := "catch"
var clock := 0.0
var held_row := 0
var target_row := 0
var from := Vector3.ZERO
var to := Vector3.ZERO
var launches := 0
var flight_seconds := .58
var lateral_transfer := false
var lateral_grip := Vector3.ZERO

func begin(component: Node) -> void:
	c = component
	held_row = c.first_hand_row
	target_row = held_row
	phase = "catch"
	lateral_transfer = false
	clock = 0.0
	from = c.start
	to = c.hang_grip

func request() -> bool:
	if phase != "hang": return false
	var sideways := Input.get_axis("move_left","move_right")
	if absf(sideways) > .5:
		var edge: Dictionary = c.opportunities.side_grip(c,sideways)
		if edge.is_empty(): return false
		lateral_transfer = true
		lateral_grip = edge.point
		target_row = held_row
		from = c.actor.global_position
		to = c.outside_architecture(lateral_grip+c.wall_normal*.36-Vector3.UP*.78)
		return launch_checked()
	lateral_transfer = false
	if held_row >= (c.hold_rows if c.layers.is_empty() else c.layers.size()-1) or c._hold(held_row,"l",false,Vector3.UP.cross(c.wall_normal)).y >= c.landing.y-.99:
		phase = "mantle"
		c.crest = c.actor.global_position
		c.progress = .78
		c.move_limit = 1.0
		c.duration = 8.0
		c.waiting_for_move = false
		return true
	# Prefer a leap across a layer; never target a missing or unreachable stone.
	var candidate := -1
	var best := -INF
	var tangent := Vector3.UP.cross(c.wall_normal).normalized()
	var origin: Vector3 = c._hold(held_row,"l",false,tangent)
	for row in range(held_row+1,c.hold_rows+1 if c.layers.is_empty() else c.layers.size()):
		if row in c.route_missing_rows: continue
		var point: Vector3 = c._hold(row,"l",false,tangent)
		var rise: float = point.y-origin.y
		var lateral: float = (point-origin).dot(tangent)
		if rise < -.05 or rise > 1.25 or absf(lateral) > 1.0: continue
		if (point-origin).length() > 1.5: continue
		var score: float = rise-absf(lateral)*.3
		if absf(sideways) > .5:
			if lateral*sideways <= .1: continue
			score = absf(lateral)-rise*.25
		elif rise < .05: continue
		if score > best: best = score; candidate = row
	if candidate < 0: return false
	target_row = candidate
	from = c.actor.global_position
	to = c.wall_point+c.wall_normal*.36
	to.y = c._hold(target_row,"l",false,Vector3.UP.cross(c.wall_normal)).y-.90
	if not c.layers.is_empty():
		to = c.layers[target_row]+c.wall_normal*.36-Vector3.UP*.78
		to = c.outside_architecture(to)
	return launch_checked()

func launch_checked() -> bool:
	# Sweep the outward launch arc as well as its endpoint.
	var previous := from
	for sample in range(1,13):
		var point := flight(float(sample)/12.0)
		if not c.solid.can_move(c.actor,previous,point,1.6): return false
		previous = point
	phase = "load"
	clock = 0.0
	c.waiting_for_move = false
	return true

func flight(u: float) -> Vector3:
	var t := u*flight_seconds
	var velocity_y: float = (to.y-from.y+.5*c.actor.gravity*flight_seconds*flight_seconds)/flight_seconds
	var point := from.lerp(to,u)
	point.y = from.y+velocity_y*t-.5*c.actor.gravity*t*t
	return point+c.wall_normal*sin(PI*u)*.16

func advance(delta: float) -> void:
	if phase == "mantle": return
	if phase == "hang":
		c.waiting_for_move = true
		return
	var before := clock
	clock += delta
	var destination: Vector3 = c.actor.global_position
	match phase:
		"catch": destination = from.lerp(to,smoothstep(0,.32,clock))
		"load": destination = from+c.wall_normal*sin(clampf(clock/.24,0,1)*PI)*.10-Vector3.UP*sin(clampf(clock/.24,0,1)*PI)*.06
		"flight": destination = flight(clampf(clock/flight_seconds,0,1))
		"settle": destination = to-Vector3.UP*sin(clampf(clock/.26,0,1)*PI)*.045
	if not c.solid.move_to(c.actor,destination,1.6):
		clock = before
		# An interrupted airborne jump loses its catch instead of freezing in air.
		if phase == "flight": c.release_grip()
		return
	if phase == "load" and clock >= .24:
		phase = "flight"
		clock = 0.0
		launches += 1
	elif phase == "flight" and clock >= flight_seconds:
		held_row = target_row
		if lateral_transfer:
			var displacement: Vector3 = lateral_grip-c.layers[held_row]
			c.layers[held_row] = lateral_grip
			c.landing += displacement
		phase = "settle"
		clock = 0.0
	elif (phase == "catch" and clock >= .32) or (phase == "settle" and clock >= .26):
		phase = "hang"
		clock = 0.0
		c.waiting_for_move = true
	c.progress = .14 if phase == "catch" else .28

func contact(side: String, foot: bool) -> Vector3:
	var row := held_row
	if lateral_transfer and phase == "flight" and not foot:
		return lateral_grip+Vector3.UP.cross(c.wall_normal).normalized()*(.24 if side == "r" else -.24)
	if phase == "flight": row = target_row
	if foot:
		if c.layers.is_empty(): row = maxi(0,floori(float(row)-1.60/c.hold_spacing))
		else:
			var wanted: float = c.layers[clampi(row,0,c.layers.size()-1)].y-1.60
			row = 0
			for index in c.layers.size():
				if c.layers[index].y <= wanted: row = index
		while row in c.route_missing_rows and row > 0: row -= 1
	return c._hold(row,side,foot,Vector3.UP.cross(c.wall_normal).normalized())

func weight(foot := false) -> float:
	if foot and not c.layers.is_empty():
		var supported := false
		for layer in c.layers:
			if layer.y <= c.layers[clampi(held_row,0,c.layers.size()-1)].y-1.60 and Vector2(layer.x-c.actor.global_position.x,layer.z-c.actor.global_position.z).length() < .65: supported = true; break
		if not supported: return 0.0
	match phase:
		"flight": return 0.0
		"catch": return smoothstep(.10,.30,clock)
		"settle": return smoothstep(.12,.26,clock) if foot else smoothstep(0,.18,clock)
		"load": return 1.0-smoothstep(.10,.24,clock) if foot else 1.0
	return 1.0

func pose() -> float:
	match phase:
		"load": return .18
		"flight": return lerpf(.40,.65,smoothstep(.35,.58,clock))
		"settle": return lerpf(.65,.14,smoothstep(0,.26,clock))
	return .14
