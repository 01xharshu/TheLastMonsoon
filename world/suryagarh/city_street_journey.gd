extends "res://world/suryagarh/settlements/street_journey.gd"
## Keep remote residents persistent at reduced update cadence, never crowd the centre.
var viewer: Node3D
var accumulated := 0.0
func _physics_process(delta: float) -> void:
 accumulated+=delta
 var far:=is_instance_valid(viewer) and actor.global_position.distance_squared_to(viewer.global_position)>40000
 if far and accumulated<.5:return
 var step:=accumulated;accumulated=0
 if actor.get_meta("knocked_out",false) or actor.get_meta("grappled",false):return
 tick(step)
