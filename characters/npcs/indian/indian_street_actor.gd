extends "res://characters/npcs/households/household_npc_actor.gd"
## Stable personal identity; female fabric follows the actual retained MPFB rig.
var ground_height: Callable
var drape: RefCounted
var drape_age := 0.0

func _ready() -> void:
	super._ready()
	if movement_profile == &"female" and _skeleton != null:
		drape = preload("res://characters/npcs/indian/river_sari_drape.gd").new(self, _skeleton)
		drape.update()
	elif _skeleton != null:
		drape=preload("res://characters/npcs/indian/indian_street_dhoti.gd").new(self,_skeleton)
		drape.update()

func _set_animation(state: StringName, delta: float) -> void:
	super._set_animation(state, delta)
	if drape == null:return
	drape_age += delta
	var camera := get_viewport().get_camera_3d()
	var near := camera != null and global_position.distance_squared_to(camera.global_position)<3600.0
	if near or (drape_age>.5 and DisplayServer.get_name()!="headless"):
		drape_age=0.0;drape.update()
