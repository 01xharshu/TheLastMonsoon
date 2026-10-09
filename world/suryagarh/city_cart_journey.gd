extends "res://vehicles/bullock_road_journey.gd"
## Existing clearance/grounding/boarding behavior with traffic spacing and progress.
var distance_travelled := 0.0
func _physics_process(delta: float) -> void:
 if cart==null:return
 # Real cart bounds still govern movement; this look-ahead prevents rear shunts.
 for other:Node3D in get_tree().get_nodes_in_group("city_route_carts"):
  if other==cart:continue
  var offset:=cart.to_local(other.global_position)
  if absf(offset.x)<2.3 and offset.z<0 and offset.z> -9:
   cart.boarding.speed=0;cart.set_forward_motion(0,delta);return
 var before:=cart.global_position
 super._physics_process(delta)
 distance_travelled+=before.distance_to(cart.global_position)
