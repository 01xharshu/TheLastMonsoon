extends Node
## Blend the final seated contact solve into the ordinary locomotion/contact
## owners. This runs after those owners, so their first correction cannot snap.
var previous := {}
@onready var component: Node = get_parent()
@onready var actor: CharacterBody3D = component.get_parent()
@onready var visual: Node3D = actor.get_node("VisualRoot/CharacterVisual")
const BONES := ["thigh_l","thigh_r","calf_l","calf_r","foot_l","foot_r","upperarm_l","upperarm_r","lowerarm_l","lowerarm_r","hand_l","hand_r"]
func _ready() -> void:
	process_priority = 95
func _process(delta: float) -> void:
	if visual.skeleton == null: return
	var rig: Skeleton3D = visual.skeleton
	if component.seat <= 0.0 and component.recovery_time <= 0.0:
		previous.clear()
		return
	for name in BONES:
		var index: int = visual.bones[name]
		var goal := rig.get_bone_pose_rotation(index)
		if component.seat <= 0.0 and previous.has(name):
			var from: Quaternion = previous[name]
			var angle := from.angle_to(goal)
			goal = from.slerp(goal,minf(1.0,minf(delta,1.0/30.0)*6.0/maxf(angle,.001)))
			rig.set_bone_pose_rotation(index,goal)
		previous[name] = goal
	rig.force_update_all_bone_transforms()
