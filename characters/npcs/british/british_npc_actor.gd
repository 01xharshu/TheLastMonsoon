extends Node3D
## Simple preview locomotion for the British NPC studies. No gameplay AI yet.

@export var patrol_distance: float = 1.4
@export var patrol_axis: Vector3 = Vector3(0, 0, -1)
@export var cycle_offset: float = 0.0

var animation_state: StringName = &"idle"
var _home: Vector3
var _clock: float = 0.0
var _skeleton: Skeleton3D
var _bones: Dictionary = {}
var _base_rotations: Dictionary = {}

func _ready() -> void:
	_home = position
	_clock = cycle_offset
	var found := find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		push_error("British NPC preview has no imported Skeleton3D: " + name)
		return
	_skeleton = found[0] as Skeleton3D
	for bone_name in ["pelvis", "spine_02", "head", "upperarm_l", "upperarm_r", "thigh_l", "thigh_r", "calf_l", "calf_r"]:
		_bones[bone_name] = _skeleton.find_bone(bone_name)
		if _bones[bone_name] < 0:
			push_error("British NPC missing animation bone " + bone_name + ": " + name)
		else:
			_base_rotations[bone_name] = _skeleton.get_bone_pose_rotation(_bones[bone_name])

func _process(delta: float) -> void:
	if _skeleton == null:
		return
	_clock += delta
	var segment := fmod(_clock, 10.0)
	var axis := patrol_axis.normalized()
	var progress := 0.0
	if segment < 2.0:
		animation_state = &"walk"
		progress = segment / 2.0
	elif segment < 4.0:
		animation_state = &"idle"
		progress = 1.0
	elif segment < 6.0:
		animation_state = &"walk"
		progress = 1.0 - (segment - 4.0) / 2.0
	else:
		animation_state = &"idle"
	position = _home + axis * patrol_distance * progress
	if animation_state == &"walk":
		var direction := axis if segment < 2.0 else -axis
		rotation.y = atan2(-direction.x, -direction.z)
	_animate_bones(animation_state == &"walk")

func _animate_bones(walking: bool) -> void:
	var phase := _clock * TAU * 1.25
	var stride := sin(phase)
	var breath := sin(_clock * TAU * 0.23)
	_set_rotation("spine_02", Vector3.RIGHT, 0.012 * breath)
	_set_rotation("head", Vector3.UP, 0.025 * sin(_clock * 0.7))
	_set_rotation("thigh_l", Vector3.RIGHT, 0.32 * stride if walking else 0.0)
	_set_rotation("thigh_r", Vector3.RIGHT, -0.32 * stride if walking else 0.0)
	_set_rotation("calf_l", Vector3.RIGHT, 0.19 * maxf(0.0, -stride) if walking else 0.0)
	_set_rotation("calf_r", Vector3.RIGHT, 0.19 * maxf(0.0, stride) if walking else 0.0)
	_set_rotation("upperarm_l", Vector3.RIGHT, -0.16 * stride if walking else 0.015 * breath)
	_set_rotation("upperarm_r", Vector3.RIGHT, 0.16 * stride if walking else -0.015 * breath)

func _set_rotation(bone_name: String, axis: Vector3, angle: float) -> void:
	var index: int = _bones.get(bone_name, -1)
	if index >= 0:
		_skeleton.set_bone_pose_rotation(index, _base_rotations[bone_name] * Quaternion(axis, angle))
