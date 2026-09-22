extends Node3D
## Existing weapons, one visible copy each. H controls the selected weapon.
const TALWAR = preload("res://environment/weapons/Talwar/weapon_talwar_01.glb")
const ENFIELD = preload("res://environment/weapons/enfield_p53/weapon_enfield_p53_01.glb")
enum Selection { TALWAR, ENFIELD }
var selected: Selection = Selection.TALWAR
var stowed := true
var swimming := false
var skeleton: Skeleton3D
var talwar_hand: Node3D
var talwar_waist: Node3D
var enfield_hand: Node3D
var enfield_back: Node3D
var rifle_grip := Vector3(-0.14, -0.012, 0)
var rifle_support := Vector3(0.20, 0.012, 0)

func attach_at_rest(bone: String, scene: PackedScene, placement: Transform3D, label: String) -> Node3D:
	var socket := BoneAttachment3D.new()
	socket.name = label + "Socket"
	socket.bone_name = bone
	skeleton.add_child(socket)
	var item: Node3D = scene.instantiate()
	item.name = label
	socket.add_child(item)
	item.transform = skeleton.get_bone_global_rest(skeleton.find_bone(bone)).affine_inverse() * placement
	for node in item.find_children("*", "AnimationPlayer", true, false):
		node.stop()
	for node in item.find_children("tlm_smoke_preview*", "Node3D", true, false):
		node.hide()
	return item

func setup(rig: Skeleton3D) -> void:
	skeleton = rig
	# Talwar grip centre in its source GLB; +X is the blade direction.
	var hand_rest := skeleton.get_bone_global_rest(skeleton.find_bone("hand_r"))
	var blade_basis := Basis(Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT)
	var hand_placement := Transform3D(blade_basis, hand_rest.origin + Vector3(0, -0.04, -0.035) - blade_basis * Vector3(-0.095, -0.002, 0))
	talwar_hand = attach_at_rest("hand_r", TALWAR, hand_placement, "TalwarHeld")
	var blade_axis := Vector3(0, -0.96, 0.28).normalized()
	var waist_basis := Basis(blade_axis, Vector3.RIGHT, blade_axis.cross(Vector3.RIGHT))
	talwar_waist = attach_at_rest("pelvis", TALWAR, Transform3D(waist_basis, Vector3(0.27, 0.94, 0.05)), "TalwarStowed")
	var barrel := Vector3(-0.25, 0.968, 0).normalized()
	var back_up := Vector3(0, 0, -1)
	var back_basis := Basis(barrel, back_up, barrel.cross(back_up))
	enfield_back = attach_at_rest("spine_03", ENFIELD, Transform3D(back_basis, Vector3(0.09, 0.86, 0.19)), "EnfieldStowed")
	# Low ready, both hands supporting the existing stock. Not a firing implementation.
	barrel = Vector3(0.5, -0.12, -0.858).normalized()
	var side := barrel.cross(Vector3.UP).normalized()
	var gun_basis := Basis(barrel, side.cross(barrel), side)
	var grip_position := Vector3(-0.13, 1.16, -0.075)
	enfield_hand = attach_at_rest("spine_03", ENFIELD, Transform3D(gun_basis, grip_position - gun_basis * rifle_grip), "EnfieldHeld")
	_refresh()

func select_weapon(value: Selection) -> void:
	selected = value
	_refresh()

func toggle_stowed() -> void:
	if swimming: return
	stowed = not stowed
	_refresh()

func set_swimming(value: bool) -> void:
	swimming = value
	if value: stowed = true
	_refresh()

func _refresh() -> void:
	if talwar_hand == null: return
	talwar_hand.visible = not stowed and selected == Selection.TALWAR
	talwar_waist.visible = not talwar_hand.visible
	enfield_hand.visible = not stowed and selected == Selection.ENFIELD
	enfield_back.visible = not enfield_hand.visible

func held_name() -> String:
	if stowed: return "STOWED"
	return "TALWAR" if selected == Selection.TALWAR else "ENFIELD"

func _aim_bone(name: String, endpoint: Vector3, child: String) -> void:
	var index := skeleton.find_bone(name)
	var current := skeleton.get_bone_global_pose(index)
	var child_position := skeleton.get_bone_global_pose(skeleton.find_bone(child)).origin
	var from_direction := (child_position - current.origin).normalized()
	var to_direction := (endpoint - current.origin).normalized()
	var desired := Basis(Quaternion(from_direction, to_direction)) * current.basis
	var parent := skeleton.get_bone_parent(index)
	if parent >= 0:
		desired = skeleton.get_bone_global_pose(parent).basis.inverse() * desired
	skeleton.set_bone_pose_rotation(index, desired.orthonormalized().get_rotation_quaternion())
	skeleton.force_update_all_bone_transforms()

func _solve_arm(side: String, target: Vector3) -> void:
	var upper := "upperarm_" + side
	var lower := "lowerarm_" + side
	var hand := "hand_" + side
	var origin := skeleton.get_bone_global_pose(skeleton.find_bone(upper)).origin
	var rest_upper := skeleton.get_bone_global_rest(skeleton.find_bone(upper)).origin
	var rest_lower := skeleton.get_bone_global_rest(skeleton.find_bone(lower)).origin
	var rest_hand := skeleton.get_bone_global_rest(skeleton.find_bone(hand)).origin
	var a := rest_upper.distance_to(rest_lower)
	var b := rest_lower.distance_to(rest_hand)
	var direction := (target - origin).normalized()
	var distance := clampf(origin.distance_to(target), 0.001, a + b - 0.0001)
	var pole := Vector3(0.65 if side == "l" else -0.65, -0.7, 0.1)
	pole = (pole - direction * pole.dot(direction)).normalized()
	var along := (a * a - b * b + distance * distance) / (2.0 * distance)
	var elbow := origin + direction * along + pole * sqrt(maxf(0, a * a - along * along))
	_aim_bone(upper, elbow, lower)
	_aim_bone(lower, origin + direction * distance, hand)

func apply_rifle_grip() -> void:
	if stowed or selected != Selection.ENFIELD: return
	# Compute contacts from the weapon transform, so both hands follow torso motion.
	skeleton.force_update_all_bone_transforms()
	var gun_transform := skeleton.global_transform.affine_inverse() * enfield_hand.global_transform
	_solve_arm("r", gun_transform * rifle_grip)
	_solve_arm("l", gun_transform * rifle_support)

func grip_errors() -> Dictionary:
	var gun_transform := skeleton.global_transform.affine_inverse() * enfield_hand.global_transform
	return {
		"right_wrist_m": skeleton.get_bone_global_pose(skeleton.find_bone("hand_r")).origin.distance_to(gun_transform * rifle_grip),
		"left_wrist_m": skeleton.get_bone_global_pose(skeleton.find_bone("hand_l")).origin.distance_to(gun_transform * rifle_support)
	}
