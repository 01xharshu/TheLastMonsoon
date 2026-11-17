extends Node3D
## Continuous swept arrow; the visual does not determine hit detection.
const ARROW = preload("res://environment/weapons/period_arrow/period_arrow.glb")
const SPEED := 52.0
const GRAVITY := 9.8
const TIP_OFFSET := .77
var velocity := Vector3.ZERO
var shooter: CollisionObject3D
var active := false
var age := 0.0
var hit_count := 0

func _ready() -> void:
	var model: Node3D = ARROW.instantiate()
	model.position.y=-TIP_OFFSET
	add_child(model)

func launch(origin: Vector3, direction: Vector3, source: CollisionObject3D, path_start := Vector3.INF) -> void:
	global_position = origin
	velocity = direction.normalized() * SPEED
	shooter = source
	active = true
	_orient()
	if path_start.is_finite():
		var clearance := PhysicsRayQueryParameters3D.create(path_start,origin,9,[source.get_rid()])
		var obstacle := get_world_3d().direct_space_state.intersect_ray(clearance)
		if not obstacle.is_empty():impact(obstacle)

func _physics_process(delta: float) -> void:
	if not active: return
	age += delta
	if age > 8.0:
		queue_free()
		return
	var travel := velocity*delta + Vector3.DOWN*GRAVITY*delta*delta*0.5
	var query := PhysicsRayQueryParameters3D.create(global_position,global_position+travel)
	if is_instance_valid(shooter): query.exclude = [shooter.get_rid()]
	query.exclude = preload("res://combat/ballistic_trace.gd").exclusions(get_tree(),query.exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		impact(hit)
		return
	global_position += travel
	velocity += Vector3.DOWN*GRAVITY*delta
	_orient()

func impact(hit: Dictionary) -> void:
	global_position = hit.position
	active = false
	WorldAudio.play_at("arrow_impact",hit.position,-18.0)
	hit_count += 1
	var policy=preload("res://combat/damage_policy.gd")
	var damaged: bool=policy.apply(hit.collider,35.0,shooter,"arrow",hit.position,velocity.normalized())
	if damaged:follow_hit_pose(policy.receiver(hit.collider),hit.position)
	get_tree().create_timer(8.0).timeout.connect(queue_free)

func _orient() -> void:
	if velocity.length_squared() > 0.01:
		global_basis = Basis(Quaternion(Vector3.UP,velocity.normalized()))

func follow_hit_pose(receiver: Node, point: Vector3) -> void:
	if receiver==null or receiver.name!="Vitality":return
	var victim: Node3D=receiver.get_parent()
	var rig: Skeleton3D=victim.get("_skeleton")
	if rig==null:return
	var bone_name := "spine_02"
	var spine: int=rig.find_bone(bone_name)
	var head: int=rig.find_bone("head")
	if head>=0 and rig.to_global(rig.get_bone_global_pose(head).origin).distance_to(point)<rig.to_global(rig.get_bone_global_pose(spine).origin).distance_to(point):bone_name="head"
	var attachment := BoneAttachment3D.new()
	attachment.name="ArrowImpactAttachment";attachment.bone_name=bone_name
	rig.add_child(attachment);rig.force_update_all_bone_transforms()
	reparent(attachment,true)
	get_tree().create_timer(8.0).timeout.connect(attachment.queue_free)
