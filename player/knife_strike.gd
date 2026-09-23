extends Node
## Short reach utility blade. Uses the same damage interface as firearms.
const REACH := 1.45
var cooldown := 0.0
@onready var actor: CharacterBody3D = get_parent()
@onready var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
@onready var camera: Camera3D = actor.get_node("CameraPivot/SpringArm3D/Camera3D")
func _process(delta: float) -> void:
	cooldown = maxf(0.0,cooldown-delta)
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed: return
	if cooldown>0 or visual.equipment.stowed or visual.equipment.selected!=4 or not visual.equipment.owns(4): return
	if actor.is_swimming or actor.has_meta("mounted_vehicle") or actor.get_meta("map_open",false) or actor.get_meta("scroll_open",false) or actor.inventory_ui.is_open(): return
	cooldown = .62
	var from := camera.global_position
	var toward := -camera.global_basis.z
	var end := from+toward*REACH
	var query := PhysicsRayQueryParameters3D.create(from,end)
	query.exclude = [actor.get_rid()]
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider.has_method("take_damage"):
		hit.collider.take_damage(18.0)
	get_viewport().set_input_as_handled()
