extends "res://characters/npcs/households/household_npc_actor.gd"
## Stable personal identity; female fabric follows the actual retained MPFB rig.
var ground_height: Callable
var drape: RefCounted
var drape_age := 0.0

func _ready() -> void:
	super._ready()
	for mesh:MeshInstance3D in find_children("*","MeshInstance3D",true,false):
		if not str(mesh.name).begins_with("Street coherent cotton"):continue
		var cotton:=ShaderMaterial.new();cotton.shader=preload("res://characters/npcs/indian/street_cotton.gdshader")
		cotton.set_shader_parameter("cloth_color",Color.WHITE)
		mesh.material_override=cotton
	if movement_profile == &"female" and _skeleton != null:
		drape = preload("res://characters/npcs/indian/river_sari_drape.gd").new(self, _skeleton)
		drape.update()
	elif _skeleton != null:
		drape=preload("res://characters/npcs/indian/indian_street_dhoti.gd").new(self,_skeleton)
		drape.update()

func _set_animation(state: StringName, delta: float) -> void:
	super._set_animation(state, delta)
	if drape == null or DisplayServer.get_name()=="headless":return
	drape_age += delta
	var camera := get_viewport().get_camera_3d()
	var distance:float=global_position.distance_squared_to(camera.global_position) if camera!=null else INF
	var cadence:=0.0 if distance<400 else (.1 if distance<3600 else .5)
	if drape_age>=cadence:
		drape_age=0.0;drape.update()
