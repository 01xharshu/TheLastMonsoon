extends AnimatableBody3D
## Physical ray target forwards damage to the actor rather than a display mesh.
var damage_receiver: Node
func take_damage(amount: float) -> void:
	var player := get_tree().root.find_child("Player",true,false)
	preload("res://combat/damage_policy.gd").apply(self,amount,player)

func receive_hit(amount: float, attacker: Node, kind: String = "weapon") -> bool:
	return preload("res://combat/damage_policy.gd").apply(self,amount,attacker,kind)
