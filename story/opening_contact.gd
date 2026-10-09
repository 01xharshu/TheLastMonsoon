extends RefCounted
## Opening-only contact overlay after the existing locomotion AnimationTree.
var wick_gap := 0.0
var palm_gap := 0.0
var carry_gap := 0.0
var pinch_width := 0.0
var planted_feet: Dictionary = {}
var foot_gap := 0.0
var walk_feet: Dictionary = {}
var finger_pads: Dictionary = {}

func update_walk(scene, delta: float) -> void:
	var rig: Skeleton3D = scene.visual.skeleton
	for side in ["l","r"]:
		var index := rig.find_bone("foot_"+side)
		var rest := rig.get_bone_global_rest(index)
		var offset := rest.basis.inverse()*Vector3(0,-.085,.06)
		var local := rig.get_bone_global_pose(index)*offset
		var sole := rig.to_global(local)
		var query := PhysicsRayQueryParameters3D.create(sole+Vector3.UP*.35,sole-Vector3.UP*.5)
		query.exclude = [scene.actor.get_rid()]
		var hit: Dictionary = scene.actor.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty(): continue
		var floor_y: float = hit.position.y+.003
		if not walk_feet.has(side): walk_feet[side] = {"previous":local,"held":false,"weight":0.0,"target":sole}
		var state: Dictionary = walk_feet[side]
		var backwards: float = (local.z-state.previous.z)/maxf(delta,.001)
		state.previous = local
		var support: bool = backwards < -.02 and sole.y-floor_y < .05 and scene.actor.velocity.length() > .03
		if support and not state.held:
			state.target = Vector3(sole.x,floor_y,sole.z)
			state.weight = 0.0
			if scene.sound != null: scene.sound.play_step(side,scene.elapsed,state.target)
		state.held = support
		if support:
			state.weight = lerpf(state.weight,1.0,1.0-exp(-22.0*delta))
			scene.visual._horse_foot_contact(side,state.target,state.weight)

func update(scene, t: float) -> void:
	var rig: Skeleton3D = scene.visual.skeleton
	var equipment = scene.visual.equipment
	if equipment == null or t >= 9.0: return
	var lean := smoothstep(3.0,5.0,t)*(1.0-smoothstep(6.0,6.8,t))
	var bend := smoothstep(6.7,8.0,t)*(1.0-smoothstep(8.3,9.0,t))
	var low_wick := smoothstep(3.0,5.0,t)*(1.0-smoothstep(5.9,6.6,t))
	scene.actor.global_position = scene.home.to_global(Vector3(-2.6,1.14-.065*bend-.22*low_wick,1.27))
	scene.visual.pose("spine_01",Vector3(.30*lean,0,0),1.0)
	scene.visual.pose("spine_02",Vector3(.25*lean,0,0),1.0)
	scene.visual.pose("head",Vector3(.10+.08*lean,.10,0),1.0)
	# The open diya remains stationary; the free hand stays in its idle pose.
	carry_gap = 0.0
	var wick: Vector3 = scene.lamp.get_node("WickContact").global_position
	var held: Vector3 = scene.home.to_global(Vector3(-2.51,1.64,.94))
	var tip: Vector3 = held
	if t < 5.0:
		tip = held.lerp(wick,smoothstep(3.0,5.0,t))
	elif t < 5.9:
		tip = wick
	else:
		tip = wick.lerp(scene.home.to_global(Vector3(-2.5,1.32,1.03)),smoothstep(5.9,6.6,t))
	# Keep the spent match visible: lower it onto the table before releasing.
	var put_down := smoothstep(6.7,8.1,t)
	tip = tip.lerp(scene.home.to_global(Vector3(-2.43,.958,.93)),put_down)
	# Burning head sits above the thumb/index pinch, never pointing down.
	var axis: Vector3 = (scene.home.global_basis*Vector3(0,.94,-.342)).normalized()
	axis = axis.lerp((scene.home.global_basis*Vector3.RIGHT).normalized(),put_down).normalized()
	# Choose a perpendicular axis even when the stick lies along the table.
	var across: Vector3 = (scene.home.global_basis*Vector3.UP).cross(axis).normalized()
	var basis := Basis(across,axis,across.cross(axis)).orthonormalized()
	# Cylinder head and flame sit at local y .0275 / .038 respectively.
	scene.match_prop.global_transform = Transform3D(basis,tip-axis*.038)
	var pinch: Vector3 = tip-axis*.058
	palm_gap = _hand(scene,"r",pinch,1.0-smoothstep(8.1,9.0,t),.32)
	wick_gap = tip.distance_to(wick)
	scene.actor.set_meta("opening_wick_gap",wick_gap)
	scene.actor.set_meta("opening_palm_gap",palm_gap)
	scene.actor.set_meta("opening_carry_gap",carry_gap)
	scene.actor.set_meta("opening_pinch_width",pinch_width)
	_plant_feet(scene)
	scene.actor.set_meta("opening_foot_gap",foot_gap)

func _plant_feet(scene) -> void:
	var rig: Skeleton3D = scene.visual.skeleton
	foot_gap = 0.0
	for side in ["l","r"]:
		var index := rig.find_bone("foot_"+side)
		var rest := rig.get_bone_global_rest(index)
		var sole_offset := rest.basis.inverse()*Vector3(0,-.085,.06)
		if not planted_feet.has(side):
			var sole := rig.to_global(rig.get_bone_global_pose(index)*sole_offset)
			var query := PhysicsRayQueryParameters3D.create(sole+Vector3.UP*.35,sole-Vector3.UP*.5)
			query.exclude = [scene.actor.get_rid()]
			var hit: Dictionary = scene.actor.get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty(): sole.y = hit.position.y+.003
			planted_feet[side] = scene.home.to_local(sole)
		var target: Vector3 = scene.home.to_global(planted_feet[side])
		scene.visual._horse_foot_contact(side,target,1.0)
		var actual := rig.to_global(rig.get_bone_global_pose(index)*sole_offset)
		foot_gap = maxf(foot_gap,actual.distance_to(target))

func _hand(scene, side: String, target: Vector3, amount: float, curl: float) -> float:
	var rig: Skeleton3D = scene.visual.skeleton
	var equipment = scene.visual.equipment
	rig.force_update_all_bone_transforms()
	var index := rig.find_bone("hand_"+side)
	var original := rig.get_bone_pose_rotation(index)
	var hand := rig.get_bone_global_pose(index)
	var offset: Vector3 = equipment.palm_offsets[side]
	var contact := (hand*offset).lerp(rig.to_local(target),amount)
	# Keep the palm vertical beside the prop. Reapply the wrist after each arm
	# solve: its parent rotates, so retaining a local wrist angle loses contact.
	var palm_world: Basis = scene.home.global_basis*Basis(Vector3.LEFT,Vector3.FORWARD,Vector3.DOWN)
	if side == "r":
		var forward := Vector3(0,.08,-.9968).normalized()
		palm_world = scene.home.global_basis*Basis(Vector3.RIGHT,forward,Vector3.RIGHT.cross(forward))
	var desired: Basis = rig.global_basis.inverse()*palm_world*(equipment.palm_axes[side] as Basis).inverse()
	for iteration in 4:
		var parent := rig.get_bone_parent(index)
		var rotation := (rig.get_bone_global_pose(parent).basis.inverse()*desired).orthonormalized().get_rotation_quaternion()
		rig.set_bone_pose_rotation(index,original.slerp(rotation,amount))
		# The three unused fingers fold naturally during a precision pinch.
		equipment._grasp(side,(.72 if side == "r" else curl)*amount)
		rig.force_update_all_bone_transforms()
		hand = rig.get_bone_global_pose(index)
		if side == "r":
			_pinch(scene,hand,amount)
			var tips := _pinch_centre(rig)
			offset = hand.affine_inverse()*tips
		equipment._solve_arm(side,contact-hand.basis*offset)
		rig.force_update_all_bone_transforms()
	if side == "r":
		pinch_width = _finger_pad(rig,"index").distance_to(_finger_pad(rig,"thumb"))
		return rig.to_global(_pinch_centre(rig)).distance_to(target)
	return rig.to_global(rig.get_bone_global_pose(index)*offset).distance_to(target)

func _cache_finger_pads(scene) -> void:
	if not finger_pads.is_empty(): return
	var rig: Skeleton3D = scene.visual.skeleton
	var body: MeshInstance3D = scene.visual.model.find_child("Arjun_MakeHuman_Body",true,false)
	for digit in ["index","thumb"]:
		var bone := rig.find_bone(digit+"_03_r")
		var rest := rig.get_bone_global_rest(bone)
		var forward := rest.basis.inverse()*(rest.origin-rig.get_bone_global_rest(rig.find_bone(digit+"_02_r")).origin).normalized()
		var points: Array[Vector3] = []
		for surface in body.mesh.get_surface_count():
			var arrays := body.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var stride := bones.size()/vertices.size()
			for v in vertices.size():
				for slot in stride:
					var bind := bones[v*stride+slot]
					var bound_bone := body.skin.get_bind_bone(bind)
					if str(body.skin.get_bind_name(bind)) != "": bound_bone = rig.find_bone(body.skin.get_bind_name(bind))
					if bound_bone == bone and weights[v*stride+slot] > .25:
						points.append(body.skin.get_bind_pose(bind)*vertices[v])
						break
		assert(not points.is_empty(),"Missing visible fingertip vertices")
		points.sort_custom(func(a: Vector3,b: Vector3): return a.dot(forward)>b.dot(forward))
		var pad := Vector3.ZERO
		var count := maxi(4,points.size()/5)
		for i in count: pad += points[i]
		finger_pads[digit] = pad/count

func _finger_pad(rig: Skeleton3D, digit: String) -> Vector3:
	return rig.get_bone_global_pose(rig.find_bone(digit+"_03_r"))*finger_pads[digit]

func _pinch_centre(rig: Skeleton3D) -> Vector3:
	return (_finger_pad(rig,"index")+_finger_pad(rig,"thumb"))*.5

func _pinch(scene, hand: Transform3D, amount: float) -> void:
	_cache_finger_pads(scene)
	var rig: Skeleton3D = scene.visual.skeleton
	var equipment = scene.visual.equipment
	var palm: Basis = hand.basis*equipment.palm_axes["r"]
	var centre: Vector3 = hand*equipment.palm_offsets["r"]+palm.y*.024
	for digit in ["index","thumb"]:
		var sign_digit := 1.0 if digit == "index" else -1.0
		var target: Vector3 = _finger_pad(rig,digit).lerp(centre+palm.x*.0025*sign_digit,amount)
		for iteration in 10:
			for joint in ["03","02","01"]:
				var index := rig.find_bone(digit+"_"+joint+"_r")
				var pose := rig.get_bone_global_pose(index)
				var actual := _finger_pad(rig,digit)-pose.origin
				var wanted := target-pose.origin
				if actual.length() < .00001 or wanted.length() < .00001: continue
				var desired := Basis(Quaternion(actual.normalized(),wanted.normalized()))*pose.basis
				var parent := rig.get_bone_parent(index)
				rig.set_bone_pose_rotation(index,(rig.get_bone_global_pose(parent).basis.inverse()*desired).orthonormalized().get_rotation_quaternion())
				rig.force_update_all_bone_transforms()
