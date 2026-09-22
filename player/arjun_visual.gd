extends Node3D
## Rest-relative, model-space procedural animation for the MPFB game rig.
const TALWAR = preload("res://environment/weapons/Talwar/weapon_talwar_01.glb")
@export var talwar_equipped := true
var skeleton: Skeleton3D
var model: Node3D
var weapon: Node3D
var phase := 0.0
var breath := 0.0
var motion := 0.0
var swim_blend := 0.0
var bones: Dictionary = {}
var base_rotations: Dictionary = {}
var axes: Dictionary = {}
@onready var actor: CharacterBody3D = get_parent().get_parent()

func _ready() -> void:
	model = preload("res://characters/arjun/arjun.glb").instantiate()
	add_child(model)
	model.position.y = -0.9
	var rigs := model.find_children("*", "Skeleton3D", true, false)
	if rigs.is_empty():
		push_error("Arjun model has no skeleton")
		return
	skeleton = rigs[0]
	for i in skeleton.get_bone_count():
		var bone := skeleton.get_bone_name(i)
		bones[bone] = i
		base_rotations[bone] = skeleton.get_bone_pose_rotation(i)
		axes[bone] = skeleton.get_bone_global_rest(i).basis.orthonormalized().inverse()
	var socket := BoneAttachment3D.new()
	socket.bone_name = "hand_r"
	skeleton.add_child(socket)
	weapon = TALWAR.instantiate()
	socket.add_child(weapon)
	# The exported blade points along +X; its grip centre is behind the guard.
	weapon.basis = axes["hand_r"] * Basis(Vector3.UP, Vector3.FORWARD, Vector3.LEFT)
	weapon.position = Vector3(0, 0.07, 0) - weapon.basis * Vector3(-0.095, -0.002, 0)

func pose(bone: String, angles: Vector3, weight: float) -> void:
	if not bones.has(bone): return
	var local_axes: Basis = axes[bone]
	var offset := Quaternion(local_axes * Vector3.RIGHT, angles.x) * Quaternion(local_axes * Vector3.UP, angles.y) * Quaternion(local_axes * Vector3.BACK, angles.z)
	var target: Quaternion = base_rotations[bone] * offset
	var index: int = bones[bone]
	skeleton.set_bone_pose_rotation(index, skeleton.get_bone_pose_rotation(index).slerp(target, weight))

func _process(delta: float) -> void:
	if skeleton == null: return
	var blend := 1.0 - exp(-12.0 * delta)
	var speed := Vector2(actor.velocity.x, actor.velocity.z).length()
	motion = lerpf(motion, clampf(speed / actor.walk_speed, 0.0, 1.0), blend)
	swim_blend = lerpf(swim_blend, 1.0 if actor.is_swimming else 0.0, blend)
	var sprint := clampf((speed - actor.walk_speed) / maxf(actor.sprint_speed - actor.walk_speed, 0.1), 0.0, 1.0)
	phase = fmod(phase + delta * lerpf(7.5, 11.5, sprint) * lerpf(0.3, 1.0, motion), TAU)
	breath += delta * 1.8
	var ground := 1.0 if actor.is_on_floor() else 0.0
	var stride := motion * ground * (1.0 - swim_blend)
	var swing := sin(phase) * lerpf(0.42, 0.8, sprint) * stride
	var swimming := swim_blend
	var armed := talwar_equipped and swimming < 0.5
	weapon.visible = armed
	# Pivot near the chest when leaning into the water, keeping the face above it.
	model.rotation.x = lerpf(model.rotation.x, swimming * 1.05, blend)
	model.position = Vector3(0, -0.9 + swimming * 0.65 + absf(sin(phase)) * stride * 0.045, 0)
	pose("pelvis", Vector3(0, swing * 0.12, sin(phase) * stride * 0.035), blend)
	pose("spine_01", Vector3(sprint * stride * 0.12, -swing * 0.18, 0), blend)
	pose("spine_02", Vector3(sin(breath) * 0.015, -swing * 0.12, 0), blend)
	pose("head", Vector3(-swimming * 0.55 - sprint * stride * 0.06, 0, 0), blend)
	for side in ["l", "r"]:
		var sign_side := 1.0 if side == "l" else -1.0
		var cycle := phase + (0.0 if side == "l" else PI)
		var leg := swing * sign_side
		var air := (1.0 - ground) * (1.0 - swimming)
		pose("thigh_" + side, Vector3(leg - air * 0.22 + swimming * sin(cycle) * 0.24, 0, 0), blend)
		pose("calf_" + side, Vector3(maxf(0, sin(cycle)) * stride * lerpf(0.65, 1.25, sprint) + air * 0.4 + swimming * (0.2 + maxf(0, sin(cycle)) * 0.35), 0, 0), blend)
		pose("foot_" + side, Vector3(-leg * 0.25 + swimming * 0.25, 0, 0), blend)
		var arm := Vector3(-leg * 0.65, 0, -sign_side * 0.45)
		var elbow := -0.15 - sprint * 0.65
		if armed and side == "r":
			arm = Vector3(-0.28 - leg * 0.12, -0.12, 0.32)
			elbow = -0.65
		arm = arm.lerp(Vector3(-0.65 + sin(cycle) * 0.85, 0, sign_side * (0.55 + cos(cycle) * 0.4)), swimming)
		elbow = lerpf(elbow, -0.5 - maxf(0, cos(cycle)) * 0.8, swimming)
		pose("upperarm_" + side, arm, blend)
		pose("lowerarm_" + side, Vector3(elbow, 0, 0), blend)
		for finger in ["index", "middle", "ring", "pinky", "thumb"]:
			for joint in ["01", "02", "03"]:
				# Fingers curl around their local hinge, unlike the model-space limbs.
				var name: String = finger + "_" + joint + "_" + side
				if bones.has(name):
					var curl := 0.85 if armed and side == "r" else 0.12
					var target: Quaternion = base_rotations[name] * Quaternion(Vector3.RIGHT, curl)
					skeleton.set_bone_pose_rotation(bones[name], skeleton.get_bone_pose_rotation(bones[name]).slerp(target, blend))
