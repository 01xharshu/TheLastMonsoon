extends Node3D
## Existing weapons, one visible copy each. H controls the selected weapon.
const TALWAR = preload("res://environment/weapons/Talwar/weapon_talwar_01.glb")
const ENFIELD = preload("res://environment/weapons/enfield_p53/weapon_enfield_p53_01.glb")
const BOW = preload("res://environment/weapons/period_bow/bow_mechanism.tscn")
const QUIVER = preload("res://environment/weapons/period_quiver/period_quiver.glb")
const PISTOL = preload("res://environment/weapons/adams_1851/adams_1851.glb")
const KNIFE = preload("res://environment/weapons/period_utility_knife/period_utility_knife.glb")
const DOUBLE_GUN = preload("res://environment/weapons/double_percussion_gun/double_percussion_gun.glb")
enum Selection { TALWAR, ENFIELD, BOW, PISTOL, KNIFE, DOUBLE_GUN }
var selected: Selection = Selection.TALWAR
var stowed := true
var inventory: InventoryComponent
var swimming := false
var skeleton: Skeleton3D
var talwar_hand: Node3D
var talwar_waist: Node3D
var enfield_hand: Node3D
var enfield_back: Node3D
var bow_hand: Node3D
var bow_back: Node3D
var quiver_back: Node3D
var pistol_hand: Node3D
var pistol_hip: Node3D
var knife_hand: Node3D
var knife_hip: Node3D
var double_hand: Node3D
var double_back: Node3D
var double_rest_transform := Transform3D.IDENTITY
var rifle_grip := Vector3(-0.14, -0.012, 0)
var rifle_support := Vector3(0.20, 0.012, 0)
var palm_offsets: Dictionary = {}
var palm_axes: Dictionary = {}
var rest_rotations: Dictionary = {}
var aiming := false
var aim_direction := Vector3.FORWARD
var recoil := 0.0
var reload_progress := -1.0
var rifle_rest_transform := Transform3D.IDENTITY
var ramrod_rest: Dictionary = {}
const PISTOL_GRIP := Vector3(-0.126, -0.015, 0.0)
const PISTOL_SCALE := 0.78
const DOUBLE_GUN_SCALE := 0.84

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
	for part_name in ["enfield_ramrod", "enfield_ramrod_tip"]:
		var part: Node3D = enfield_hand.find_child(part_name, true, false)
		if part: ramrod_rest[part_name] = part.position
	double_hand = attach_at_rest("spine_03", DOUBLE_GUN, Transform3D(gun_basis, grip_position - gun_basis * rifle_grip), "DoubleGunHeld")
	double_hand.scale = Vector3.ONE * DOUBLE_GUN_SCALE
	double_rest_transform = double_hand.transform
	double_back = attach_at_rest("spine_03", DOUBLE_GUN, Transform3D(back_basis, Vector3(-.10,.85,-.21)), "DoubleGunStowed")
	double_back.scale = Vector3.ONE * DOUBLE_GUN_SCALE
	# Keep the bow independent of the left hand so both arms can meet real contact points.
	var bow_axis := Vector3(.75,0,.66).normalized()
	var bow_basis := Basis(bow_axis,Vector3.UP,bow_axis.cross(Vector3.UP))
	bow_hand = attach_at_rest("spine_03", BOW, Transform3D(bow_basis,Vector3(.22,1.35,.48)), "BowHeld")
	bow_back = attach_at_rest("spine_03", BOW, Transform3D(Basis(Vector3.UP, -0.22),Vector3(-0.30,1.08,-0.24)), "BowStowed")
	quiver_back = attach_at_rest("spine_03", QUIVER, Transform3D(Basis.IDENTITY,Vector3(0.27,0.99,-0.25)), "QuiverBack")
	var right_palm: Vector3 = skeleton.get_bone_global_rest(skeleton.find_bone("hand_r")) * palm_offsets["r"]
	pistol_hand = attach_at_rest("hand_r", PISTOL, Transform3D(blade_basis,right_palm-blade_basis*(PISTOL_GRIP*PISTOL_SCALE)), "PistolHeld")
	pistol_hand.scale = Vector3.ONE * PISTOL_SCALE
	pistol_hip = attach_at_rest("pelvis", PISTOL, Transform3D(Basis(Vector3.UP,0.45),Vector3(0.28,0.92,-0.08)), "PistolHolstered")
	pistol_hip.scale = Vector3.ONE * PISTOL_SCALE
	knife_hand = attach_at_rest("hand_r", KNIFE, Transform3D(blade_basis,right_palm-blade_basis*Vector3(-.045,0,0)), "KnifeHeld")
	knife_hip = attach_at_rest("pelvis", KNIFE, Transform3D(waist_basis,Vector3(-.26,.86,-.03)), "KnifeSheathed")
	_refresh()

func select_weapon(value: Selection) -> void:
	if not owns(value):
		if inventory != null: inventory.message_requested.emit("Find this weapon in Company stores")
		return
	selected = value
	stowed = swimming
	_refresh()

func owns(value: Selection) -> bool:
	if inventory == null: return false
	return inventory.has_item(["talwar","enfield","bow","pistol","utility_knife","double_gun"][int(value)])

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
	bow_hand.visible = owns(Selection.BOW) and not stowed and selected == Selection.BOW
	bow_back.visible = owns(Selection.BOW) and not bow_hand.visible
	quiver_back.visible = owns(Selection.BOW)
	pistol_hand.visible = owns(Selection.PISTOL) and not stowed and selected == Selection.PISTOL
	pistol_hip.visible = owns(Selection.PISTOL) and not pistol_hand.visible
	knife_hand.visible = owns(Selection.KNIFE) and not stowed and selected == Selection.KNIFE
	knife_hip.visible = owns(Selection.KNIFE) and not knife_hand.visible
	double_hand.visible = owns(Selection.DOUBLE_GUN) and not stowed and selected == Selection.DOUBLE_GUN
	double_back.visible = owns(Selection.DOUBLE_GUN) and not double_hand.visible

func held_name() -> String:
	if stowed or not owns(selected): return "UNARMED" if not owns(Selection.TALWAR) and not owns(Selection.ENFIELD) and not owns(Selection.BOW) and not owns(Selection.PISTOL) and not owns(Selection.KNIFE) and not owns(Selection.DOUBLE_GUN) else "STOWED"
	return ["TALWAR","ENFIELD","BOW","PISTOL","KNIFE","DOUBLE GUN"][int(selected)]

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

func apply_rifle_grip(sword_striking := false) -> void:
	animate_ramrod()
	if stowed: return
	# Back-carried long guns obstruct the close shoulder camera while aiming.
	var firearm_aim: bool = aiming and selected in [Selection.ENFIELD, Selection.PISTOL, Selection.DOUBLE_GUN]
	enfield_back.visible = owns(Selection.ENFIELD) and not enfield_hand.visible and not firearm_aim
	double_back.visible = owns(Selection.DOUBLE_GUN) and not double_hand.visible and not firearm_aim
	if selected == Selection.TALWAR or selected == Selection.KNIFE:
		if not sword_striking: apply_sword_rest()
		_grasp("r")
		return
	if selected == Selection.BOW:
		apply_bow_grip()
		_grasp("l")
		if bow_hand.draw_fraction > 0.02: _grasp("r")
		return
	if selected == Selection.PISTOL:
		apply_pistol_grip()
		_grasp("r", 0.9)
		return
	var longgun: Node3D = double_hand if selected == Selection.DOUBLE_GUN else enfield_hand
	var gun_scale := DOUBLE_GUN_SCALE if selected == Selection.DOUBLE_GUN else 1.0
	if reload_progress >= 0.0:
		# Bring the muzzle up for loading while the right hand keeps the stock grip.
		var barrel := Vector3(0.18,0.94,0.28).normalized()
		var side_axis := barrel.cross(Vector3.UP).normalized()
		var gun_basis := Basis(barrel,side_axis.cross(barrel),side_axis)
		var grip := Vector3(-0.20,1.00,0.18)
		longgun.global_transform = skeleton.global_transform * Transform3D(gun_basis.scaled(Vector3.ONE*gun_scale),grip-gun_basis*(rifle_grip*gun_scale))
	elif aiming:
		var barrel := (skeleton.global_basis.inverse()*aim_direction).normalized()
		var side_axis := barrel.cross(Vector3.UP).normalized()
		if side_axis.length_squared() < 0.1: side_axis = Vector3.LEFT
		var gun_basis := Basis(barrel,side_axis.cross(barrel),side_axis)
		var grip := Vector3(-0.16,1.51,0.13)-barrel*recoil
		longgun.global_transform = skeleton.global_transform*Transform3D(gun_basis.scaled(Vector3.ONE*gun_scale),grip-gun_basis*(rifle_grip*gun_scale))
	else:
		longgun.transform = double_rest_transform if selected == Selection.DOUBLE_GUN else rifle_rest_transform
	# Compute contacts from the weapon transform, so both hands follow torso motion.
	skeleton.force_update_all_bone_transforms()
	var gun_transform := skeleton.global_transform.affine_inverse() * longgun.global_transform
	for pass_index in 10:
		for side in ["r", "l"]:
			var hand := skeleton.get_bone_global_pose(skeleton.find_bone("hand_"+side))
			var support := rifle_support
			if side == "l" and reload_progress >= 0.0:
				var pouch := Vector3(0.10,0.87,0.20)
				var muzzle: Vector3 = gun_transform * Vector3(0.78,0.02,0)
				var reach := smoothstep(0.20,0.38,reload_progress) * (1.0-smoothstep(0.79,0.98,reload_progress))
				var pocket := smoothstep(0.02,0.18,reload_progress) * (1.0-smoothstep(0.20,0.38,reload_progress))
				var target := (gun_transform * rifle_support).lerp(pouch,pocket)
				support = gun_transform.affine_inverse() * target.lerp(muzzle,reach)
			var contact: Vector3 = gun_transform * (rifle_grip if side=="r" else support)
			_solve_arm(side,contact-hand.basis*palm_offsets[side])
	_grasp("r")
	_grasp("l")

func animate_ramrod() -> void:
	var extension := 0.0
	if not stowed and selected == Selection.ENFIELD and reload_progress >= 0.0:
		extension = 0.28 * smoothstep(0.36,0.55,reload_progress) * (1.0-smoothstep(0.69,0.86,reload_progress))
	for part_name in ramrod_rest:
		var part: Node3D = enfield_hand.find_child(part_name, true, false)
		if part: part.position = (ramrod_rest[part_name] as Vector3) + Vector3(extension,0,0)

func _rotate_digit(name: String, axis: Vector3, angle: float) -> void:
	var index := skeleton.find_bone(name)
	var current := skeleton.get_bone_global_pose(index)
	var basis := Basis(Quaternion(axis.normalized(),angle))*current.basis
	var parent := skeleton.get_bone_parent(index)
	basis = skeleton.get_bone_global_pose(parent).basis.inverse()*basis
	skeleton.set_bone_pose_rotation(index,basis.orthonormalized().get_rotation_quaternion())
	skeleton.force_update_all_bone_transforms()

func _grasp(side: String, amount: float = 1.0) -> void:
	# Flex in the actual palm plane. The thumb opposes the fingers independently.
	for finger in ["index","middle","ring","pinky","thumb"]:
		for joint in ["01","02","03"]:
			var name: String = finger+"_"+joint+"_"+side
			skeleton.set_bone_pose_rotation(skeleton.find_bone(name),rest_rotations[name])
	skeleton.force_update_all_bone_transforms()
	var hand := skeleton.get_bone_global_pose(skeleton.find_bone("hand_"+side))
	var palm: Basis = hand.basis*palm_axes[side]
	for finger in ["index","middle","ring","pinky"]:
		var base_curl := 0.78 if finger == "index" and selected == Selection.PISTOL else 1.34
		_rotate_digit(finger+"_01_"+side,palm.x,base_curl*amount)
		_rotate_digit(finger+"_02_"+side,palm.x,0.96*amount)
		_rotate_digit(finger+"_03_"+side,palm.x,0.58*amount)
	_rotate_digit("thumb_01_"+side,palm.y,(-0.55 if side=="r" else 0.55)*amount)
	_rotate_digit("thumb_02_"+side,palm.x,0.75*amount)
	_rotate_digit("thumb_03_"+side,palm.x,0.45*amount)

func grip_errors() -> Dictionary:
	var longgun: Node3D = double_hand if selected == Selection.DOUBLE_GUN else enfield_hand
	var gun_transform := skeleton.global_transform.affine_inverse() * longgun.global_transform
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

func apply_sword_strike(progress: float, target_world: Vector3) -> void:
	# Carry the palm and blade through one shared impact point instead of rotating
	# the arm while the held blade remains at its rest transform.
	var impact: Vector3 = skeleton.to_local(target_world) if target_world != Vector3.ZERO else Vector3(0,1.25,1.1)
	var toward := (impact-Vector3(-.30,1.04,.18)).normalized()
	var wind_blade := Vector3(-.20,.85,.48).normalized()
	var follow_blade := Vector3(.82,-.25,.52).normalized()
	var wind_hand := Vector3(-.25,1.38,-.06)
	var hit_hand := impact-toward*.62
	var follow_hand := Vector3(.18,.95,.40)
	var sweep := smoothstep(.16,.52,progress)
	var finish := smoothstep(.55,.85,progress)
	var contact: Vector3 = wind_hand.lerp(hit_hand,sweep).lerp(follow_hand,finish)
	var blade: Vector3 = wind_blade.lerp(toward,sweep).lerp(follow_blade,finish).normalized()
	var across := Vector3.UP.cross(blade).normalized()
	if across.length_squared()<.01: across = Vector3.RIGHT
	var desired := Basis(blade,across,blade.cross(across))
	var hand_basis: Basis = desired*(palm_axes["r"] as Basis).inverse()
	var hand_index := skeleton.find_bone("hand_r")
	for i in 4:
		_solve_arm("r",contact-hand_basis*palm_offsets["r"])
		var parent := skeleton.get_bone_parent(hand_index)
		var local_basis := skeleton.get_bone_global_pose(parent).basis.inverse()*hand_basis
		skeleton.set_bone_pose_rotation(hand_index,local_basis.orthonormalized().get_rotation_quaternion())
		skeleton.force_update_all_bone_transforms()

func apply_pistol_grip() -> void:
	# The short barrel follows the camera while the right palm meets the wood grip.
	skeleton.force_update_all_bone_transforms()
	var barrel := (skeleton.global_basis.inverse()*aim_direction).normalized() if aiming else Vector3(0.38,-0.25,0.89).normalized()
	var side_axis := barrel.cross(Vector3.UP).normalized()
	var basis := Basis(barrel,side_axis.cross(barrel),side_axis)
	var hand_target := Vector3(-0.30,1.40,0.72) if aiming else Vector3(-0.36,1.04,0.20)
	if reload_progress >= 0.0: hand_target = Vector3(-0.24,1.10,0.27)
	# The pistol's imported barrel runs along local +X. Derive the wrist from
	# its actual socket orientation so the visible barrel follows the camera.
	var hand_basis: Basis = basis * pistol_hand.transform.basis.inverse()
	var hand_index := skeleton.find_bone("hand_r")
	for i in 6:
		_solve_arm("r",hand_target-hand_basis*palm_offsets["r"])
		var parent := skeleton.get_bone_parent(hand_index)
		var local_basis := skeleton.get_bone_global_pose(parent).basis.inverse()*hand_basis
		skeleton.set_bone_pose_rotation(hand_index,local_basis.orthonormalized().get_rotation_quaternion())
		skeleton.force_update_all_bone_transforms()
	if reload_progress >= 0.0:
		var cylinder: Vector3 = skeleton.to_local(pistol_hand.to_global(Vector3(-0.048,0.063,0)))
		var pouch := Vector3(0.10,0.88,0.18)
		var reach := smoothstep(0.24,0.42,reload_progress) * (1.0-smoothstep(0.83,0.97,reload_progress))
		var contact := pouch.lerp(cylinder,reach)
		for i in 6:
			var left := skeleton.get_bone_global_pose(skeleton.find_bone("hand_l"))
			_solve_arm("l",contact-left.basis*palm_offsets["l"])
		_grasp("l")

func apply_bow_grip() -> void:
	# Both palms follow the bow geometry; the right hand follows the moving nock.
	skeleton.force_update_all_bone_transforms()
	var draw: float = bow_hand.draw_fraction
	var bow_transform := skeleton.global_transform.affine_inverse() * bow_hand.global_transform
	var grip: Vector3 = bow_transform.origin
	var nock: Vector3 = bow_transform * Vector3(-0.12-0.30*draw,0,0)
	for i in 10:
		for side in ["l", "r"]:
			var hand := skeleton.get_bone_global_pose(skeleton.find_bone("hand_"+side))
			var contact: Vector3 = grip if side == "l" else nock
			_solve_arm(side,contact-hand.basis*palm_offsets[side])

func held_contact_errors() -> Dictionary:
	skeleton.force_update_all_bone_transforms()
	var right_palm: Vector3 = skeleton.global_transform * (skeleton.get_bone_global_pose(skeleton.find_bone("hand_r")) * palm_offsets["r"])
	var left_palm: Vector3 = skeleton.global_transform * (skeleton.get_bone_global_pose(skeleton.find_bone("hand_l")) * palm_offsets["l"])
	return {
		"pistol_palm_m": right_palm.distance_to(pistol_hand.to_global(PISTOL_GRIP)),
		"bow_palm_m": left_palm.distance_to(bow_hand.global_position),
		"bow_nock_m": right_palm.distance_to(bow_hand.to_global(Vector3(-0.12-0.30*bow_hand.draw_fraction,0,0)))
	}
