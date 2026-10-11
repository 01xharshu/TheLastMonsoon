extends "res://world/suryagarh/combat_encounters.gd"
## Flat supported test world; all capsule movement stays production code.
func _ready() -> void:set_physics_process(false)
func ground(point: Vector3, _terrain_only: bool=false) -> Vector3:
	return Vector3(point.x,0,point.z)
