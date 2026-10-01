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
	if phase == "approach":
		approach_time+=delta
		if horizontal.length()>.435:
			var motion := horizontal.normalized()*minf(delta*1.6,horizontal.length()-.42)
			actor.velocity=motion/maxf(delta,.001)
			actor.velocity.y=-3.0
			actor.move_and_slide()
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
		if not door.opened:
			door.swing_direction=1.0 if door.get_parent().to_local(actor.global_position).z<door.position.z else -1.0
		door.set_open(not door.opened)
		actor.set_meta("door_latch_released",door.moving)
	if elapsed>=.9: finish()

func apply_pose() -> void:
	if phase == "" or phase == "approach": return
	var rig: Skeleton3D=visual.skeleton
	var equipment=visual.equipment
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
