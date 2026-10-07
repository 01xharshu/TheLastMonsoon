extends Node
## Jump catch and deliberate hold transfers on authored masonry; solid mantles.
@onready var actor: CharacterBody3D = get_parent()
var active := false
var progress := 0.0
var duration := 2.4
var start := Vector3.ZERO
var crest := Vector3.ZERO
var grip := Vector3.ZERO
var hang_grip := Vector3.ZERO
var landing := Vector3.ZERO
var saved_mask: int
var wall_normal := Vector3.ZERO
var wall_point := Vector3.ZERO
var hold_base_y := 0.0
var hold_center_z := 0.0
var has_holds := false
var ascent_steps := 1
var step_index := 0
var step_phase := 0.0
var first_hand_row := 0
var first_foot_row := 0
var hold_spacing := .40
var hold_rows := 11
var solid := preload("res://player/climb_collision.gd").new()
var catch_seconds := 0.0
var launch_y := 0.0
var waiting_for_move := false
var move_limit := .14
var route_missing_rows: Array = []
var releasing := false
var release_velocity := Vector3.ZERO
var leap := preload("res://player/climb_leap.gd").new()
var leap_active := false
var window_committed := false
var layers: Array[Vector3] = []
var opportunities := preload("res://player/climb_opportunities.gd").new()

func arm_jump() -> void:
	catch_seconds = 1.2
	launch_y = actor.global_position.y

func request_move() -> bool:
	if not active or not waiting_for_move: return false
	if window.active:
		window_committed = true
		waiting_for_move = false
		return true
	if leap_active: return leap.request()
	var next_limit: float
	if progress < .15:
		next_limit = .20
	elif progress < .78-.0001:
		next_limit = minf(.78, move_limit + .58 / ascent_steps)
	else:
		next_limit = 1.0
	# Never animate a grip on a missing stone or above the final row.
	if progress < .78-.0001:
		var next_step := mini(ascent_steps-1, roundi(maxf(0.0,progress-.20)/.58*ascent_steps))
		var next_row := first_hand_row + next_step/2 + 1
		var next_foot_row := first_foot_row + next_step/2 + 1
		if next_row in route_missing_rows or next_foot_row in route_missing_rows: return false
		if next_row >= hold_rows and landing.y-.94 > hold_base_y+(hold_rows-1)*hold_spacing+hold_spacing+.12: return false
	move_limit = next_limit
	waiting_for_move = false
	return true

func release_grip() -> void:
	if not active: return
	if window.active:
		wall_normal = window.normal
		solid = window.solid
		saved_mask = actor.collision_mask
		window.active = false
	releasing = true
	waiting_for_move = false
	release_velocity = wall_normal * 1.8
	actor.velocity = release_velocity
	catch_seconds = 0.0

var window := preload("res://player/window_climb.gd").new()

func try_start() -> bool:
	if active or actor.is_swimming or actor.has_meta("mounted_vehicle"): return false
	# All entry profiles require actual takeoff, including low walls and windows.
	if actor.is_on_floor() or catch_seconds <= 0.0 or actor.global_position.y-launch_y < .06: return false
	leap_active = false
	layers.clear()
	window_committed = false
	waiting_for_move = false
	releasing = false
	if window.try_start(actor):
		active = true
		return true
	var forward: Vector3 = actor.visual_root.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var space: PhysicsDirectSpaceState3D = actor.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(actor.global_position,actor.global_position+forward*1.5)
	ray.exclude = [actor.get_rid()]
	var hit: Dictionary = space.intersect_ray(ray)
	if hit.is_empty():
		var lower: Vector3 = actor.global_position-Vector3.UP*.40
		var low_ray := PhysicsRayQueryParameters3D.create(lower,lower+forward*1.5)
		low_ray.exclude = [actor.get_rid()]
		hit = space.intersect_ray(low_ray)
	if not hit.is_empty() and hit.normal.dot(forward) > -.65:
		var structural_origin: Vector3 = actor.global_position-Vector3.UP*.85
		var structural_ray := PhysicsRayQueryParameters3D.create(structural_origin,structural_origin+forward*1.5)
		structural_ray.exclude = [actor.get_rid()]
		hit = space.intersect_ray(structural_ray)
	if hit.is_empty() or absf(hit.normal.y) > 0.65 or hit.normal.dot(forward) > -.65: return false
	if bool(hit.collider.get_meta("climb_blocked",false)): return false
	var authored: bool = hit.collider.is_in_group("climbable_walls")
	var discovered: Dictionary = {}
	if not authored:
		if not hit.collider is StaticBody3D: return false
		var surface := preload("res://player/climb_surface.gd").new()
		if surface.survey(actor,hit):
			if not window.start_ledge(actor,surface.edge,surface.normal,surface.landing,surface.highest-(actor.global_position.y-.9)): return false
			window.surface = surface
			active = true
			return true
		discovered = opportunities.survey(actor,hit)
		if discovered.is_empty():
			if OS.get_cmdline_user_args().has("--debug-opportunities"): print("CATCH reject no supported platform")
			return false
		layers = discovered.layers
		authored = true
	has_holds = not layers.is_empty() or hit.collider.has_meta("climb_hold_base_y")
	if has_holds:
		# Only a real, newly launched jump can catch the tall wall route.
		if catch_seconds <= 0.0 or actor.is_on_floor() or actor.global_position.y-launch_y < .35: return false
		if Vector2(actor.global_position.x-hit.position.x,actor.global_position.z-hit.position.z).length() > .90: return false
		route_missing_rows = hit.collider.get_meta("climb_hold_missing_rows",[])
	if layers.is_empty() and authored and absf(hit.position.z-float(hit.collider.get_meta("climb_center_z",hit.position.z)))>float(hit.collider.get_meta("climb_lane_half_width",.45)): return false
	wall_normal = hit.normal
	wall_point = hit.position
	hold_base_y = float(hit.collider.get_meta("climb_hold_base_y",hit.position.y))
	hold_center_z = float(hit.collider.get_meta("climb_hold_center_z",hit.position.z))
	hold_spacing = float(hit.collider.get_meta("climb_hold_spacing",.40))
	hold_rows = int(hit.collider.get_meta("climb_hold_rows",11))
	if not layers.is_empty():
		hold_base_y = layers[0].y
		hold_rows = layers.size()
	var top: float
	if not discovered.is_empty():
		top = discovered.top
	elif authored:
		top = hit.collider.get_meta("top_y")
		if top-actor.global_position.y < 0.5: return false
	else:
		if not hit.collider is StaticBody3D: return false
		var probe: Vector3 = hit.position - wall_normal * 0.18
		var down := PhysicsRayQueryParameters3D.create(Vector3(probe.x,actor.global_position.y+1.45,probe.z),Vector3(probe.x,actor.global_position.y-0.45,probe.z))
		down.exclude = [actor.get_rid()]
		var lip: Dictionary = space.intersect_ray(down)
		if lip.is_empty() or lip.collider != hit.collider or lip.normal.dot(Vector3.UP) < 0.7: return false
		top = lip.position.y
		var height_above_feet := top - (actor.global_position.y - 0.9)
		if height_above_feet < 0.55 or height_above_feet > 2.15: return false
	landing = discovered.landing if not discovered.is_empty() else Vector3(hit.position.x,top+0.94,hit.position.z)-wall_normal*(0.8 if authored else 0.65)
	# A lip alone does not establish a place to stand: verify surface depth.
	var support_query := PhysicsRayQueryParameters3D.create(landing+Vector3.UP*.15,landing-Vector3.UP*1.20)
	support_query.exclude = [actor.get_rid()]
	var support_hit := space.intersect_ray(support_query)
	if support_hit.is_empty() or support_hit.normal.y<.7 or absf(support_hit.position.y-top)>.15: return false
	var shape := PhysicsShapeQueryParameters3D.new()
	shape.shape = actor.get_node("CollisionShape3D").shape
	shape.transform = Transform3D(Basis.IDENTITY,landing)
	shape.exclude = [actor.get_rid()]
	if not space.intersect_shape(shape,1).is_empty(): return false
	if not has_holds:
		var ledge_height: float = top-(actor.global_position.y-.9)
		if ledge_height>2.15: return false
		if not window.start_ledge(actor,Vector3(hit.position.x,top,hit.position.z),wall_normal,landing,ledge_height): return false
		active = true
		return true
	start = actor.global_position
	grip = Vector3(hit.position.x,actor.global_position.y,hit.position.z)+wall_normal*.36
	var reachable_row := floori((actor.global_position.y+.95-hold_base_y-.07)/hold_spacing)
	if not layers.is_empty():
		reachable_row = -1
		for index in layers.size():
			var height: float = layers[index].y-actor.global_position.y
			if height >= .25 and height <= 1.10 and Vector2(layers[index].x-actor.global_position.x,layers[index].z-actor.global_position.z).length() < .95:
				reachable_row = index
	if reachable_row < (0 if not layers.is_empty() else int(hit.collider.get_meta("climb_min_hand_row",3))) or reachable_row >= hold_rows or reachable_row in route_missing_rows:
		if OS.get_cmdline_user_args().has("--debug-opportunities"): print("CATCH reject reach ",actor.global_position," layers=",layers)
		return false
	var catch_height: float = layers[reachable_row].y if not layers.is_empty() else hold_base_y+reachable_row*hold_spacing+.07
	if not layers.is_empty():
		grip = layers[reachable_row]+wall_normal*.36
	if catch_height-actor.global_position.y < .25: return false
	grip.y = catch_height-(.78 if not layers.is_empty() else .90)
	if not layers.is_empty(): grip = outside_architecture(grip)
	hang_grip = grip
	grip.y += .35
	# Stop the vertical pull with the boots below the coping. The last phase
	# must carry the hips and trailing feet over the lip before landing.
	crest = Vector3(hit.position.x,top-0.65,hit.position.z)+wall_normal*.36
	if not layers.is_empty():
		crest = layers[-1]+wall_normal*.36
		crest.y = top-.65
		crest = outside_architecture(crest)
	var clearance := Vector3(crest.x,_clearance_y(),crest.z)
	if not solid.can_move(actor,start,hang_grip,1.6):
		if OS.get_cmdline_user_args().has("--debug-opportunities"): print("CATCH reject entry sweep ",start," to ",hang_grip)
		return false
	var across := Vector3(landing.x,clearance.y,landing.z)
	if not solid.can_move(actor,crest,clearance,.9) or not solid.can_move(actor,clearance,across,.9) or not solid.can_move(actor,across,landing,.9):
		if OS.get_cmdline_user_args().has("--debug-opportunities"): print("CATCH reject mantle ",crest," ",clearance," ",across," ",landing)
		return false
	# Each ascent step has time for a reach, boot placement and upward push.
	ascent_steps = maxi(1, roundi((crest.y - grip.y) / (hold_spacing*.5)))
	duration = maxf(2.8, (ascent_steps * .55) / .58)
	first_hand_row = reachable_row
	first_foot_row = floori((grip.y-.65-hold_base_y)/hold_spacing)
	step_index = 0
	step_phase = 0.0
	progress = 0
	move_limit = .14
	waiting_for_move = false
	releasing = false
	catch_seconds = 0.0
	active = true
	saved_mask = actor.collision_mask
	solid.begin(actor)
	actor.set_meta("climbing",true)
	actor.velocity = Vector3.ZERO
	actor.survival.set_sprinting(false)
	var visual: Node = actor.get_node("VisualRoot/CharacterVisual")
	visual.equipment.stowed = true
	visual.equipment._refresh()
	actor.visual_root.global_rotation.y = atan2(-wall_normal.x,-wall_normal.z)
	leap.begin(self)
	leap_active = true
	return true

func _physics_process(delta: float) -> void:
	if not active:
		if catch_seconds > 0.0:
			catch_seconds = maxf(0.0,catch_seconds-delta)
			if not actor.is_on_floor(): try_start()
		return
	if window.active:
		if actor.survival.stamina <= 0.0 or Input.is_action_just_pressed("move_backward"):
			release_grip()
			return
		if waiting_for_move:
			if Input.is_action_just_pressed("jump") or (Input.is_action_pressed("jump") and Input.is_action_pressed("move_forward")): request_move()
			return
		var step_delta := delta
		if not window_committed:
			step_delta = minf(delta,maxf(0.0,.28-window.progress)*window.duration)
		window.advance(actor,step_delta)
		if window.active and not window_committed and window.progress >= .27999: waiting_for_move = true
		active = window.active
		return
	if releasing:
		release_velocity.y -= actor.gravity*delta
		actor.velocity = release_velocity
		actor.move_and_collide(release_velocity*delta)
		if solid.finish(actor):
			active = false
			actor.set_meta("climbing",false)
		return
	if actor.survival.stamina <= 0.0 or Input.is_action_just_pressed("move_backward"):
		release_grip()
		return
	if waiting_for_move:
		if Input.is_action_just_pressed("jump") or (Input.is_action_pressed("jump") and Input.is_action_pressed("move_forward")): request_move()
		return
	if leap_active and leap.phase != "mantle":
		leap.advance(delta)
		return
	var previous_progress := progress
	var previous_step := step_index
	var previous_phase := step_phase
	progress = minf(move_limit,progress+delta*(.14/.32 if progress < .14 else 1.0/duration))
	var t: float = clampf(progress,0,1)
	var destination := actor.global_position
	if t < 0.14:
		destination = start.lerp(hang_grip,smoothstep(0,0.14,t))
	elif t < .20:
		destination = hang_grip.lerp(grip,smoothstep(.14,.20,t))
	elif t < 0.78:
		var ascent: float = (t - .20) / .58
		var cycle := ascent * ascent_steps
		step_index = mini(ascent_steps-1, floori(maxf(0.0,cycle-.00001)))
		step_phase = clampf(cycle-step_index,0.0,1.0)
		# Reach, place the opposite boot, then push. Root travel occurs only
		# after the next pair of contacts is established.
		var stepped: float = (step_index + smoothstep(.50,.94,step_phase)) / ascent_steps
		destination = grip.lerp(crest, minf(1.0, stepped))
	elif t < .90:
		# Raise into a crouch at the coping; stand as the hips move onto it.
		var clearance := Vector3(crest.x,_clearance_y(),crest.z)
		destination = crest.lerp(clearance,smoothstep(.78,.90,t))
	else:
		var clearance := Vector3(crest.x,_clearance_y(),crest.z)
		var across := Vector3(landing.x,clearance.y,landing.z)
		destination = clearance.lerp(across,smoothstep(.90,.96,t)) if t < .96 else across.lerp(landing,smoothstep(.96,1.0,t))
	var height: float = lerpf(1.6,.9,smoothstep(.78,.88,t))
	if not solid.move_to(actor,destination,height):
		progress = previous_progress
		step_index = previous_step
		step_phase = previous_phase
		return
	if progress >= move_limit and move_limit < 1.0:
		waiting_for_move = true
	if t >= 1 and solid.finish(actor):
		active = false
		actor.set_meta("climbing",false)
		actor.collision_mask = saved_mask
		actor.velocity = Vector3.ZERO

func tree_pose_progress() -> float:
	if leap_active and leap.phase != "mantle": return leap.pose()
	if waiting_for_move and progress <= .14001: return .14
	if progress < .14 or progress >= .78: return progress
	if progress < .20: return lerpf(.14,.28,smoothstep(.14,.20,progress))
	var transfer := smoothstep(.28,.70,step_phase)
	return lerpf(.28,.56,transfer) if step_index%2 == 0 else lerpf(.56,.28,transfer)

func step_contact(side: String, foot: bool) -> Vector3:
	if leap_active: return leap.contact(side,foot)
	var tangent := Vector3.UP.cross(wall_normal).normalized()
	var moving_left: bool = step_index%2 == 0
	if foot: moving_left = not moving_left
	var moving: bool = (side == "l") == moving_left
	var count: int = (step_index+1)/2 if ((side == "l") != foot) else step_index/2
	var row: int = (first_foot_row if foot else first_hand_row)+count
	var move: float = smoothstep(.28,.50,step_phase) if foot else smoothstep(0.0,.28,step_phase)
	if not moving: move = 0.0
	var from := _hold(row,side,foot,tangent)
	var to := _hold(row+1,side,foot,tangent)
	var point := from.lerp(to,move)
	# Lift clear of the stone during the transfer, then lock to its surface.
	point += wall_normal*sin(move*PI)*(.12 if foot else .07)
	return point

func _hold(row: int, side: String, foot: bool, tangent: Vector3) -> Vector3:
	if not layers.is_empty():
		var point := layers[clampi(row,0,layers.size()-1)]
		return point+tangent*(-.24 if side == "l" else .24)-wall_normal*(.05 if foot else 0.0)
	var point := wall_point+wall_normal*(.13 if foot else .18)
	point += tangent*((-.24 if side == "l" else .24)+(.08 if posmod(row,2)==1 else 0.0))
	point.y = hold_base_y+row*hold_spacing+(.08 if foot else .07)
	if foot: point.y = maxf(start.y-.86, point.y)
	if row >= hold_rows:
		point.y = landing.y-.94+.08
	return point

func _clearance_y() -> float:
	return maxf(landing.y-.39,layers[-1].y+.48) if not layers.is_empty() else landing.y-.39

func outside_architecture(point: Vector3) -> Vector3:
	var edge := 0.0
	for layer in layers:
		if layer.y <= point.y+.95: edge = maxf(edge,(layer-wall_point).dot(wall_normal))
	return point+wall_normal*maxf(0.0,edge+.36-(point-wall_point).dot(wall_normal))
