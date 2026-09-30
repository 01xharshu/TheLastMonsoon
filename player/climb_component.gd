extends Node
## Authored climbable masonry: physical wall check, clear landing, timed ascent and mantle.
@onready var actor: CharacterBody3D = get_parent()
var active := false
var progress := 0.0
var duration := 2.4
var start := Vector3.ZERO
var crest := Vector3.ZERO
var grip := Vector3.ZERO
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

func try_start() -> bool:
	if active or actor.is_swimming or actor.has_meta("mounted_vehicle"): return false
	var forward: Vector3 = actor.visual_root.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var space: PhysicsDirectSpaceState3D = actor.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(actor.global_position,actor.global_position+forward*1.5)
	ray.exclude = [actor.get_rid()]
	var hit: Dictionary = space.intersect_ray(ray)
	if hit.is_empty() or absf(hit.normal.y) > 0.25: return false
	var authored: bool = hit.collider.is_in_group("climbable_walls")
	has_holds = hit.collider.has_meta("climb_hold_base_y")
	if authored and absf(hit.position.z-float(hit.collider.get_meta("climb_center_z",hit.position.z)))>2.3: return false
	wall_normal = hit.normal
	wall_point = hit.position
	hold_base_y = float(hit.collider.get_meta("climb_hold_base_y",hit.position.y))
	hold_center_z = float(hit.collider.get_meta("climb_hold_center_z",hit.position.z))
	var top: float
	if authored:
		top = hit.collider.get_meta("top_y")
		if top-actor.global_position.y > 5.6 or top-actor.global_position.y < 0.5: return false
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
	landing = Vector3(hit.position.x,top+0.94,hit.position.z)-wall_normal*(0.8 if authored else 0.25)
	var shape := PhysicsShapeQueryParameters3D.new()
	shape.shape = actor.get_node("CollisionShape3D").shape
	shape.transform = Transform3D(Basis.IDENTITY,landing)
	shape.exclude = [actor.get_rid()]
	if not space.intersect_shape(shape,1).is_empty(): return false
	start = actor.global_position
	grip = Vector3(hit.position.x,actor.global_position.y,hit.position.z)+wall_normal*.28
	# Stop the vertical pull with the boots below the coping. The last phase
	# must carry the hips and trailing feet over the lip before landing.
	crest = Vector3(hit.position.x,top-0.65,hit.position.z)+wall_normal*.36
	# Keep tall climbs at a human climbing pace; a short ledge still uses the
	# original quick reach and mantle timing.
	ascent_steps = maxi(1, roundi((crest.y - grip.y) / .275))
	duration = maxf(2.8, (ascent_steps * .70) / .64)
	first_hand_row = clampi(floori((grip.y+.35-hold_base_y)/.55),0,7)
	first_foot_row = maxi(0,roundi((grip.y-.65-hold_base_y)/.55))
	step_index = 0
	step_phase = 0.0
	progress = 0
	active = true
	saved_mask = actor.collision_mask
	actor.collision_mask = 0
	actor.set_meta("climbing",true)
	actor.velocity = Vector3.ZERO
	actor.survival.set_sprinting(false)
	var visual: Node = actor.get_node("VisualRoot/CharacterVisual")
	visual.equipment.stowed = true
	visual.equipment._refresh()
	actor.visual_root.global_rotation.y = atan2(-wall_normal.x,-wall_normal.z)
	return true

func _physics_process(delta: float) -> void:
	if not active: return
	progress += delta/duration
	var t: float = clampf(progress,0,1)
	if t < 0.14:
		actor.global_position = start.lerp(grip,smoothstep(0,0.14,t))
	elif t < 0.78:
		var ascent: float = (t - .14) / .64
		step_index = mini(ascent_steps-1, floori(ascent * ascent_steps))
		step_phase = fposmod(ascent * ascent_steps, 1.0)
		# Reach, place the opposite boot, then push. Root travel occurs only
		# after the next pair of contacts is established.
		var stepped: float = (step_index + smoothstep(.50,.94,step_phase)) / ascent_steps
		actor.global_position = grip.lerp(crest, minf(1.0, stepped))
	elif t < .90:
		# Lift outside the face until the trailing boot clears the coping.
		var clearance := Vector3(crest.x, landing.y + .10, crest.z)
		actor.global_position = crest.lerp(clearance,smoothstep(.78,.90,t))
	else:
		var clearance := Vector3(crest.x, landing.y + .10, crest.z)
		actor.global_position = clearance.lerp(landing,smoothstep(.90,1.0,t))
	if t >= 1:
		active = false
		actor.set_meta("climbing",false)
		actor.collision_mask = saved_mask
		actor.velocity = Vector3.ZERO

func tree_pose_progress() -> float:
	if progress < .14 or progress >= .78: return progress
	var transfer := smoothstep(.28,.70,step_phase)
	return lerpf(.28,.56,transfer) if step_index%2 == 0 else lerpf(.56,.28,transfer)

func step_contact(side: String, foot: bool) -> Vector3:
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
	var point := wall_point+wall_normal*(.13 if foot else .18)
	point += tangent*((-.24 if side == "l" else .24)+(.08 if posmod(row,2)==1 else 0.0))
	point.y = hold_base_y+row*.55+(.08 if foot else .07)
	if row >= 8:
		point.y = landing.y-.94+.08
		point -= wall_normal*.20
	return point
