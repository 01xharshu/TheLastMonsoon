extends CharacterBody3D
var health := 100.0
func receive_combat_hit(amount: float, _attacker: Node3D) -> void:
 health = maxf(0,health-amount)
