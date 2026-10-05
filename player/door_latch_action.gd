extends Node
## Approach, reach, release and recover. The visible hand drives the latch release.
var door: Node3D
var actor: CharacterBody3D
var visual: Node3D
var pull: Node3D
var elapsed := 0.0
var phase := ""
var amount := 0.0
var released := false
var last_gap := INF
var approach_time := 0.0
var clearance_target := Vector3.ZERO

func begin(target: Node3D) -> bool:
	if phase != "": return false
	actor=get_parent()
	visual=actor.get_node_or_null("VisualRoot/CharacterVisual")
	if visual == null or visual.skeleton == null: return false
	if actor.is_swimming or actor.get_meta("climbing",false) or actor.get_meta("rest_action","") != "" or (actor.has_meta("mounted_vehicle") and actor.get_meta("mounted_vehicle") != null): return false
	if visual.equipment.reload_progress >= 0.0: return false
	door=target
	pull=door.nearest_pull(actor.global_position)
	if pull == null: return false
	if actor.global_position.distance_to(pull.global_position)>3.0: return false
	if not visual.equipment.stowed: visual.equipment.toggle_stowed()
	phase="approach"
	elapsed=0.0
	approach_time=0.0
	released=false
	last_gap=INF
	actor.set_meta("door_latch_failure","")
	actor.set_meta("door_latch_active",true)
	return true

func _physics_process(delta: float) -> void:
	if phase == "": return
	if not is_instance_valid(door) or not is_instance_valid(pull) or actor.get_meta("detention_action","") != "":
		finish()
		return
	actor.velocity=Vector3.ZERO
	var horizontal := pull.global_position-actor.global_position
	horizontal.y=0
	if phase == "clearance":
		elapsed+=delta
		amount=1.0-smoothstep(0.0,.3,elapsed)
		var retreat := clearance_target-actor.global_position
		retreat.y=0
		if retreat.length()>.05:
			actor.velocity=retreat.normalized()*minf(1.6,retreat.length()/maxf(delta,.001))
			actor.velocity.y=-3.0
			_move_with_steps(delta)
		if elapsed>.3:
			door.set_open(false)
			if door.moving: actor.set_meta("door_latch_released",true); finish(); return
		if elapsed>3.0:
			actor.set_meta("door_latch_failure","closing sweep occupied")
			finish()
		return
	if phase == "approach":
		approach_time+=delta
		if horizontal.length()>.435:
			var motion := horizontal.normalized()*minf(delta*1.6,horizontal.length()-.42)
			actor.velocity=motion/maxf(delta,.001)
			actor.velocity.y=-3.0
			var before := actor.global_position
			_move_with_steps(delta)
			var travel := actor.global_position-before
			travel.y=0
			if travel.length()<.001 and horizontal.length()<.7:
				phase="reach"
				elapsed=0.0
			if approach_time>2.0:
				actor.set_meta("door_latch_failure","approach blocked")
				finish(); return
		else:
			phase="reach"
			elapsed=0.0
		if horizontal.length()>.02: actor.get_node("VisualRoot").global_rotation.y=atan2(horizontal.x,horizontal.z)
		return
	elapsed+=delta
	amount=smoothstep(0.0,.32,elapsed)*(1.0-smoothstep(.55,.86,elapsed))
	# Release only after a rendered pose has reached the actual ring.
	if not released and elapsed>=.36:
		if last_gap>.04 or elapsed>.65:
			if elapsed>.65:
				actor.set_meta("door_latch_failure","hand unreachable: %s" % last_gap)
				finish()
			return
		released=true
		if door.opened:
			phase="clearance"
			elapsed=0.0
			var local := door.to_local(actor.global_position)
			clearance_target=door.to_global(Vector3(0,local.y,-door.swing_direction*.9))
			return
		if not door.opened:
			door.swing_direction=1.0 if door.get_parent().to_local(actor.global_position).z<door.position.z else -1.0
		door.set_open(not door.opened)
		actor.set_meta("door_latch_released",door.moving)
	if elapsed>=.9: finish()

func apply_pose() -> void:
	if phase == "" or phase == "approach": return
	var rig: Skeleton3D=visual.skeleton
	var equipment=visual.equipment
	visual.pose("spine_02",Vector3(.18,0,0),amount)
	rig.force_update_all_bone_transforms()
	var hand_index := rig.find_bone("hand_r")
	var hand := rig.get_bone_global_pose(hand_index)
	var palm: Vector3=hand*equipment.palm_offsets["r"]
	var target: Vector3=rig.to_local(pull.global_position)
	var contact := palm.lerp(target,amount)
	var normal: Vector3=rig.global_basis.inverse()*(pull.global_position-actor.global_position)
	normal.y=0;normal=normal.normalized()
	var finger_axis := Vector3.DOWN
	var across := finger_axis.cross(normal).normalized()
	var desired_hand: Basis=Basis(across,normal.cross(across),normal)*(equipment.palm_axes["r"] as Basis).inverse()
	for iteration in 4:
		equipment._solve_arm("r",contact-desired_hand*equipment.palm_offsets["r"])
		var parent := rig.get_bone_parent(hand_index)
		var local_basis := rig.get_bone_global_pose(parent).basis.inverse()*desired_hand
		rig.set_bone_pose_rotation(hand_index,rig.get_bone_pose_rotation(hand_index).slerp(local_basis.orthonormalized().get_rotation_quaternion(),amount))
		rig.force_update_all_bone_transforms()
	equipment._grasp("r",amount*.6)
	rig.force_update_all_bone_transforms()
	var solved := rig.to_global(rig.get_bone_global_pose(hand_index)*equipment.palm_offsets["r"])
	last_gap=solved.distance_to(pull.global_position)
	actor.set_meta("door_latch_hand_gap",last_gap)
	actor.set_meta("door_latch_progress",elapsed)

func finish() -> void:
	phase=""
	amount=0.0
	if is_instance_valid(actor):
		actor.set_meta("door_latch_active",false)
		actor.velocity=Vector3.ZERO

func _move_with_steps(delta: float) -> void:
	var horizontal := Vector3(actor.velocity.x,0,actor.velocity.z)*delta
	actor.step_ground_grace=.15 if actor.is_on_floor() else maxf(0,actor.step_ground_grace-delta)
	actor.step_up_grace=maxf(0,actor.step_up_grace-delta)
	actor.move_and_slide()
	actor._try_walk_step(delta,horizontal)
	actor._try_walk_step_down()
