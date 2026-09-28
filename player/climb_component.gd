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
	crest = Vector3(hit.position.x,top+0.72,hit.position.z)+wall_normal*.27
	# Keep tall climbs at a human climbing pace; a short ledge still uses the
	# original quick reach and mantle timing.
	duration = maxf(2.4, (crest.y - grip.y) / .85 + .95)
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
		var step_count: float = maxf(1.0, ceilf((crest.y - grip.y) / .72))
		var step_number: float = floorf(ascent * step_count)
		var step_phase: float = fposmod(ascent * step_count, 1.0)
		var stepped: float = (step_number + smoothstep(0.08, .92, step_phase)) / step_count
		actor.global_position = grip.lerp(crest, minf(1.0, stepped))
	else:
		actor.global_position = crest.lerp(landing,smoothstep(0.78,1.0,t))
	if t >= 1:
		active = false
		actor.set_meta("climbing",false)
		actor.collision_mask = saved_mask
		actor.velocity = Vector3.ZERO
