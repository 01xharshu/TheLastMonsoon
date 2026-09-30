extends AnimatableBody3D
## Physical ray target forwards damage to the actor rather than a display mesh.
var damage_receiver: Node
func take_damage(amount: float) -> void:
	if is_instance_valid(damage_receiver) and damage_receiver.has_method("take_damage"):
		damage_receiver.take_damage(amount)
