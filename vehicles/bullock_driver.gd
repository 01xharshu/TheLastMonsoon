extends "res://vehicles/seated_coachman.gd"
## Complete existing MPFB farmer, seated on the goods-cart driver's bench.
func _process(delta:float) -> void:
 visible=coach.boarding.rider==null
 if visible:super._process(delta)
func foot_target_world(side:String) -> Vector3:
 return coach.to_global(Vector3(-.18 if side=="l" else .18,.93,1.29))
