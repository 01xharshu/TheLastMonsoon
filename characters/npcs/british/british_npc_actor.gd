extends Node3D
## Independent preview actor with its own sampled idle/walk AnimationPlayer.

@export var patrol_distance: float = 1.4
@export var patrol_axis: Vector3 = Vector3(0, 0, -1)
@export var cycle_offset: float = 0.0
@export var movement_profile: StringName = &"male"
@export var movement_enabled: bool = true

var animation_state: StringName = &"idle"
var _home: Vector3
var _clock: float = 0.0
var _skeleton: Skeleton3D
var _bones: Dictionary = {}
var _base_rotations: Dictionary = {}
var _pitch_axes: Dictionary = {}
var _yaw_axes: Dictionary = {}
var animation_player: AnimationPlayer
var animation_tree: AnimationTree
var locomotion_blend: float = 0.0

func _ready() -> void:
	_home = position
	_clock = cycle_offset
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
	animation_player = AnimationPlayer.new()
	animation_player.name = "PersonalAnimationPlayer"
	add_child(animation_player)
	animation_player.root_node = NodePath("..")
	var library := AnimationLibrary.new()
	library.add_animation("idle", _make_clip(false))
	library.add_animation("walk", _make_clip(true))
	animation_player.add_animation_library("", library)
	animation_tree = AnimationTree.new()
	animation_tree.name = "PersonalAnimationTree"
	add_child(animation_tree)
	animation_tree.anim_player = animation_tree.get_path_to(animation_player)
	animation_tree.root_node = NodePath("..")
	var locomotion := AnimationNodeBlendSpace1D.new()
	locomotion.min_space = 0.0
	locomotion.max_space = 1.0
	var idle := AnimationNodeAnimation.new()
	idle.animation = &"idle"
	var walk := AnimationNodeAnimation.new()
	walk.animation = &"walk"
	locomotion.add_blend_point(idle, 0.0, -1, "idle")
	locomotion.add_blend_point(walk, 1.0, -1, "walk")
	var graph := AnimationNodeBlendTree.new()
	graph.add_node("locomotion", locomotion)
	graph.connect_node("output", 0, "locomotion")
	animation_tree.tree_root = graph
	animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animation_tree.active = true
	animation_tree.set("parameters/locomotion/blend_position", 0.0)
	animation_tree.advance(0.0)

func _make_clip(walking: bool) -> Animation:
	var clip := Animation.new()
	var female := movement_profile == &"female"
	clip.length = (1.05 if female else 0.85) if walking else 3.5
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
				"lowerarm_l", "lowerarm_r": angle = -0.10 - (0.04 * absf(stride) if walking else 0.0)
				"foot_l": angle = ((0.22 if female else 0.32) * stride - 0.35 * maxf(0.0, stride)) if walking else 0.0
				"foot_r": angle = (-(0.22 if female else 0.32) * stride - 0.35 * maxf(0.0, -stride)) if walking else 0.0
			var base: Quaternion = _base_rotations[bone_name]
			clip.rotation_track_insert_key(track, fraction * clip.length, base * Quaternion(axis, angle))
	return clip

func _process(delta: float) -> void:
	if animation_player == null:
		return
	if not movement_enabled:
		_set_animation(&"idle", delta)
		return
	_clock += delta
	var segment := fmod(_clock, 10.0)
	var axis := patrol_axis.normalized()
	var progress := 0.0
	var walking := false
	if segment < 2.0:
		walking = true
		progress = segment / 2.0
	elif segment < 4.0:
		progress = 1.0
	elif segment < 6.0:
		walking = true
		progress = 1.0 - (segment - 4.0) / 2.0
	position = _home + axis * patrol_distance * progress
	if walking:
		var direction := axis if segment < 2.0 else -axis
		rotation.y = atan2(direction.x, direction.z)
	_set_animation(&"walk" if walking else &"idle", delta)

func _set_animation(state: StringName, delta: float) -> void:
	animation_state = state
	var target := 1.0 if state == &"walk" else 0.0
	# Finite blend time avoids an endless residual walk after stopping.
	locomotion_blend = move_toward(locomotion_blend, target, maxf(delta, 0.0) / 0.2)
	animation_tree.set("parameters/locomotion/blend_position", locomotion_blend)
	animation_tree.advance(maxf(delta, 0.0))
