extends Node
## Short reach utility blade. Uses the same damage interface as firearms.
const REACH := 1.45
var cooldown := 0.0
var elapsed := -1.0
var landed := false
@onready var actor: CharacterBody3D = get_parent()
@onready var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
@onready var camera: Camera3D = actor.get_node("CameraPivot/SpringArm3D/Camera3D")
func _process(delta: float) -> void:
	cooldown = maxf(0.0,cooldown-delta)
	if actor.get_meta("detention_action","")!="":elapsed=-1;visual.knife_phase=-1;return
	if elapsed<0:return
	elapsed+=delta;visual.knife_phase=minf(elapsed/.55,1)
	if not landed and visual.knife_phase>=.45:
		landed=true
		var from:=actor.global_position+Vector3.UP*.25
		var query:=PhysicsRayQueryParameters3D.create(from,from-camera.global_basis.z*REACH)
		query.exclude=[actor.get_rid()]
		var hit:=actor.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():preload("res://combat/damage_policy.gd").apply(hit.collider,18,actor,"knife")
	if elapsed>=.55:elapsed=-1;visual.knife_phase=-1
func strike() -> bool:
	if actor.get_meta("detention_action", "") != "": return false
	if cooldown>0 or visual.equipment.stowed or visual.equipment.selected!=4 or not visual.equipment.owns(4): return false
	if actor.is_swimming or actor.has_meta("mounted_vehicle") or actor.get_meta("map_open",false) or actor.get_meta("scroll_open",false) or actor.inventory_ui.is_open(): return false
	cooldown = .62
	ControllerFeedback.pulse("melee")
	elapsed=0;landed=false
	return true
