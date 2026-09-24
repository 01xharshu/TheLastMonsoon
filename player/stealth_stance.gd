extends Node
## Ground stances layered after locomotion. Cover requires a real solid surface.
const STAND := ""
const COVER := "cover"
const PRONE := "prone"
@onready var actor: CharacterBody3D = get_parent()
@onready var collider: CollisionShape3D = actor.get_node("CollisionShape3D")
@onready var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
var stance := STAND
var cover_body: CollisionObject3D
var cover_point := Vector3.ZERO
var blend := 0.0
var cover_blend := 0.0
var base_height := 1.5

func _ready() -> void:
	process_priority = 20
	base_height = actor.get_node("CameraPivot").position.y
	collider.shape = collider.shape.duplicate()

func is_low() -> bool:
	return stance != STAND

func move_speed() -> float:
	return 1.15 if stance == PRONE else 2.0

func camera_height() -> float:
	if stance == PRONE: return .52
	if stance == COVER: return 1.42 if Input.is_action_pressed("aim") else 1.07
	return base_height

func can_change() -> bool:
	return actor.is_on_floor() and not actor.is_swimming and not actor.has_meta("mounted_vehicle") and not actor.get_meta("climbing",false) and actor.get_meta("river_action","") == "" and not actor.inventory_ui.is_open() and not actor.get_meta("map_open",false) and not actor.get_meta("weapon_wheel_open",false) and not actor.get_meta("scroll_open",false) and not actor.get_meta("interaction_reach",false)

func _unhandled_input(event: InputEvent) -> void:
	if not can_change(): return
	if event.is_action_pressed("toggle_prone"):
		if stance == PRONE: stand()
		else: enter_prone()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("take_cover"):
		if stance == COVER: stand()
		else: try_cover()
		get_viewport().set_input_as_handled()

func enter_prone() -> void:
	if not can_change(): return
	cover_body = null
	_set_stance(PRONE)

func try_cover() -> bool:
	if not can_change(): return false
	var direction: Vector3 = -actor.get_node("CameraPivot").global_basis.z
	direction.y = 0.0
	direction = direction.normalized()
	var origin := actor.global_position - Vector3.UP*.18
	var query := PhysicsRayQueryParameters3D.create(origin,origin+direction*1.5)
	query.exclude = [actor.get_rid()]
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider is CollisionObject3D or absf(hit.normal.y) > .55: return false
	cover_body = hit.collider
	cover_point = hit.position
	_set_stance(COVER)
	return true

func stand() -> bool:
	if stance == STAND: return true
	var query := PhysicsShapeQueryParameters3D.new()
	var standing_shape := CapsuleShape3D.new()
	standing_shape.radius = .4
	standing_shape.height = 1.8
	query.shape = standing_shape
	query.transform = Transform3D(Basis.IDENTITY,actor.global_position+Vector3.UP*.015)
	query.exclude = [actor.get_rid()]
	query.collision_mask = actor.collision_mask
	if not actor.get_world_3d().direct_space_state.intersect_shape(query,8).is_empty(): return false
	cover_body = null
	_set_stance(STAND)
	return true

func _set_stance(next: String) -> void:
	stance = next
	actor.set_meta("stealth_stance",stance)
	var shape := collider.shape as CapsuleShape3D
	if next == PRONE:
		shape.radius = .32
		shape.height = 1.5
		collider.rotation.x = PI*.5
		collider.position.y = -.56
	elif next == COVER:
		shape.radius = .4
		shape.height = 1.18
		collider.rotation.x = 0.0
		collider.position.y = -.31
	else:
		shape.radius = .4
		shape.height = 1.8
		collider.rotation.x = 0.0
		collider.position.y = 0.0
	actor.floor_snap_length = actor.ground_snap_distance

func _physics_process(_delta: float) -> void:
	if stance == COVER and (not is_instance_valid(cover_body) or actor.global_position.distance_to(cover_point) > 2.1):
		stand()
	if stance != STAND and (actor.is_swimming or actor.has_meta("mounted_vehicle") or actor.get_meta("climbing",false)):
		_set_stance(STAND)

func _process(delta: float) -> void:
	if visual.skeleton == null: return
	blend = move_toward(blend,1.0 if stance != STAND else 0.0,delta*3.5)
	cover_blend = move_toward(cover_blend,1.0 if stance == COVER else 0.0,delta*4.0)
	if blend <= .001: return
	var prone_weight := maxf(0.0,blend-cover_blend)
	if cover_blend > .001: _pose_cover(cover_blend)
	if prone_weight > .001: _pose_prone(prone_weight,delta)

func _pose_cover(weight: float) -> void:
	var aiming: bool = Input.is_action_pressed("aim")
	visual.model.position.y = lerpf(visual.model.position.y,-1.03 if aiming else -1.19,weight)
	visual.pose("pelvis",Vector3(.19 if aiming else .35,0,0),weight)
	visual.pose("spine_01",Vector3(.25,0,0),weight)
	visual.pose("spine_02",Vector3(.12,0,0),weight)
	visual.pose("thigh_l",Vector3(.64 if aiming else .95,0,-.12),weight)
	visual.pose("calf_l",Vector3(-.92 if aiming else -1.35,0,0),weight)
	visual.pose("thigh_r",Vector3(.62 if aiming else .90,0,.12),weight)
	visual.pose("calf_r",Vector3(-.9 if aiming else -1.3,0,0),weight)
	visual.pose("upperarm_l",Vector3(-.65 if aiming else -.42,0,-.35),weight*.65)
	visual.pose("upperarm_r",Vector3(-.85 if aiming else -.46,0,.35),weight*.65)

func _pose_prone(weight: float,_delta: float) -> void:
	visual.model.position.y = lerpf(visual.model.position.y,-1.08,weight)
	visual.model.rotation.x = lerpf(visual.model.rotation.x,1.30,weight)
	var crawl: float = sin(float(Time.get_ticks_msec())*.012)*minf(1.0,Vector2(actor.velocity.x,actor.velocity.z).length())
	visual.pose("spine_01",Vector3(-.10,0,0),weight)
	visual.pose("head",Vector3(.25,0,0),weight)
	visual.pose("thigh_l",Vector3(.12+crawl*.18,0,-.08),weight)
	visual.pose("thigh_r",Vector3(.12-crawl*.18,0,.08),weight)
	visual.pose("calf_l",Vector3(-.08,0,0),weight)
	visual.pose("calf_r",Vector3(-.08,0,0),weight)
	visual.pose("upperarm_l",Vector3(-.9-crawl*.16,0,-.28),weight)
	visual.pose("upperarm_r",Vector3(-.9+crawl*.16,0,.28),weight)
	visual.pose("lowerarm_l",Vector3(-.9,0,0),weight)
	visual.pose("lowerarm_r",Vector3(-.9,0,0),weight)
