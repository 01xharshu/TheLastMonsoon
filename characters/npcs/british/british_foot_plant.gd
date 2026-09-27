extends RefCounted
## Flat-ground stance correction after AnimationTree evaluation.
var skeleton: Skeleton3D
var legs: Dictionary = {}
var ankle_height: Dictionary = {}
var planted_side := ""
var planted_world := Vector3.ZERO
var active := false
var reach_limited := false
var pelvis: int
var pelvis_position: Vector3
var pelvis_down: Vector3
var hip_drop: float = 0.008

func configure(rig: Skeleton3D) -> void:
	skeleton = rig
	pelvis = rig.find_bone("pelvis")
	pelvis_position = rig.get_bone_pose_position(pelvis)
	var parent := rig.get_bone_parent(pelvis)
	var basis := rig.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	pelvis_down = basis.inverse() * Vector3.DOWN
	for side in ["l", "r"]:
		legs[side] = [rig.find_bone("thigh_"+side), rig.find_bone("calf_"+side), rig.find_bone("foot_"+side)]
		ankle_height[side] = rig.to_global(rig.get_bone_global_pose(legs[side][2]).origin).y

func clear() -> void:
	active = false
	planted_side = ""

func reset_pose() -> void:
	skeleton.set_bone_pose_position(pelvis, pelvis_position)

func _required_drop(bones: Array, target_world: Vector3) -> float:
	var hip := skeleton.to_global(skeleton.get_bone_global_pose(bones[0]).origin)
	var knee := skeleton.to_global(skeleton.get_bone_global_pose(bones[1]).origin)
	var ankle := skeleton.to_global(skeleton.get_bone_global_pose(bones[2]).origin)
	var length := hip.distance_to(knee) + knee.distance_to(ankle) - 0.002
	var horizontal := Vector2(hip.x-target_world.x, hip.z-target_world.z).length_squared()
	var vertical := sqrt(maxf(0.0, length*length-horizontal))
	return maxf(0.008, hip.y-target_world.y-vertical)

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
	var bones: Array = legs[side]
	if side != planted_side:
		planted_side = side
		planted_world = skeleton.to_global(skeleton.get_bone_global_pose(bones[2]).origin)
		planted_world.y = ankle_height[side]
		# A restart can enter halfway through stance. Place within the remaining
		# stroke rather than pinning an already trailing animated ankle.
		var remaining := 0.75-phase if side == "l" else (0.25-phase if phase < 0.25 else 1.25-phase)
		var forward := skeleton.global_basis.z.normalized()
		var hip_world := skeleton.to_global(skeleton.get_bone_global_pose(bones[0]).origin)
		var projected := (planted_world-hip_world).dot(forward)
		planted_world += forward * (remaining*distance_per_cycle*0.5 - projected)
	hip_drop = clampf(maxf(_required_drop(bones, planted_world), _required_drop(swing, swing_target)), 0.008, 0.08)
	skeleton.set_bone_pose_position(pelvis, pelvis_position + pelvis_down * hip_drop * pose_weight)
	active = true
	_solve(bones, skeleton.to_local(planted_world))
	var contact_limited := reach_limited
	_solve(swing, skeleton.to_local(swing_target))
	reach_limited = contact_limited

func _rotate_world(index: int, from: Vector3, to: Vector3) -> void:
	if from.length_squared() < 0.000001 or to.length_squared() < 0.000001:
		return
	var orientation := skeleton.get_bone_global_pose(index).basis.get_rotation_quaternion()
	var delta := Quaternion(from.normalized(), to.normalized())
	var local_delta := orientation.inverse() * delta * orientation
	skeleton.set_bone_pose_rotation(index, skeleton.get_bone_pose_rotation(index) * local_delta)

func _solve(bones: Array, target: Vector3) -> void:
	var hip := skeleton.get_bone_global_pose(bones[0]).origin
	var knee := skeleton.get_bone_global_pose(bones[1]).origin
	var ankle := skeleton.get_bone_global_pose(bones[2]).origin
	var foot_orientation := skeleton.get_bone_global_pose(bones[2]).basis.get_rotation_quaternion()
	var upper_length := hip.distance_to(knee)
	var lower_length := knee.distance_to(ankle)
	var direction := (target-hip).normalized()
	var distance := hip.distance_to(target)
	var reachable := clampf(distance, absf(upper_length-lower_length)+0.001, upper_length+lower_length-0.0001)
	reach_limited = absf(reachable-distance)>0.001
	target = hip + direction * reachable
	var along := (upper_length*upper_length-lower_length*lower_length+reachable*reachable)/(2.0*reachable)
	var height := sqrt(maxf(0.0,upper_length*upper_length-along*along))
	# Model fronts are +Z; knee bends forward in the sagittal plane.
	var pole := Vector3.BACK - direction * direction.dot(Vector3.BACK)
	if pole.length_squared()<0.001:
		pole = Vector3.RIGHT
	var desired_knee := hip + direction*along + pole.normalized()*height
	_rotate_world(bones[0], knee-hip, desired_knee-hip)
	knee = skeleton.get_bone_global_pose(bones[1]).origin
	ankle = skeleton.get_bone_global_pose(bones[2]).origin
	_rotate_world(bones[1], ankle-knee, target-knee)
	# Keep the animated foot orientation while solving the leg position.
	var current := skeleton.get_bone_global_pose(bones[2]).basis.get_rotation_quaternion()
	var correction := current.inverse() * foot_orientation
	skeleton.set_bone_pose_rotation(bones[2], skeleton.get_bone_pose_rotation(bones[2]) * correction)
