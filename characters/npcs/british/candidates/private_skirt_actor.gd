extends "res://characters/npcs/british/british_npc_actor.gd"
## Current Private/Corporal/Sergeant woman garment driver, applied to the live roster by owner request.
var skirt_mesh: MeshInstance3D
var cloth_values := Vector4.ZERO

func _ready() -> void:
	super._ready()
	for mesh_node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance.mesh.get_blend_shape_count() == 4:
			skirt_mesh = mesh_instance
			break
	assert(skirt_mesh != null, "Candidate skirt must retain four glTF morphs")

func _process(delta: float) -> void:
	super._process(delta)
	if skirt_mesh == null:
		return
	var phase := _walk_phase * TAU
	var strength := locomotion_blend if travel_speed > 0.001 else 0.0
	var stride := sin(phase)
	var lag := sin(phase - 0.65)
	var target := Vector4(maxf(0.0, stride), maxf(0.0, -stride), maxf(0.0, lag) * 0.45, maxf(0.0, -lag) * 0.45) * strength
	# Exponential relaxation avoids a hem snap when the actor waits or turns.
	cloth_values = cloth_values.lerp(target, 1.0 - exp(-maxf(delta, 0.0) / 0.12))
	for index in 4:
		skirt_mesh.set_blend_shape_value(index, cloth_values[index])
