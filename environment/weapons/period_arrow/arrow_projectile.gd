extends Node3D
## Continuous swept arrow; the visual does not determine hit detection.
const ARROW = preload("res://environment/weapons/period_arrow/period_arrow.glb")
const SPEED := 52.0
const GRAVITY := 9.8
var velocity := Vector3.ZERO
var shooter: CollisionObject3D
var active := false
var age := 0.0
var hit_count := 0

func _ready() -> void:
	var model: Node3D = ARROW.instantiate()
	add_child(model)

func launch(origin: Vector3, direction: Vector3, source: CollisionObject3D) -> void:
	global_position = origin
	velocity = direction.normalized() * SPEED
	shooter = source
	active = true
	_orient()

func _physics_process(delta: float) -> void:
	if not active: return
	age += delta
	if age > 8.0:
		queue_free()
		return
	var travel := velocity*delta + Vector3.DOWN*GRAVITY*delta*delta*0.5
	var query := PhysicsRayQueryParameters3D.create(global_position,global_position+travel)
	if is_instance_valid(shooter): query.exclude = [shooter.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position
		active = false
		hit_count += 1
		if hit.collider.has_method("take_damage"): hit.collider.take_damage(35.0)
		get_tree().create_timer(8.0).timeout.connect(queue_free)
		return
	global_position += travel
	velocity += Vector3.DOWN*GRAVITY*delta
	_orient()

func _orient() -> void:
	if velocity.length_squared() > 0.01:
		global_basis = Basis(Quaternion(Vector3.UP,velocity.normalized()))
