extends Node3D
## Existing weapons, one visible copy each. H controls the selected weapon.
const TALWAR = preload("res://environment/weapons/Talwar/weapon_talwar_01.glb")
const ENFIELD = preload("res://environment/weapons/enfield_p53/weapon_enfield_p53_01.glb")
enum Selection { TALWAR, ENFIELD }
var selected: Selection = Selection.TALWAR
var stowed := true
var inventory: InventoryComponent
var swimming := false
var skeleton: Skeleton3D
var talwar_hand: Node3D
var talwar_waist: Node3D
var enfield_hand: Node3D
var enfield_back: Node3D
var rifle_grip := Vector3(-0.14, -0.012, 0)
var rifle_support := Vector3(0.20, 0.012, 0)
var palm_offsets: Dictionary = {}
var palm_axes: Dictionary = {}
var rest_rotations: Dictionary = {}
var aiming := false
var aim_direction := Vector3.FORWARD
var recoil := 0.0
var rifle_rest_transform := Transform3D.IDENTITY

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
	for i in skeleton.get_bone_count():
		rest_rotations[skeleton.get_bone_name(i)] = skeleton.get_bone_pose_rotation(i)
	for side_name in ["r", "l"]:
		var hand := skeleton.get_bone_global_rest(skeleton.find_bone("hand_"+side_name))
		var index := skeleton.get_bone_global_rest(skeleton.find_bone("index_01_"+side_name)).origin
		var pinky := skeleton.get_bone_global_rest(skeleton.find_bone("pinky_01_"+side_name)).origin
		var middle := skeleton.get_bone_global_rest(skeleton.find_bone("middle_01_"+side_name)).origin
		var middle_tip := skeleton.get_bone_global_rest(skeleton.find_bone("middle_02_"+side_name)).origin
		var thumb := skeleton.get_bone_global_rest(skeleton.find_bone("thumb_02_"+side_name)).origin
		var across := (index-pinky).normalized()
		var forward := (middle_tip-middle).normalized()
		forward = (forward-across*forward.dot(across)).normalized()
		var normal := across.cross(forward).normalized()
		if normal.dot(thumb-middle)<0:
			normal = -normal
			across = -across
		var centre := (index+pinky+middle)/3.0 + normal*.023 - forward*.005
		palm_offsets[side_name] = hand.affine_inverse()*centre
		palm_axes[side_name] = hand.basis.inverse()*Basis(across,forward,normal)
	# Talwar grip centre in its source GLB; +X is the blade direction.
	var hand_rest := skeleton.get_bone_global_rest(skeleton.find_bone("hand_r"))
	var blade_basis: Basis = hand_rest.basis*palm_axes["r"]
	var hand_placement := Transform3D(blade_basis, hand_rest*palm_offsets["r"] - blade_basis * Vector3(-0.095, -0.002, 0))
	talwar_hand = attach_at_rest("hand_r", TALWAR, hand_placement, "TalwarHeld")
	var blade_axis := Vector3(0, -0.96, -0.28).normalized()
	var waist_basis := Basis(blade_axis, Vector3.RIGHT, blade_axis.cross(Vector3.RIGHT))
	talwar_waist = attach_at_rest("pelvis", TALWAR, Transform3D(waist_basis, Vector3(0.27, 0.94, -0.05)), "TalwarStowed")
	var barrel := Vector3(-0.25, 0.968, 0).normalized()
	var back_up := Vector3(0, 0, 1)
	var back_basis := Basis(barrel, back_up, barrel.cross(back_up))
	enfield_back = attach_at_rest("spine_03", ENFIELD, Transform3D(back_basis, Vector3(0.09, 0.86, -0.19)), "EnfieldStowed")
	# Low ready, both hands supporting the existing stock. Not a firing implementation.
	barrel = Vector3(0.5, -0.12, 0.858).normalized()
	var side := barrel.cross(Vector3.UP).normalized()
	var gun_basis := Basis(barrel, side.cross(barrel), side)
	var grip_position := Vector3(-0.16, 1.12, 0.16)
	enfield_hand = attach_at_rest("spine_03", ENFIELD, Transform3D(gun_basis, grip_position - gun_basis * rifle_grip), "EnfieldHeld")
	rifle_rest_transform = enfield_hand.transform
	_refresh()

func select_weapon(value: Selection) -> void:
	if not owns(value): return
	selected = value
	_refresh()

func owns(value: Selection) -> bool:
	if inventory == null: return false
	return inventory.has_item("talwar" if value == Selection.TALWAR else "enfield")

func toggle_stowed() -> void:
	if swimming: return
	if stowed and not owns(selected): return
	stowed = not stowed
	_refresh()

func set_swimming(value: bool) -> void:
	swimming = value
	if value: stowed = true
	_refresh()

func _refresh() -> void:
	if talwar_hand == null: return
	talwar_hand.visible = owns(Selection.TALWAR) and not stowed and selected == Selection.TALWAR
	talwar_waist.visible = owns(Selection.TALWAR) and not talwar_hand.visible
	enfield_hand.visible = owns(Selection.ENFIELD) and not stowed and selected == Selection.ENFIELD
	enfield_back.visible = owns(Selection.ENFIELD) and not enfield_hand.visible

func held_name() -> String:
	if stowed or not owns(selected): return "UNARMED" if not owns(Selection.TALWAR) and not owns(Selection.ENFIELD) else "STOWED"
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
	var pole := Vector3(0.65 if side == "l" else -0.65, -0.7, -0.1)
	pole = (pole - direction * pole.dot(direction)).normalized()
	var along := (a * a - b * b + distance * distance) / (2.0 * distance)
	var elbow := origin + direction * along + pole * sqrt(maxf(0, a * a - along * along))
	_aim_bone(upper, elbow, lower)
	_aim_bone(lower, origin + direction * distance, hand)

func apply_rifle_grip() -> void:
	if stowed: return
	if selected == Selection.TALWAR:
		apply_sword_rest()
		_grasp("r")
		return
	if aiming:
		var barrel := (skeleton.global_basis.inverse()*aim_direction).normalized()
		var side_axis := barrel.cross(Vector3.UP).normalized()
		if side_axis.length_squared() < 0.1: side_axis = Vector3.LEFT
		var gun_basis := Basis(barrel,side_axis.cross(barrel),side_axis)
		var grip := Vector3(-0.16,1.34,0.13)-barrel*recoil
		enfield_hand.global_transform = skeleton.global_transform*Transform3D(gun_basis,grip-gun_basis*rifle_grip)
	else:
		enfield_hand.transform = rifle_rest_transform
	# Compute contacts from the weapon transform, so both hands follow torso motion.
	skeleton.force_update_all_bone_transforms()
	var gun_transform := skeleton.global_transform.affine_inverse() * enfield_hand.global_transform
	for pass_index in 10:
		for side in ["r", "l"]:
			var hand := skeleton.get_bone_global_pose(skeleton.find_bone("hand_"+side))
			var contact: Vector3 = gun_transform * (rifle_grip if side=="r" else rifle_support)
			_solve_arm(side,contact-hand.basis*palm_offsets[side])
	_grasp("r")
	_grasp("l")

func _rotate_digit(name: String, axis: Vector3, angle: float) -> void:
	var index := skeleton.find_bone(name)
	var current := skeleton.get_bone_global_pose(index)
	var basis := Basis(Quaternion(axis.normalized(),angle))*current.basis
	var parent := skeleton.get_bone_parent(index)
	basis = skeleton.get_bone_global_pose(parent).basis.inverse()*basis
	skeleton.set_bone_pose_rotation(index,basis.orthonormalized().get_rotation_quaternion())
	skeleton.force_update_all_bone_transforms()

func _grasp(side: String) -> void:
	# Flex in the actual palm plane. The thumb opposes the fingers independently.
	for finger in ["index","middle","ring","pinky","thumb"]:
		for joint in ["01","02","03"]:
			var name: String = finger+"_"+joint+"_"+side
			skeleton.set_bone_pose_rotation(skeleton.find_bone(name),rest_rotations[name])
	skeleton.force_update_all_bone_transforms()
	var hand := skeleton.get_bone_global_pose(skeleton.find_bone("hand_"+side))
	var palm: Basis = hand.basis*palm_axes[side]
	for finger in ["index","middle","ring","pinky"]:
		_rotate_digit(finger+"_01_"+side,palm.x,1.02)
		_rotate_digit(finger+"_02_"+side,palm.x,0.80)
		_rotate_digit(finger+"_03_"+side,palm.x,0.52)
	_rotate_digit("thumb_01_"+side,palm.y,-0.55 if side=="r" else 0.55)
	_rotate_digit("thumb_02_"+side,palm.x,0.75)
	_rotate_digit("thumb_03_"+side,palm.x,0.45)

func grip_errors() -> Dictionary:
	var gun_transform := skeleton.global_transform.affine_inverse() * enfield_hand.global_transform
	return {
		"right_palm_m": (skeleton.get_bone_global_pose(skeleton.find_bone("hand_r"))*palm_offsets["r"]).distance_to(gun_transform * rifle_grip),
		"left_palm_m": (skeleton.get_bone_global_pose(skeleton.find_bone("hand_l"))*palm_offsets["l"]).distance_to(gun_transform * rifle_support)
	}

func apply_sword_rest() -> void:
	# Relax the right arm; keep the blade down and clear of the right leg.
	var hand_index := skeleton.find_bone("hand_r")
	var blade := Vector3(-0.18,-0.91,0.38).normalized()
	var across := Vector3.FORWARD.cross(blade).normalized()
	var desired := Basis(blade,across,blade.cross(across))
	var hand_basis: Basis = desired*(palm_axes["r"] as Basis).inverse()
	var contact := Vector3(-0.39,0.91,0.16)
	for i in 4:
		_solve_arm("r",contact-hand_basis*palm_offsets["r"])
		var parent := skeleton.get_bone_parent(hand_index)
		var local_basis := skeleton.get_bone_global_pose(parent).basis.inverse()*hand_basis
		skeleton.set_bone_pose_rotation(hand_index,local_basis.orthonormalized().get_rotation_quaternion())
		skeleton.force_update_all_bone_transforms()
