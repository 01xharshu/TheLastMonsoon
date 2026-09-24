extends Node
## Sword strike against a reachable checkpoint rope.
const DURATION := 0.68
const ROPE_HEIGHT := 1.25
var elapsed := DURATION
var target: Node3D
var impact_done := false
@onready var actor: CharacterBody3D = get_parent()
@onready var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")

func strike() -> bool:
	if not available(): return false
	target = _find_target()
	ControllerFeedback.pulse("melee")
	elapsed = 0.0
	impact_done = false
	return true

func available() -> bool:
	return elapsed >= DURATION and visual.equipment != null and not visual.equipment.stowed and visual.equipment.selected == 0 and not actor.is_swimming and not actor.get_meta("scroll_open",false) and not actor.get_meta("map_open",false) and not actor.get_meta("weapon_wheel_open",false) and not actor.inventory_ui.is_open() and not actor.get_meta("climbing",false) and not actor.has_meta("mounted_vehicle")

func _find_target() -> Node3D:
	var camera: Camera3D = actor.get_node("CameraPivot/SpringArm3D/Camera3D")
	var direction := -camera.global_basis.z
	var best: Node3D
	var best_alignment := 0.68
	for candidate in get_tree().get_nodes_in_group("cuttable_flags"):
		if candidate.cut: continue
		var rope_point: Vector3 = candidate.global_position + Vector3.UP * ROPE_HEIGHT
		var distance := actor.global_position.distance_to(rope_point)
		if distance > 2.15: continue
		var alignment := direction.dot((rope_point - camera.global_position).normalized())
		if alignment > best_alignment:
			best = candidate
			best_alignment = alignment
	return best

func _process(delta: float) -> void:
	if elapsed >= DURATION: return
	elapsed = minf(DURATION, elapsed + delta)
	visual.slash_phase = elapsed / DURATION
	if is_instance_valid(target):
		var toward: Vector3 = target.global_position - actor.global_position
		if toward.length_squared() > 0.001:
			actor.get_node("VisualRoot").global_rotation.y = atan2(toward.x, toward.z)
	if not impact_done and elapsed >= DURATION * 0.47:
		impact_done = true
		if is_instance_valid(target) and actor.global_position.distance_to(target.global_position + Vector3.UP*ROPE_HEIGHT) <= 2.15:
			if target.cut_flag(): actor.get_node("FameComponent").award_flag_cut()
	if elapsed >= DURATION:
		visual.slash_phase = -1.0
		target = null
