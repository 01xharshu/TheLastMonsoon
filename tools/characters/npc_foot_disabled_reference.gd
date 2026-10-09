extends "res://characters/npcs/british/british_foot_plant.gd"
## Original disabled-foot path for exact pose and workload regression checks.
func update(phase: float, enabled: bool, pose_weight: float, distance_per_cycle: float) -> void:
	var side := "l" if cos(phase * TAU) < 0.0 else "r"
	var swing_side := "r" if side == "l" else "l"
	var swing: Array = legs[swing_side]
	var swing_target := skeleton.to_global(skeleton.get_bone_global_pose(swing[2]).origin)
	swing_target.y = maxf(swing_target.y, float(ankle_height[swing_side]) + 0.035 * absf(cos(phase * TAU)))
	if not enabled:
		skeleton.set_bone_pose_position(pelvis, pelvis_position + pelvis_down * hip_drop * pose_weight)
		clear()
		return
	super.update(phase,enabled,pose_weight,distance_per_cycle)
