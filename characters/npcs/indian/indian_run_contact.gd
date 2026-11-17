extends "res://characters/npcs/british/british_foot_plant.gd"
## Short stance windows and an unplanted flight interval for the Indian run.
const STANCE_FRACTION := 0.32
var actor: Node3D

func setup(owner: Node3D, rig: Skeleton3D) -> void:
	actor = owner
	configure(rig)
	for side in ankle_height:
		ankle_height[side] = float(ankle_height[side]) - actor.global_position.y

func update_run(phase: float, weight: float) -> void:
	reset_pose()
	var half_phase := fposmod(phase, 0.5)
	if weight < 0.95 or half_phase >= STANCE_FRACTION:
		clear()
		return
	var side := "l" if phase < 0.5 else "r"
	var bones: Array = legs[side]
	if planted_side != side:
		planted_side = side
		planted_world = skeleton.to_global(skeleton.get_bone_global_pose(bones[2]).origin)
		var height := actor.global_position.y
		var ground: Callable = actor.ground_height
		if ground.is_valid():
			height = float(ground.call(planted_world.x, planted_world.z))
		planted_world.y = height + float(ankle_height[side])
		var forward := actor.global_basis.z.normalized()
		var hip_world := skeleton.to_global(skeleton.get_bone_global_pose(bones[0]).origin)
		var stroke := (STANCE_FRACTION - half_phase) * 0.72 * float(actor.travel_speed)
		planted_world += forward * (stroke * 0.5 - (planted_world - hip_world).dot(forward))
	hip_drop = clampf(_required_drop(bones, planted_world), 0.008, 0.08)
	skeleton.set_bone_pose_position(pelvis, pelvis_position + pelvis_down * hip_drop * weight)
	_solve(bones, skeleton.to_local(planted_world))
	skeleton.force_update_all_bone_transforms()
	active = true
