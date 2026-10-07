extends Node3D
## Independent preview actor with its own sampled idle/walk AnimationPlayer.

@export var patrol_distance: float = 1.4
@export var patrol_axis: Vector3 = Vector3(0, 0, -1)
@export var cycle_offset: float = 0.0
@export var movement_profile: StringName = &"male"
@export var movement_enabled: bool = true
@export var foot_plant_enabled: bool = true

var animation_state: StringName = &"idle"
var _home: Vector3
var _clock: float = 0.0
var _skeleton: Skeleton3D
var _bones: Dictionary = {}
var _base_rotations: Dictionary = {}
var _pitch_axes: Dictionary = {}
var _yaw_axes: Dictionary = {}
var _finger_rest: Dictionary = {}
var _finger_pitch: Dictionary = {}
var animation_player: AnimationPlayer
var animation_tree: AnimationTree
var locomotion_blend: float = 0.0
var turn_blend: float = 0.0
var _turn_progress: float = 0.0
var nominal_walk_speed: float = 0.0
var travel_speed: float = 0.0
var walk_playback_rate: float = 1.0
var foot_plant = preload("res://characters/npcs/british/british_foot_plant.gd").new()
var _walk_phase: float = 0.0
var _last_facing: float = 0.0
var body_collider: AnimatableBody3D
var contact_blocked: bool = false

func _patrol_body_blocked(local_motion: Vector3) -> bool:
	if body_collider == null or local_motion.length_squared() < 0.00000001:
		return false
	var body_shape := body_collider.get_node("BodyShape") as CollisionShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = body_shape.shape
	query.collision_mask = body_collider.collision_mask
	query.exclude = [body_collider.get_rid()]
	query.margin = 0.015
	var world_motion := get_parent_node_3d().global_basis * local_motion
	var steps := maxi(1, int(ceil(world_motion.length() / 0.1)))
	var start := body_shape.global_transform
	for step in range(1, steps + 1):
		query.transform = start
		query.transform.origin += world_motion * float(step) / float(steps)
		for hit in get_world_3d().direct_space_state.intersect_shape(query, 16):
			var other: Object = hit.collider
			if other is CharacterBody3D or (other is AnimatableBody3D and other.name == "BodyCollider"):
				return true
	return false

func _ready() -> void:
	if not has_meta("combat_faction"): set_meta("combat_faction","british")
	add_to_group("combat_actors")
	call_deferred("_configure_combat")
	_home = position
	_clock = cycle_offset
	_create_body_collider()
	var found := find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		push_error("British NPC has no imported skeleton: " + name)
		return
	_skeleton = found[0] as Skeleton3D
	for bone_name in ["spine_02", "head", "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "foot_l", "foot_r", "thigh_l", "thigh_r", "calf_l", "calf_r"]:
		var index := _skeleton.find_bone(bone_name)
		_bones[bone_name] = index
		if index >= 0:
			_base_rotations[bone_name] = _skeleton.get_bone_pose_rotation(index)
		else:
			push_error("Missing motion bone " + bone_name + ": " + name)
	# Convert the imported A-pose to relaxed arms in skeleton space.
	# Derive the correction from each rig rather than assuming local bone axes.
	for side in ["l", "r"]:
		var upper: int = _bones["upperarm_" + side]
		var lower := _skeleton.find_bone("lowerarm_" + side)
		if upper < 0 or lower < 0:
			continue
		var pose := _skeleton.get_bone_global_pose(upper)
		var direction := (_skeleton.get_bone_global_pose(lower).origin - pose.origin).normalized()
		var clearance := 0.22 if movement_profile == &"female" else 0.12
		var target := Vector3(clearance if direction.x > 0.0 else -clearance, -1.0, 0.0).normalized()
		var correction := Quaternion(direction, target)
		var orientation := pose.basis.get_rotation_quaternion()
		var local_correction := orientation.inverse() * correction * orientation
		_base_rotations["upperarm_" + side] = _base_rotations["upperarm_" + side] * local_correction
	# Pitch/yaw axes are expressed in each posed bone's local coordinates.
	# Imported bone rolls differ, so Vector3.RIGHT alone produces sideways kicks.
	for bone_name in _base_rotations:
		_skeleton.set_bone_pose_rotation(_bones[bone_name], _base_rotations[bone_name])
	for bone_name in _base_rotations:
		var inverse := _skeleton.get_bone_global_pose(_bones[bone_name]).basis.orthonormalized().inverse()
		_pitch_axes[bone_name] = (inverse * Vector3.RIGHT).normalized()
		_yaw_axes[bone_name] = (inverse * Vector3.UP).normalized()
	# Relax the imported spread fingers without adding hundreds of clip tracks.
	for side in ["l", "r"]:
		for finger in ["index", "middle", "ring", "pinky", "thumb"]:
			for joint in ["01", "02", "03"]:
				var bone_name: String = finger + "_" + joint + "_" + side
				var index := _skeleton.find_bone(bone_name)
				if index < 0:
					continue
				_finger_rest[index] = _skeleton.get_bone_pose_rotation(index)
				var inverse := _skeleton.get_bone_global_pose(index).basis.orthonormalized().inverse()
				_finger_pitch[index] = (inverse * Vector3.RIGHT).normalized()
	animation_player = AnimationPlayer.new()
	animation_player.name = "PersonalAnimationPlayer"
	add_child(animation_player)
	animation_player.root_node = NodePath("..")
	var library := AnimationLibrary.new()
	library.add_animation("idle", _make_clip(false))
	var walk_clip := _make_clip(true)
	library.add_animation("walk", walk_clip)
	library.add_animation("turn", _make_clip(false, true))
	_measure_stride(walk_clip)
	animation_player.add_animation_library("", library)
	animation_tree = AnimationTree.new()
	animation_tree.name = "PersonalAnimationTree"
	add_child(animation_tree)
	animation_tree.anim_player = animation_tree.get_path_to(animation_player)
	animation_tree.root_node = NodePath("..")
	var idle := AnimationNodeAnimation.new()
	idle.animation = &"idle"
	var walk := AnimationNodeAnimation.new()
	walk.animation = &"walk"
	var graph := AnimationNodeBlendTree.new()
	graph.add_node("idle", idle)
	graph.add_node("walk", walk)
	graph.add_node("walk_rate", AnimationNodeTimeScale.new())
	graph.add_node("locomotion", AnimationNodeBlend2.new())
	var turn := AnimationNodeAnimation.new()
	turn.animation = &"turn"
	graph.add_node("turn", turn)
	graph.add_node("turn_seek", AnimationNodeTimeSeek.new())
	graph.add_node("turning", AnimationNodeBlend2.new())
	graph.connect_node("walk_rate", 0, "walk")
	graph.connect_node("locomotion", 0, "idle")
	graph.connect_node("locomotion", 1, "walk_rate")
	graph.connect_node("turn_seek", 0, "turn")
	graph.connect_node("turning", 0, "locomotion")
	graph.connect_node("turning", 1, "turn_seek")
	graph.connect_node("output", 0, "turning")
	animation_tree.tree_root = graph
	animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animation_tree.active = true
	animation_tree.set("parameters/locomotion/blend_amount", 0.0)
	animation_tree.set("parameters/walk_rate/scale", 1.0)
	animation_tree.set("parameters/turning/blend_amount", 0.0)
	animation_tree.advance(0.0)
	_process(0.0)
	foot_plant.configure(_skeleton)
	_last_facing = rotation.y

func _create_body_collider() -> void:
	# A moving physics body follows this preview actor's patrol transform. The
	# capsule represents the torso and legs, not the full width of a dress.
	body_collider = AnimatableBody3D.new()
	body_collider.name = "BodyCollider"
	body_collider.collision_layer = 1
	body_collider.collision_mask = 1
	# The parent patrol owns the transform; sync_to_physics would keep this child
	# at its spawn point while the visible actor moves.
	body_collider.sync_to_physics = false
	add_child(body_collider)
	var shape := CapsuleShape3D.new()
	shape.radius = 0.29 if movement_profile == &"male" else 0.30
	shape.height = 1.60 if movement_profile == &"male" else 1.50
	var collision := CollisionShape3D.new()
	collision.name = "BodyShape"
	collision.shape = shape
	collision.position.y = shape.height * 0.5
	body_collider.add_child(collision)

func _measure_stride(clip: Animation) -> void:
	# Calibrate cadence to this rig's actual ankle excursion, not its sex/size label.
	var foot := _skeleton.find_bone("foot_l")
	var minimum := INF
	var maximum := -INF
	for frame in 65:
		for track in clip.get_track_count():
			var bone_name := str(clip.track_get_path(track)).get_slice(":", 1)
			_skeleton.set_bone_pose_rotation(_bones[bone_name], clip.track_get_key_value(track, frame))
		var z := _skeleton.get_bone_global_pose(foot).origin.z
		minimum = minf(minimum, z)
		maximum = maxf(maximum, z)
	# A cycle has two stance strokes across the ankle excursion.
	nominal_walk_speed = maxf(0.05, 2.0 * (maximum - minimum) / clip.length)
	for bone_name in _base_rotations:
		_skeleton.set_bone_pose_rotation(_bones[bone_name], _base_rotations[bone_name])

func _make_clip(walking: bool, turning: bool = false) -> Animation:
	var clip := Animation.new()
	var female := movement_profile == &"female"
	clip.length = (1.05 if female else 0.85) if walking else 3.5
	if turning:
		clip.length = 0.5
	clip.loop_mode = Animation.LOOP_LINEAR
	var path := str(get_path_to(_skeleton))
	for bone_name in _base_rotations:
		var track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track, NodePath(path + ":" + bone_name))
		for frame in range(65):
			var fraction := float(frame) / 64.0
			var phase := fraction * TAU
			var stride := sin(phase)
			var angle := 0.0
			var axis: Vector3 = _pitch_axes[bone_name]
			match bone_name:
				"spine_02": angle = 0.009 * sin(phase * 2.0) if walking else 0.012 * stride
				"head":
					axis = _yaw_axes[bone_name]
					angle = 0.012 * stride if walking else 0.025 * stride
				"thigh_l": angle = -(0.22 if female else 0.32) * stride if walking else 0.0
				"thigh_r": angle = (0.22 if female else 0.32) * stride if walking else 0.0
				"calf_l": angle = 0.35 * maxf(0.0, stride) if walking else 0.0
				"calf_r": angle = 0.35 * maxf(0.0, -stride) if walking else 0.0
				"upperarm_l": angle = (0.10 if female else 0.16) * stride if walking else 0.012 * stride
				"upperarm_r": angle = -(0.10 if female else 0.16) * stride if walking else -0.012 * stride
				"lowerarm_l", "lowerarm_r": angle = 0.08 + (0.02 * absf(stride) if walking else 0.0)
				"foot_l": angle = ((0.22 if female else 0.32) * stride - 0.35 * maxf(0.0, stride)) if walking else 0.0
				"foot_r": angle = (-(0.22 if female else 0.32) * stride - 0.35 * maxf(0.0, -stride)) if walking else 0.0
			if turning:
				# Two small alternating lifts let each foot reposition during the
				# root pivot. Keep the ankle level through hip/knee compensation.
				var left_lift := maxf(0.0, stride)
				var right_lift := maxf(0.0, -stride)
				match bone_name:
					"thigh_l": angle = -0.23 * left_lift
					"thigh_r": angle = -0.23 * right_lift
					"calf_l": angle = 0.46 * left_lift
					"calf_r": angle = 0.46 * right_lift
					"foot_l": angle = -0.23 * left_lift
					"foot_r": angle = -0.23 * right_lift
			var base: Quaternion = _base_rotations[bone_name]
			clip.rotation_track_insert_key(track, fraction * clip.length, base * Quaternion(axis, angle))
	return clip

func _process(delta: float) -> void:
	if animation_player == null or get_meta("dead",false) or get_meta("knocked_out",false):
		return
	if get_meta("external_combat_motion",false):
		_set_animation(&"walk" if travel_speed > .02 else &"idle",delta)
		return
	if not movement_enabled:
		contact_blocked = false
		travel_speed = 0.0
		_set_animation(&"idle", delta)
		return
	var previous_clock := _clock
	_clock += delta
	var segment := fmod(_clock, 10.0)
	var axis := patrol_axis.normalized()
	var progress := 0.0
	var walking := false
	var turning := false
	var direction := axis
	if segment < 2.0:
		walking = true
		progress = segment / 2.0
	elif segment < 4.0:
		progress = 1.0
	elif segment < 4.5:
		progress = 1.0
		turning = true
		direction = -axis
		_turn_progress = (segment - 4.0) / 0.5
	elif segment < 6.5:
		walking = true
		direction = -axis
		progress = 1.0 - (segment - 4.5) / 2.0
	elif segment < 9.5:
		direction = -axis
	else:
		turning = true
		direction = axis
		_turn_progress = (segment - 9.5) / 0.5
	var previous := position
	var desired := _home + axis * patrol_distance * progress
	contact_blocked = walking and _patrol_body_blocked(desired - previous)
	if contact_blocked:
		# Freeze patrol time as well as travel: clearing the obstruction resumes
		# here rather than jumping to a later point on the timed path.
		_clock = previous_clock
		travel_speed = 0.0
		rotation.y = rotate_toward(rotation.y, atan2(direction.x, direction.z), TAU * maxf(delta, 0.0))
		body_collider.force_update_transform()
		_set_animation(&"idle", delta)
		return
	position = desired
	travel_speed = position.distance_to(previous) / delta if delta > 0.0 else 0.0
	if walking or turning:
		var target_yaw := atan2(direction.x, direction.z)
		rotation.y = rotate_toward(rotation.y, target_yaw, TAU * maxf(delta, 0.0))
	if body_collider != null:
		body_collider.force_update_transform()
	_set_animation(&"turn" if turning else (&"walk" if walking else &"idle"), delta)

func take_damage(amount: float) -> void:
	get_node("Vitality").take_damage(amount)

func _set_animation(state: StringName, delta: float) -> void:
	animation_state = state
	var target := 1.0 if state == &"walk" else 0.0
	# Finite blend time avoids an endless residual walk after stopping.
	locomotion_blend = move_toward(locomotion_blend, target, maxf(delta, 0.0) / 0.2)
	if state == &"walk" and travel_speed > 0.001:
		walk_playback_rate = clampf(travel_speed / nominal_walk_speed, 0.1, 3.0)
	animation_tree.set("parameters/walk_rate/scale", walk_playback_rate)
	animation_tree.set("parameters/locomotion/blend_amount", locomotion_blend)
	turn_blend = move_toward(turn_blend, 1.0 if state == &"turn" else 0.0, maxf(delta, 0.0) / 0.08)
	animation_tree.set("parameters/turning/blend_amount", turn_blend)
	if state == &"turn":
		animation_tree.set("parameters/turn_seek/seek_request", clampf(_turn_progress, 0.0, 1.0) * 0.5)
	if foot_plant.skeleton != null and get_meta("combat_action","")=="":
		foot_plant.reset_pose()
	animation_tree.advance(maxf(delta, 0.0))
	for index in _finger_rest:
		var finger_name := _skeleton.get_bone_name(index)
		var curl := .95 if get_meta("combat_action","")=="strike" else (0.22 if "_01_" in finger_name else (0.32 if "_02_" in finger_name else 0.18))
		if finger_name.begins_with("thumb"):
			curl *= 0.55
		_skeleton.set_bone_pose_rotation(index, _finger_rest[index] * Quaternion(_finger_pitch[index], curl))
	if foot_plant.skeleton != null and get_meta("combat_action","")=="":
		_walk_phase = fmod(_walk_phase + maxf(delta, 0.0)*walk_playback_rate/animation_player.get_animation("walk").length, 1.0)
		if absf(angle_difference(_last_facing, rotation.y)) > 0.2:
			foot_plant.clear()
		_last_facing = rotation.y
		foot_plant.update(_walk_phase, foot_plant_enabled and state == &"walk" and locomotion_blend > 0.95 and travel_speed > 0.001, locomotion_blend if foot_plant_enabled else 0.0, nominal_walk_speed * animation_player.get_animation("walk").length)

func combat_react(action: String) -> void:
	var motion := get_node_or_null("CombatMotion")
	if motion != null: motion.play(action)

func _configure_combat() -> void:
	if animation_tree == null: return
	var motion := preload("res://combat/npc_combat_motion.gd").new()
	motion.name = "CombatMotion"
	add_child(motion)
	if get_node_or_null("Vitality") == null:
		var vitality := preload("res://combat/npc_vitality.gd").new()
		vitality.name = "Vitality"
		add_child(vitality)
