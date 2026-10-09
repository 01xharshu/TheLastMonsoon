extends "res://world/suryagarh/combat_encounters.gd"
## Test harness retains real perception rays while recording movement targets.
var commanded_goals: Array[Vector3] = []
func _ready() -> void:
	set_process(false);set_physics_process(false)
func move_actor(_actor: Node3D, goal: Vector3, _speed: float, _delta: float) -> bool:
	commanded_goals.append(goal)
	return false
