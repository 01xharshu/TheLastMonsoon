extends Node
## Short reach utility blade. Uses the same damage interface as firearms.
const DURATION := .55
var cooldown := 0.0
var elapsed := -1.0
var landed := false
var previous_blade:=PackedVector3Array()
@onready var actor: CharacterBody3D = get_parent()
@onready var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
@onready var camera: Camera3D = actor.get_node("CameraPivot/SpringArm3D/Camera3D")
func _ready() -> void:
	set_process(false)

func _process(delta: float) -> void:
	cooldown = maxf(0.0,cooldown-delta)
	if actor.get_meta("detention_action","")!="":elapsed=-1;visual.knife_phase=-1;return
	if elapsed<0:
		if cooldown<=0:set_process(false)
		return
	elapsed+=delta;visual.knife_phase=minf(elapsed/.55,1)
	var blade: PackedVector3Array=visual.equipment.knife_blade_segment()
	if not landed and visual.knife_phase>=.30 and visual.knife_phase<=.82:
		var segments: Array=[[blade[0],blade[1]]]
		if previous_blade.size()==2:
			segments.append([previous_blade[0],blade[0]])
			segments.append([previous_blade[1],blade[1]])
		for segment in segments:
			var query:=PhysicsRayQueryParameters3D.create(segment[0],segment[1])
			query.exclude=[actor.get_rid()]
			var hit:=actor.get_world_3d().direct_space_state.intersect_ray(query)
			if hit.is_empty():continue
			var sight:=PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*.25,hit.position)
			sight.exclude=[actor.get_rid()]
			var obstacle:=actor.get_world_3d().direct_space_state.intersect_ray(sight)
			var policy=preload("res://combat/damage_policy.gd")
			if not obstacle.is_empty() and policy.receiver(obstacle.collider)!=policy.receiver(hit.collider):continue
			if policy.apply(hit.collider,18,actor,"knife"):
				WorldAudio.play_at("impact",hit.position,-18.0)
				landed=true;break
	previous_blade=blade
	if elapsed>=.55:elapsed=-1;visual.knife_phase=-1
func strike() -> bool:
	if actor.get_meta("detention_action", "") != "": return false
	if cooldown>0 or visual.equipment.stowed or visual.equipment.selected!=4 or not visual.equipment.owns(4): return false
	if actor.is_swimming or actor.has_meta("mounted_vehicle") or actor.get_meta("map_open",false) or actor.get_meta("scroll_open",false) or actor.inventory_ui.is_open(): return false
	WorldAudio.play_at("knife_slash",actor.global_position,-18.0)
	cooldown = .62
	ControllerFeedback.pulse("melee")
	set_process(true)
	elapsed=0;landed=false
	previous_blade=visual.equipment.knife_blade_segment()
	return true
