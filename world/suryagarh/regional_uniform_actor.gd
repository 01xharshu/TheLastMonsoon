extends "res://characters/npcs/british/candidates/private_skirt_actor.gd"
## Keep the existing four-morph uniform driver when a journey owns locomotion.
## The original preview controller remains unchanged; no mesh/body is removed.
func _set_animation(state:StringName,delta:float) -> void:
 super._set_animation(state,delta)
 if skirt_mesh==null:return
 var phase:float=_walk_phase*TAU
 var strength:float=locomotion_blend if travel_speed>.001 else 0.0
 var stride:=sin(phase);var lag:=sin(phase-.65)
 var target:=Vector4(maxf(0,stride),maxf(0,-stride),maxf(0,lag)*.45,maxf(0,-lag)*.45)*strength
 cloth_values=cloth_values.lerp(target,1-exp(-maxf(delta,0)/.12))
 for index in 4:skirt_mesh.set_blend_shape_value(index,cloth_values[index])
