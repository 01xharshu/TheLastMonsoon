extends AnimationTree
## Runtime locomotion blend for the imported Arjun clips. Combat and special poses
## remain procedural layers on the same skeleton.

var ground_blend := 0.0
var water_blend := 0.0
var swim_blend := 0.0
var playback_rate := 1.0
var foot_contact_offset := 0.0
var skeleton: Skeleton3D
var idle_foot_y := 0.0

func configure(model: Node3D) -> bool:
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_error("Arjun animation tree needs an AnimationPlayer")
		return false
	var source: AnimationPlayer = players[0]
	var rigs := model.find_children("*", "Skeleton3D", true, false)
	if rigs.is_empty():
		push_error("Arjun animation tree needs a Skeleton3D")
		return false
	skeleton = rigs[0]
	idle_foot_y = _lowest_foot_y()
	var library := AnimationLibrary.new()
	for name in ["idle", "walk", "swim_idle", "swim_forward"]:
		if not source.has_animation(name):
			push_error("Arjun animation tree missing clip: " + name)
			return false
		var clip: Animation = _walk_clip(skeleton, source.get_animation("idle")) if name == "walk" else source.get_animation(name).duplicate(true)
		clip.loop_mode = Animation.LOOP_LINEAR
		# CharacterBody3D owns travel. A baked root translation must not move the
		# skeleton independently of its collision shape.
		for track in range(clip.get_track_count() - 1, -1, -1):
			if str(clip.track_get_path(track)).ends_with(":Root") and clip.track_get_type(track) == Animation.TYPE_POSITION_3D:
				clip.remove_track(track)
		library.add_animation(name, clip)
	source.add_animation_library("motion", library)
	anim_player = get_path_to(source)
	var ground := AnimationNodeBlendSpace1D.new()
	ground.min_space = 0.0
	ground.max_space = 1.0
	ground.add_blend_point(_clip("motion/idle"), 0.0, -1, "idle")
	ground.add_blend_point(_clip("motion/walk"), 1.0, -1, "walk")
	var water := AnimationNodeBlendSpace1D.new()
	water.min_space = 0.0
	water.max_space = 1.0
	water.add_blend_point(_clip("motion/swim_idle"), 0.0, -1, "swim_idle")
	water.add_blend_point(_clip("motion/swim_forward"), 1.0, -1, "swim_forward")
	var graph := AnimationNodeBlendTree.new()
	graph.add_node("ground", ground)
	graph.add_node("water", water)
	graph.add_node("swim", AnimationNodeBlend2.new())
	graph.connect_node("swim", 0, "ground")
	graph.connect_node("swim", 1, "water")
	graph.connect_node("output", 0, "swim")
	tree_root = graph
	callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	active = true
	return true

func _clip(name: String) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = name
	return node

func _walk_clip(skeleton: Skeleton3D, idle: Animation) -> Animation:
	var clip := Animation.new()
	clip.length = 0.88
	clip.loop_mode = Animation.LOOP_LINEAR
	var tracks: Dictionary = {}
	for bone in ["pelvis", "spine_01", "spine_02", "head", "thigh_l", "thigh_r", "calf_l", "calf_r", "foot_l", "foot_r", "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r"]:
		if skeleton.find_bone(bone) < 0: continue
		var track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track, NodePath("Arjun_Rig/Skeleton3D:" + bone))
		tracks[bone] = track
	for frame in 25:
		var cycle := TAU * float(frame) / 24.0
		var left := cos(cycle)
		var right := -left
		var angles := {
			"pelvis": Vector3(0.0, sin(cycle) * 0.06, sin(cycle) * 0.025),
			"spine_01": Vector3(0.07, -sin(cycle) * 0.045, 0.0),
			"spine_02": Vector3(-0.025, -sin(cycle) * 0.035, 0.0),
			"head": Vector3(-0.045, 0.0, 0.0),
			"thigh_l": Vector3(left * 0.52, 0.0, 0.0),
			"thigh_r": Vector3(right * 0.52, 0.0, 0.0),
			"calf_l": Vector3(maxf(0.0, -sin(cycle)) * 0.72 + 0.10, 0.0, 0.0),
			"calf_r": Vector3(maxf(0.0, sin(cycle)) * 0.72 + 0.10, 0.0, 0.0),
			"foot_l": Vector3(-left * 0.20, 0.0, 0.0),
			"foot_r": Vector3(-right * 0.20, 0.0, 0.0),
			"upperarm_l": Vector3(-left * 0.12, 0.0, 0.0),
			"upperarm_r": Vector3(-right * 0.12, 0.0, 0.0),
			"lowerarm_l": Vector3(-0.12, 0.0, 0.0),
			"lowerarm_r": Vector3(-0.12, 0.0, 0.0)
		}
		for bone in tracks:
			var index := skeleton.find_bone(bone)
			var axes := skeleton.get_bone_global_rest(index).basis.orthonormalized().inverse()
			var angle: Vector3 = angles[bone]
			var idle_track := idle.find_track(NodePath("Arjun_Rig/Skeleton3D:" + bone), Animation.TYPE_ROTATION_3D)
			var base: Quaternion = idle.track_get_key_value(idle_track, 0) if idle_track >= 0 else skeleton.get_bone_pose_rotation(index)
			var rotation := base * Quaternion(axes * Vector3.RIGHT, angle.x) * Quaternion(axes * Vector3.UP, angle.y) * Quaternion(axes * Vector3.BACK, angle.z)
			clip.rotation_track_insert_key(tracks[bone], clip.length * float(frame) / 24.0, rotation)
	return clip

func update_motion(delta: float, ground_speed: float, water_speed: float, in_water: bool) -> void:
	var weight := 1.0 - exp(-8.0 * delta)
	ground_blend = lerpf(ground_blend, clampf(ground_speed, 0.0, 1.0), weight)
	water_blend = lerpf(water_blend, clampf(water_speed, 0.0, 1.0), weight)
	swim_blend = lerpf(swim_blend, 1.0 if in_water else 0.0, weight)
	set("parameters/ground/blend_position", ground_blend)
	set("parameters/water/blend_position", water_blend)
	set("parameters/swim/blend_amount", swim_blend)
	# The collision body travels at 4 m/s at its normal pace. Match the
	# in-place gait cadence to that travel so planted feet slide less.
	var ground_rate := clampf(ground_speed * 1.7, 0.7, 2.2)
	playback_rate = lerpf(playback_rate, lerpf(ground_rate, 1.0, swim_blend), weight)
	advance(delta * playback_rate)
	# The source boots rise as the thighs swing. Move only the visual rig down
	# toward the lowest boot while leaving collision and travel untouched.
	var correction := clampf((_lowest_foot_y() - idle_foot_y) * 2.0 + ground_blend * 0.08, 0.0, 0.28)
	foot_contact_offset = lerpf(foot_contact_offset, correction * (1.0 - swim_blend), weight)

func _lowest_foot_y() -> float:
	if skeleton == null: return 0.0
	var lowest := INF
	for bone in ["foot_l", "foot_r"]:
		var index := skeleton.find_bone(bone)
		if index >= 0:
			lowest = minf(lowest, (skeleton.transform * skeleton.get_bone_global_pose(index)).origin.y)
	return 0.0 if lowest == INF else lowest
