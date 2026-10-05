extends RefCounted
## Analytic two-bone reach in skeleton space, without stretch or translation.
static func point(rig: Skeleton3D, label: String) -> Vector3:
	return rig.get_bone_global_pose(rig.find_bone(label)).origin

static func aim(rig: Skeleton3D, index: int, from: Vector3, to: Vector3) -> void:
	if from.length_squared() < .0000001 or to.length_squared() < .0000001: return
	var basis := rig.get_bone_global_pose(index).basis.orthonormalized()
	var turn := Quaternion(from.normalized(), to.normalized())
	var local_turn := basis.inverse() * Basis(turn) * basis
	rig.set_bone_pose_rotation(index, (rig.get_bone_pose_rotation(index) * local_turn.get_rotation_quaternion()).normalized())

static func reach(rig: Skeleton3D, upper: String, lower: String, tip: String, world_target: Vector3, world_pole: Vector3) -> float:
	var target := rig.global_transform.affine_inverse() * world_target
	var pole := rig.global_transform.affine_inverse() * world_pole
	var root := point(rig, upper)
	var middle := point(rig, lower)
	var end := point(rig, tip)
	var a := root.distance_to(middle)
	var b := middle.distance_to(end)
	var offset := target - root
	var distance := clampf(offset.length(), absf(a-b) + .0001, a+b-.0001)
	var direction := offset.normalized()
	var pole_direction := pole-root
	pole_direction -= direction * pole_direction.dot(direction)
	if pole_direction.length_squared() < .00001: pole_direction = direction.cross(Vector3.RIGHT)
	pole_direction = pole_direction.normalized()
	var along := (a*a + distance*distance - b*b) / (2.0 * distance)
	var height := sqrt(maxf(0.0, a*a-along*along))
	var elbow := root + direction * along + pole_direction * height
	aim(rig, rig.find_bone(upper), middle-root, elbow-root)
	middle = point(rig, lower)
	end = point(rig, tip)
	aim(rig, rig.find_bone(lower), end-middle, target-middle)
	return (rig.global_transform * point(rig, tip)).distance_to(world_target)

static func orient(rig: Skeleton3D, label: String, world_basis: Basis) -> void:
	var index := rig.find_bone(label)
	var desired := rig.global_basis.inverse() * world_basis
	var current := rig.get_bone_global_pose(index).basis
	var local_turn := current.inverse() * desired
	rig.set_bone_pose_rotation(index, (rig.get_bone_pose_rotation(index) * local_turn.get_rotation_quaternion()).normalized())
