extends RefCounted
## Opening-only contact overlay after the existing locomotion AnimationTree.
var wick_gap := 0.0
var palm_gap := 0.0
var carry_gap := 0.0

func update(scene, t: float) -> void:
	var rig: Skeleton3D = scene.visual.skeleton
	var equipment = scene.visual.equipment
	if equipment == null or t >= 9.0: return
	# Held away from the clothing; lifted after lighting, lowered onto the table.
	var base := Vector3(-2.60,0.96,0.70)
	var lift := smoothstep(6.2,6.9,t)*(1.0-smoothstep(7.5,8.4,t))
	scene.lamp.position = base + Vector3(0,0.14,0.04)*lift
	var left_grip: Vector3 = scene.lamp.to_global(Vector3(-0.15,0.59,0.10))
	var hold := smoothstep(0.4,1.3,t)*(1.0-smoothstep(8.3,9.0,t))
	carry_gap = _hand(scene,"l",left_grip,hold,.52)
	# Strike along a rough pad held beside the lantern, approach the wick,
	# dwell during ignition, withdraw and blow out before lowering the hand.
	var wick: Vector3 = scene.lamp.get_node("WickContact").global_position
	var strike: Vector3 = scene.home.to_global(Vector3(-2.50,1.23,0.96))
	var tip := strike
	if t < 2.5:
		tip += scene.home.global_basis*Vector3(.055*(smoothstep(2.1,2.5,t)-.5),0,0)
	elif t < 5.0:
		tip = strike.lerp(wick,smoothstep(2.5,5.0,t))
	elif t < 5.9:
		tip = wick
	else:
		tip = wick.lerp(scene.home.to_global(Vector3(-2.5,1.32,1.03)),smoothstep(5.9,6.6,t))
	var axis: Vector3 = (scene.home.global_basis*Vector3(0,-.5,-.866)).normalized()
	var across: Vector3 = (scene.home.global_basis*Vector3.RIGHT).normalized()
	var basis := Basis(across,axis,across.cross(axis)).orthonormalized()
	# Cylinder head and flame sit at local y .0275 / .038 respectively.
	scene.match_prop.global_transform = Transform3D(basis,tip-axis*.038)
	var pinch: Vector3 = tip-axis*.058
	palm_gap = _hand(scene,"r",pinch,1.0,.32)
	wick_gap = tip.distance_to(wick)
	scene.actor.set_meta("opening_wick_gap",wick_gap)
	scene.actor.set_meta("opening_palm_gap",palm_gap)
	scene.actor.set_meta("opening_carry_gap",carry_gap)

func _hand(scene, side: String, target: Vector3, amount: float, curl: float) -> float:
	var rig: Skeleton3D = scene.visual.skeleton
	var equipment = scene.visual.equipment
	rig.force_update_all_bone_transforms()
	var index := rig.find_bone("hand_"+side)
	var hand := rig.get_bone_global_pose(index)
	equipment._grasp(side,curl*amount)
	rig.force_update_all_bone_transforms()
	var offset: Vector3 = equipment.palm_offsets[side]
	if side == "r":
		var index_tip := rig.get_bone_global_pose(rig.find_bone("index_03_r")).origin
		var thumb_tip := rig.get_bone_global_pose(rig.find_bone("thumb_03_r")).origin
		offset = hand.affine_inverse()*((index_tip+thumb_tip)*.5)
	var palm: Vector3 = hand*offset
	var contact := palm.lerp(rig.to_local(target),amount)
	# Keep a neutral wrist in the reaching forearm plane; solve shoulder/elbow.
	for iteration in 3:
		hand = rig.get_bone_global_pose(index)
		equipment._solve_arm(side,contact-hand.basis*offset)
		rig.force_update_all_bone_transforms()
	equipment._grasp(side,curl*amount)
	rig.force_update_all_bone_transforms()
	return rig.to_global(rig.get_bone_global_pose(index)*offset).distance_to(target)
