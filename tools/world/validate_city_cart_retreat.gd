extends SceneTree
## Non-rendered vehicle-state fixture: a sub-ULP reverse remainder must finish.
class Boarding extends RefCounted:
	var speed := -.65
class Vehicle extends Node3D:
	var boarding := Boarding.new()
	var recorded_motion := INF
	func set_forward_motion(speed:float, _delta:float) -> void: recorded_motion=speed
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var cart := Vehicle.new(); root.add_child(cart)
	cart.position=Vector3(-328.1983,8.330203,-15.28201);cart.rotation.y=PI*.5
	var before:=cart.global_position
	var residual:=.00000591576099
	var journey:=preload("res://world/suryagarh/city_cart_journey.gd").new()
	journey.configure(cart);journey.retreat_remaining=residual;journey.stalled_age=42;journey.passing_retry=3
	var errors:Array[String]=[]
	if before+cart.global_basis.z*residual!=before:errors.append("fixture did not reproduce sub-ULP displacement")
	journey.retreat(.1)
	if journey.retreat_remaining!=0 or journey.stalled_age!=0 or journey.passing_retry!=0:errors.append("reverse state did not finish")
	if cart.global_position!=before or cart.boarding.speed!=0 or cart.recorded_motion!=0:errors.append("finish moved vehicle or left motion active")
	if journey.distance_travelled!=0:errors.append("finish credited phantom travel")
	journey.free();cart.free()
	print("CITY CART RETREAT ","PASS" if errors.is_empty() else "FAIL"," ",errors)
	quit(0 if errors.is_empty() else 1)
