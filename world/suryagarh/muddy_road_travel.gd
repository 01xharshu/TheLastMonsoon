extends Node
## Attaches the same ground-aware effect to existing and new live carts.
var elapsed:=2.0
func _physics_process(delta:float) -> void:
 elapsed+=delta
 if elapsed<2:return
 elapsed=0
 for vehicle in get_tree().get_nodes_in_group("cart_parking_vehicles"):
  if vehicle.get("boarding")==null or vehicle.has_node("MudClods"):continue
  var effect:=preload("res://vehicles/cart_mud_effects.gd").new();effect.name="MudClods";effect.configure(vehicle);vehicle.add_child(effect)
