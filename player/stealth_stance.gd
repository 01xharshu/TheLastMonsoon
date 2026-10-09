extends Node
## Ground stances layered after locomotion. Cover requires a real solid surface.
const STAND := ""
const COVER := "cover"
const CROUCH := "crouch"
const CropCover = preload("res://player/crop_concealment.gd")
const GarmentFit = preload("res://player/arjun_stance_garment_fit.gd")
const PRONE := "prone"
@onready var actor: CharacterBody3D = get_parent()
@onready var collider: CollisionShape3D = actor.get_node("CollisionShape3D")
@onready var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
var stance := STAND
var cover_body: CollisionObject3D
var cover_point := Vector3.ZERO
var cover_local_point := Vector3.ZERO
var blend := 0.0
var cover_blend := 0.0
var prone_blend := 0.0
var aim_peek := 0.0
var gait_phase := 0.0
var prone_support_lift := 0.0
var base_height := 1.5
var crop_fields: Array[Node3D] = []
var crop_cache_age := 0.0
var fitted_garments := 0
var low_waist: Array[Dictionary] = []

func _ready() -> void:
	process_priority = 20
	base_height = actor.get_node("CameraPivot").position.y
	collider.shape = collider.shape.duplicate()
	fitted_garments = GarmentFit.apply(visual.model)
	low_waist = GarmentFit.prepare_low_waist(visual.model)
	# Carry the pouch after this final pose, then solve its cloth support.
	var carry := actor.get_node("VisualRoot/EquipmentVisuals")
	carry.process_priority = 21
	carry.get_node("WaterBagVisual").process_priority = 22

func is_low() -> bool:
	return stance != STAND or blend > .01

func move_speed() -> float:
	return 1.15 if stance == PRONE or prone_blend > .1 else 2.0

func camera_height() -> float:
	var crouched_height := lerpf(1.07,1.42,aim_peek)
	return lerpf(lerpf(base_height,crouched_height,cover_blend),.52,prone_blend)+prone_support_lift

func can_change() -> bool:
	if actor.get_meta("detention_action", "") != "": return false
	return actor.is_on_floor() and not actor.is_swimming and not actor.has_meta("mounted_vehicle") and not actor.get_meta("climbing",false) and actor.get_meta("river_action","") == "" and not actor.inventory_ui.is_open() and not actor.get_meta("map_open",false) and not actor.get_meta("weapon_wheel_open",false) and not actor.get_meta("scroll_open",false) and not actor.get_meta("interaction_reach",false)

func _unhandled_input(event: InputEvent) -> void:
	if not can_change(): return
	if event.is_action_pressed("toggle_prone"):
		if stance == PRONE: stand()
		else: enter_prone()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("take_cover"):
		if stance in [COVER,CROUCH]: stand()
		elif not try_cover(): enter_crouch()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_H or event.keycode == KEY_H):
		if stance == COVER: stand()
		else: try_cover()
		get_viewport().set_input_as_handled()

func enter_crouch() -> void:
	if not can_change(): return
	cover_body = null
	_set_stance(CROUCH)

func sight_target() -> Vector3:
	return actor.global_position-Vector3.UP*.9+Vector3.UP*_sight_height()

func _sight_height() -> float:
	return lerpf(lerpf(1.60,lerpf(1.02,1.42,aim_peek),cover_blend),.38,prone_blend)+prone_support_lift

func visible_range(observer: Vector3, base_range: float) -> float:
	var feet := actor.global_position-Vector3.UP*.9
	var concealment := 0.0
	for field in crop_fields:
		if is_instance_valid(field): concealment = maxf(concealment, CropCover.cover_sample(field,feet,_sight_height(),observer))
	return maxf(3.0, base_range*(1.0-.65*concealment))

func _refresh_crop_fields() -> void:
	crop_fields.clear()
	var candidates: Array[Dictionary] = []
	for group in ["crop_concealment", "bhairavpur_garden"]:
		for field in get_tree().get_nodes_in_group(group):
			if not field is Node3D: continue
			candidates.append({"field":field,"distance":actor.global_position.distance_squared_to(field.global_position)})
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.distance < b.distance)
	for record in candidates:
		if crop_fields.size()>=32: break
		if not record.field in crop_fields: crop_fields.append(record.field)

func enter_prone() -> void:
	if not can_change(): return
	var query := PhysicsShapeQueryParameters3D.new()
	var horizontal := CapsuleShape3D.new()
	horizontal.radius = .32
	horizontal.height = 1.5
	query.shape = horizontal
	query.margin = .001
	query.transform = Transform3D(Basis(Vector3.UP,actor.get_node("VisualRoot").global_rotation.y)*Basis(Vector3.RIGHT,PI*.5),actor.global_position-Vector3.UP*.56)
	query.exclude = [actor.get_rid()]
	query.collision_mask = actor.collision_mask
	if not actor.get_world_3d().direct_space_state.intersect_shape(query,8).is_empty(): return
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
	cover_local_point = cover_body.to_local(cover_point)
	_set_stance(COVER)
	return true

func stand() -> bool:
	if stance == STAND: return true
	var query := PhysicsShapeQueryParameters3D.new()
	var standing_shape := CapsuleShape3D.new()
	standing_shape.radius = .4
	standing_shape.height = 1.8
	query.shape = standing_shape
	query.margin = .001
	# Crawl capsule rests 2 cm lower than the standing capsule; lift the
	# clearance probe enough to avoid treating its supporting floor as a roof.
	query.transform = Transform3D(Basis.IDENTITY,actor.global_position+Vector3.UP*.035)
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
		collider.rotation.y = actor.get_node("VisualRoot").rotation.y
		collider.position.y = -.56
	elif next in [COVER,CROUCH]:
		shape.radius = .4
		shape.height = 1.18
		collider.rotation.x = 0.0
		collider.rotation.y = 0.0
		collider.position.y = -.31
	else:
		shape.radius = .4
		shape.height = 1.8
		collider.rotation.x = 0.0
		collider.rotation.y = 0.0
		collider.position.y = 0.0
	actor.floor_snap_length = actor.ground_snap_distance

func _physics_process(_delta: float) -> void:
	if stance == PRONE: collider.rotation.y = actor.get_node("VisualRoot").rotation.y
	crop_cache_age -= _delta
	if crop_cache_age <= 0.0:
		crop_cache_age = 1.0
		_refresh_crop_fields()
	if stance == COVER:
		if is_instance_valid(cover_body):
			cover_point = cover_body.to_global(cover_local_point)
		if not is_instance_valid(cover_body) or actor.global_position.distance_to(cover_point) > 2.1:
			# Losing shelter must not expose Arjun by automatically standing him up.
			cover_body = null
			_set_stance(CROUCH)
	if stance != STAND and (actor.is_swimming or actor.has_meta("mounted_vehicle") or actor.get_meta("climbing",false)):
		_set_stance(STAND)

func _process(delta: float) -> void:
	if visual.skeleton == null: return
	cover_blend = move_toward(cover_blend,1.0 if stance in [COVER,CROUCH] else 0.0,delta*4.0)
	prone_blend = move_toward(prone_blend,1.0 if stance == PRONE else 0.0,delta*3.5)
	blend = maxf(cover_blend,prone_blend)
	GarmentFit.use_low_waist(low_waist,blend > .001)
	prone_support_lift = 0.0
	aim_peek = move_toward(aim_peek,1.0 if stance == COVER and Input.is_action_pressed("aim") else 0.0,delta*4.5)
	var travel_speed := Vector2(actor.velocity.x,actor.velocity.z).length()
	gait_phase = fmod(gait_phase+delta*travel_speed*(5.0 if stance == PRONE else 4.2),TAU)
	if blend <= .001: return
	if cover_blend > .001: _pose_cover(cover_blend)
	if prone_blend > .001: _pose_prone(prone_blend,delta)
	# Stance is the final body layer. Resolve carried equipment against that
	# pose so the earlier weapon solve cannot be pulled away by crouch/crawl.
	if visual.equipment != null and not visual.equipment.stowed:
		visual.skeleton.force_update_all_bone_transforms()
		visual.equipment.apply_rifle_grip()

func _pose_cover(weight: float) -> void:
	var stride := clampf(Vector2(actor.velocity.x,actor.velocity.z).length()/2.0,0.0,1.0)
	var swing := sin(gait_phase)*.23*stride
	visual.model.position.y = lerpf(visual.model.position.y,lerpf(-1.19,-1.03,aim_peek),weight)
	visual.pose("pelvis",Vector3(lerpf(.35,.19,aim_peek),swing*.12,0),weight)
	visual.pose("spine_01",Vector3(.25,0,0),weight)
	visual.pose("spine_02",Vector3(.12,0,0),weight)
	visual.pose("thigh_l",Vector3(lerpf(.95,.64,aim_peek)+swing,0,-.12),weight)
	visual.pose("calf_l",Vector3(lerpf(-1.35,-.92,aim_peek)-maxf(0.0,swing)*.7,0,0),weight)
	visual.pose("thigh_r",Vector3(lerpf(.90,.62,aim_peek)-swing,0,.12),weight)
	visual.pose("calf_r",Vector3(lerpf(-1.3,-.9,aim_peek)-maxf(0.0,-swing)*.7,0,0),weight)
	visual.pose("upperarm_l",Vector3(lerpf(-.42,-.65,aim_peek)-swing*.4,0,-.35),weight*.65)
	visual.pose("upperarm_r",Vector3(lerpf(-.46,-.85,aim_peek)+swing*.4,0,.35),weight*.65)
	# Lower the posed rig until its lowest boot reaches the support plane.
	# Collision travel remains on the CharacterBody; this corrects visual height.
	var lowest := INF
	for side in ["l","r"]:
		var bone: int = visual.skeleton.find_bone("foot_"+side)
		if bone >= 0:
			var foot: Vector3 = visual.skeleton.global_transform*visual.skeleton.get_bone_global_pose(bone).origin
			lowest = minf(lowest,foot.y)
	if lowest < INF:
		var support := actor.global_position.y-.9+.10
		visual.model.position.y += clampf(support-lowest,-.4,.2)*weight


func _pose_prone(weight: float,_delta: float) -> void:
	visual.model.position.y = lerpf(visual.model.position.y,-1.08,weight)
	visual.model.rotation.x = lerpf(visual.model.rotation.x,1.30,weight)
	var crawl: float = sin(gait_phase)*minf(1.0,Vector2(actor.velocity.x,actor.velocity.z).length())
	visual.pose("spine_01",Vector3(-.10,0,0),weight)
	visual.pose("head",Vector3(.25,0,0),weight)
	visual.pose("thigh_l",Vector3(.12+crawl*.18,0,-.08),weight)
	visual.pose("thigh_r",Vector3(.12-crawl*.18,0,.08),weight)
	visual.pose("calf_l",Vector3(-.08,0,0),weight)
	visual.pose("calf_r",Vector3(-.08,0,0),weight)
	visual.pose("foot_l",Vector3.ZERO,weight)
	visual.pose("foot_r",Vector3.ZERO,weight)
	visual.pose("ball_l",Vector3.ZERO,weight)
	visual.pose("ball_r",Vector3.ZERO,weight)
	visual.pose("upperarm_l",Vector3(-.9-crawl*.16,0,-.28),weight)
	visual.pose("upperarm_r",Vector3(-.9+crawl*.16,0,.28),weight)
	visual.pose("lowerarm_l",Vector3(-.9,0,0),weight)
	visual.pose("lowerarm_r",Vector3(-.9,0,0),weight)
	var support := actor.global_position.y-.9
	var query := PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*.2,actor.global_position-Vector3.UP*1.4,actor.collision_mask)
	query.exclude = [actor.get_rid()]
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.normal.y > .5: support = hit.position.y
	visual.skeleton.force_update_all_bone_transforms()
	var lowest := INF
	for side in ["l","r"]:
		var foot: Vector3 = visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("foot_"+side)).origin)
		lowest = minf(lowest,foot.y)
	prone_support_lift = clampf(support+.10-lowest,-.20,.30)*weight
	visual.model.position.y += prone_support_lift
	if visual.equipment != null and visual.equipment.stowed:
		visual.skeleton.force_update_all_bone_transforms()
		for side in ["l","r"]:
			var hand: Vector3 = visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("hand_"+side)).origin)
			hand.y = lerpf(hand.y,support+.06,weight)
			visual.equipment._solve_arm(side,visual.skeleton.to_local(hand))
