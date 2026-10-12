extends "res://world/suryagarh/combat_encounters.gd"
## Focused movement fixture: retain production ground/sweep/contact methods.
func _ready() -> void:
 set_process(false)
 set_physics_process(false)
 patrol_terrain = preload("res://world/suryagarh/tree_trunk_collision.gd").terrain_cache(self)
func _process(_delta: float) -> void: pass
func _physics_process(_delta: float) -> void: pass
