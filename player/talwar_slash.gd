extends Node
## Sword strike: the animated blade must contact the pole before it can break.
const DURATION := 0.68
const ROPE_HEIGHT := 1.25
var elapsed := DURATION
var target: Node3D
var impact_done := false
var previous_blade := PackedVector3Array()
@onready var actor: CharacterBody3D = get_parent()
@onready var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")

func strike() -> bool:
	if not available(): return false
	target = _find_target()
	visual.slash_target_world = target.global_position+Vector3.UP*ROPE_HEIGHT if is_instance_valid(target) else Vector3.ZERO
	ControllerFeedback.pulse("melee")
	elapsed = 0.0
	impact_done = false
	previous_blade = visual.equipment.sword_blade_segment()
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
		var offset: Vector3 = rope_point-actor.global_position
		if Vector2(offset.x,offset.z).length() > 1.45: continue
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
	var blade: PackedVector3Array = visual.equipment.sword_blade_segment()
	if not impact_done and is_instance_valid(target) and visual.slash_phase >= .30 and visual.slash_phase <= .82:
		var point: Vector3 = target.global_position+Vector3.UP*ROPE_HEIGHT
		var distance := point.distance_to(Geometry3D.get_closest_point_to_segment(point,blade[0],blade[1]))
		if previous_blade.size() == 2:
			for end in [0,1]:
				distance = minf(distance,point.distance_to(Geometry3D.get_closest_point_to_segment(point,previous_blade[end],blade[end])))
		if distance <= .14:
			var ray := PhysicsRayQueryParameters3D.create(blade[0],point)
			ray.exclude = [actor.get_rid()]
			var obstacle := actor.get_world_3d().direct_space_state.intersect_ray(ray)
			if obstacle.is_empty() or obstacle.collider == target:
				impact_done = true
				if target.cut_flag(): actor.get_node("FameComponent").award_flag_cut()
	previous_blade = blade
	if elapsed >= DURATION:
		visual.slash_phase = -1.0
		visual.slash_target_world = Vector3.ZERO
		target = null
