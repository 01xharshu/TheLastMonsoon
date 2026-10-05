extends Node
## Local stair correction after the AnimationTree/visual pose; no controller motion.
@onready var actor: CharacterBody3D = get_parent()
@onready var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
var surfaces: Array[Node] = []
var refresh := 0.0
var planted: Dictionary = {}
var active_samples := 0
var max_residual := 0.0

func _ready() -> void:
	process_priority = 90

func _process(delta: float) -> void:
	refresh -= delta
	if refresh <= 0.0:
		surfaces = get_tree().get_nodes_in_group("stair_contact_surfaces")
		refresh = 1.0
	if actor.get_meta("mounted_vehicle", null) != null or actor.get_meta("climbing", false) or actor.is_swimming or not actor.is_on_floor():
		planted.clear()
		return
	var surface: Node3D
	for candidate in surfaces:
		if is_instance_valid(candidate) and candidate.global_position.distance_squared_to(actor.global_position) < 900.0:
			if candidate.support(actor.global_position - Vector3.UP * .9).is_finite():
				surface = candidate
				break
	if surface == null:
		planted.clear()
		return
	for side in ["l", "r"]:
		var index: int = visual.skeleton.find_bone("foot_" + side)
		var rest: Transform3D = visual.skeleton.get_bone_global_rest(index)
		var offset: Vector3 = rest.basis.inverse() * Vector3(0, -.085, .06)
		var sole: Vector3 = visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(index) * offset)
		var target: Vector3 = surface.support(sole)
		if not target.is_finite() or absf(target.y - sole.y) > .32:
			planted.erase(side)
			continue
		var contact := 1.0 - smoothstep(.08, .20, sole.y - target.y)
		if contact < .1:
			planted.erase(side)
			continue
		if planted.has(side):
			var previous: Vector3 = planted[side]
			if Vector2(previous.x, previous.z).distance_to(Vector2(sole.x, sole.z)) < .32:
				target = previous
			else: planted.erase(side)
		if not planted.has(side): planted[side] = target
		visual._horse_foot_contact(side, target, contact)
		var corrected: Vector3 = visual.skeleton.to_global(visual.skeleton.get_bone_global_pose(index) * offset)
		if contact > .99:
			active_samples += 1
			max_residual = maxf(max_residual, corrected.distance_to(target))
