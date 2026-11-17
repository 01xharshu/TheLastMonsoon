extends Node
## Roll each wheel from measured travel, including scripted motion, reversing and turns.
var cart: Node3D
var previous: Dictionary={}
var previous_origin:=Vector3.INF
var previous_forward:=Vector3.FORWARD
func _ready() -> void:
	cart=get_parent();process_priority=200
	reset()
func reset() -> void:
	previous.clear()
	previous_origin=cart.global_position;previous_forward=-cart.global_basis.z.normalized()
	for wheel in cart.wheels:previous[wheel.get_instance_id()]=wheel.global_position
func _process(delta: float) -> void:
	update_roll(delta)
func update_roll(delta: float) -> void:
	if not previous_origin.is_finite() or cart.global_position.distance_to(previous_origin)>maxf(3.0,60.0*delta):reset();return
	var forward: Vector3=-cart.global_basis.z.normalized()
	var tangent: Vector3=(forward+previous_forward).normalized()
	for wheel in cart.wheels:
		var key: int=wheel.get_instance_id()
		if previous.has(key):
			var displacement: Vector3=wheel.global_position-previous[key]
			var along:=displacement.dot(tangent)
			var radius: float=maxf(.05,wheel.position.y*cart.global_basis.y.length())
			wheel.rotation.x=wrapf(wheel.rotation.x+along/radius,-PI,PI)
		previous[key]=wheel.global_position
	previous_origin=cart.global_position;previous_forward=forward
