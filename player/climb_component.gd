extends Node
## Authored climbable masonry: physical wall check, clear landing, timed ascent and mantle.
@onready var actor: CharacterBody3D = get_parent()
var active := false
var progress := 0.0
var start := Vector3.ZERO
var crest := Vector3.ZERO
var grip := Vector3.ZERO
var landing := Vector3.ZERO
var saved_mask: int
var wall_normal := Vector3.ZERO
var wall_point := Vector3.ZERO

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
	if authored and absf(hit.position.z-float(hit.collider.get_meta("climb_center_z",hit.position.z)))>2.3: return false
	wall_normal = hit.normal
	wall_point = hit.position
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
	grip = Vector3(hit.position.x,actor.global_position.y,hit.position.z)+wall_normal*.48
	crest = Vector3(hit.position.x,top+1.1,hit.position.z)+wall_normal*.46
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
	progress += delta/2.4
	var t: float = clampf(progress,0,1)
	if t < 0.14:
		actor.global_position = start.lerp(grip,smoothstep(0,0.14,t))
	elif t < 0.78:
		actor.global_position = grip.lerp(crest,smoothstep(0.14,0.78,t))
	else:
		actor.global_position = crest.lerp(landing,smoothstep(0.78,1.0,t))
	if t >= 1:
		active = false
		actor.set_meta("climbing",false)
		actor.collision_mask = saved_mask
		actor.velocity = Vector3.ZERO
