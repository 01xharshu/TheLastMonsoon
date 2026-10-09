extends AnimationTree
## Runtime locomotion blend for the imported Arjun clips. Combat and special poses
## remain procedural layers on the same skeleton.

var air_blend := 0.0
var ground_blend := 0.0
var water_blend := 0.0
var swim_blend := 0.0
var playback_rate := 1.0
var foot_contact_offset := 0.0
var skeleton: Skeleton3D
var idle_foot_y := 0.0
var rest_blend := 0.0
var sit_down_seconds := 1.5
var stand_up_seconds := 1.5
var climb_blend := 0.0
var pistol_aim_blend := 0.0
var pistol_reload_blend := 0.0
var pistol_recoil_blend := 0.0
var pistol_aim_phase := 0.0
var pistol_reload_phase := 0.0
var longgun_aim_blend := 0.0
var longgun_ready_blend := 0.0
var longgun_reload_blend := 0.0
var longgun_recoil_blend := 0.0

func configure(model: Node3D) -> bool:
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_error("Arjun animation tree needs an AnimationPlayer")
		return false
	var source: AnimationPlayer = players[0]
	if source.has_animation("sit_down"): sit_down_seconds = source.get_animation("sit_down").length
	if source.has_animation("stand_up"): stand_up_seconds = source.get_animation("stand_up").length
	var rigs := model.find_children("*", "Skeleton3D", true, false)
	if rigs.is_empty():
		push_error("Arjun animation tree needs a Skeleton3D")
		return false
	skeleton = rigs[0]
	idle_foot_y = _lowest_foot_y()
	var library := AnimationLibrary.new()
	for name in ["idle", "walk", "run", "swim_idle", "swim_forward", "sit_down", "sit_idle", "stand_up"]:
		if name != "run" and not source.has_animation(name):
			push_error("Arjun animation tree missing clip: " + name)
			return false
		var clip: Animation = _walk_clip(skeleton, source.get_animation("idle"), name == "run") if name in ["walk", "run"] else source.get_animation(name).duplicate(true)
		clip.loop_mode = Animation.LOOP_LINEAR if name in ["idle", "walk", "run", "swim_idle", "swim_forward", "sit_idle"] else Animation.LOOP_NONE
		# CharacterBody3D owns travel. A baked root translation must not move the
		# skeleton independently of its collision shape.
		for track in range(clip.get_track_count() - 1, -1, -1):
			if str(clip.track_get_path(track)).ends_with(":Root") and clip.track_get_type(track) == Animation.TYPE_POSITION_3D:
				clip.remove_track(track)
		library.add_animation(name, clip)
	library.add_animation("longgun_ready", _longgun_pose_clip(skeleton, source.get_animation("idle"), false))
	library.add_animation("longgun_aim", _longgun_pose_clip(skeleton, source.get_animation("idle"), true))
	var rest_clips := preload("res://player/arjun_rest_clips.gd")
	library.add_animation("lie_down", rest_clips.make(skeleton, source.get_animation("sit_idle"), source.get_animation("idle"), false))
	library.add_animation("rise_from_lie", rest_clips.make(skeleton, source.get_animation("sit_idle"), source.get_animation("idle"), true))
	for beat in ["reach", "hang", "load", "leap", "catch", "pull_left", "pull_right", "mantle", "mantle_press", "mantle_step", "recover"]:
		library.add_animation("climb_" + beat, _climb_pose_clip(skeleton, source.get_animation("idle"), beat))
	for beat in ["jump_rise", "jump_fall"]:
		library.add_animation(beat, _climb_pose_clip(skeleton, source.get_animation("idle"), beat))
	library.add_animation("detention_arrest", _detention_clip(source.get_animation("idle"), true))
	library.add_animation("detention_wait", _detention_clip(source.get_animation("idle"), false))
	for action in ["punch","punch_left","kick","jump_kick","grapple","sword","knife","hit","block","dodge"]:
		library.add_animation(action,preload("res://player/melee_motion.gd").make(skeleton,source.get_animation("idle"),action))
	source.add_animation_library("motion", library)
	anim_player = get_path_to(source)
	var ground := AnimationNodeBlendSpace1D.new()
	ground.min_space = 0.0
	ground.max_space = 1.75
	ground.add_blend_point(_clip("motion/idle"), 0.0, -1, "idle")
	ground.add_blend_point(_clip("motion/walk"), 1.0, -1, "walk")
	ground.add_blend_point(_clip("motion/run"), 1.75, -1, "run")
	var water := AnimationNodeBlendSpace1D.new()
	water.min_space = 0.0
	water.max_space = 1.0
	water.add_blend_point(_clip("motion/swim_idle"), 0.0, -1, "swim_idle")
	water.add_blend_point(_clip("motion/swim_forward"), 1.0, -1, "swim_forward")
	var graph := AnimationNodeBlendTree.new()
	graph.add_node("ground", ground)
	graph.add_node("water", water)
	graph.add_node("swim", AnimationNodeBlend2.new())
	var air := AnimationNodeBlendSpace1D.new()
	air.min_space = -1.0
	air.max_space = 1.0
	air.add_blend_point(_clip("motion/jump_fall"), -1.0, -1, "fall")
	air.add_blend_point(_clip("motion/jump_rise"), 1.0, -1, "rise")
	graph.add_node("air_pose", air)
	graph.add_node("air", AnimationNodeBlend2.new())
	var longgun_ready := AnimationNodeBlend2.new()
	var longgun_aim := AnimationNodeBlend2.new()
	for layer in [longgun_ready, longgun_aim]:
		layer.set_filter_enabled(true)
		for bone in ["spine_02", "head"]:
			layer.set_filter_path(NodePath("Arjun_Rig/Skeleton3D:" + bone), true)
	graph.add_node("longgun_ready", longgun_ready)
	graph.add_node("longgun_aim", longgun_aim)
	graph.add_node("longgun_ready_pose", _clip("motion/longgun_ready"))
	graph.add_node("longgun_aim_pose", _clip("motion/longgun_aim"))
	graph.add_node("sit_down", _clip("motion/sit_down"))
	graph.add_node("stand_up", _clip("motion/stand_up"))
	graph.add_node("sit_down_seek", AnimationNodeTimeSeek.new())
	graph.add_node("stand_up_seek", AnimationNodeTimeSeek.new())
	graph.add_node("sit_transition", AnimationNodeBlend2.new())
	graph.add_node("sit_idle", _clip("motion/sit_idle"))
	graph.add_node("sit", AnimationNodeBlend2.new())
	graph.add_node("rest", AnimationNodeBlend2.new())
	graph.add_node("lie_down", _clip("motion/lie_down"))
	graph.add_node("rise_from_lie", _clip("motion/rise_from_lie"))
	graph.add_node("lie_down_seek", AnimationNodeTimeSeek.new())
	graph.add_node("rise_from_lie_seek", AnimationNodeTimeSeek.new())
	graph.add_node("sleep_motion", AnimationNodeBlend2.new())
	graph.add_node("sleep", AnimationNodeBlend2.new())
	var climb := AnimationNodeBlendSpace1D.new()
	climb.min_space = 0.0
	climb.max_space = 1.0
	for beat in [{"name":"reach","at":0.0},{"name":"hang","at":0.14},{"name":"load","at":0.18},{"name":"leap","at":0.40},{"name":"catch","at":0.65},{"name":"pull_left","at":0.28},{"name":"pull_right","at":0.56},{"name":"mantle","at":0.78},{"name":"mantle_press","at":0.86},{"name":"mantle_step","at":0.90},{"name":"recover","at":1.0}]:
		climb.add_blend_point(_clip("motion/climb_" + beat.name), beat.at, -1, beat.name)
	graph.add_node("climb_pose", climb)
	preload("res://player/climb_animation.gd").configure(graph)
	graph.add_node("climb", AnimationNodeBlend2.new())
	graph.connect_node("air", 0, "ground")
	graph.connect_node("air", 1, "air_pose")
	graph.connect_node("swim", 0, "air")
	graph.connect_node("swim", 1, "water")
	graph.connect_node("longgun_ready", 0, "swim")
	graph.connect_node("longgun_ready", 1, "longgun_ready_pose")
	graph.connect_node("longgun_aim", 0, "longgun_ready")
	graph.connect_node("longgun_aim", 1, "longgun_aim_pose")
	preload("res://player/pistol_motion_layer.gd").configure(graph,library,skeleton,source.get_animation("idle"))
	graph.connect_node("rest", 0, "pistol_recoil")
	graph.connect_node("sit_down_seek", 0, "sit_down")
	graph.connect_node("stand_up_seek", 0, "stand_up")
	graph.connect_node("sit_transition", 0, "sit_down_seek")
	graph.connect_node("sit_transition", 1, "stand_up_seek")
	graph.connect_node("sit", 0, "sit_transition")
	graph.connect_node("sit", 1, "sit_idle")
	graph.connect_node("rest", 1, "sit")
	graph.connect_node("sleep", 0, "rest")
	graph.connect_node("lie_down_seek", 0, "lie_down")
	graph.connect_node("rise_from_lie_seek", 0, "rise_from_lie")
	graph.connect_node("sleep_motion", 0, "lie_down_seek")
	graph.connect_node("sleep_motion", 1, "rise_from_lie_seek")
	graph.connect_node("sleep", 1, "sleep_motion")
	graph.connect_node("climb", 0, "sleep")
	graph.connect_node("climb", 1, "climb_selector")
	graph.add_node("detention_pose", AnimationNodeBlend2.new())
	graph.add_node("detention_arrest", _clip("motion/detention_arrest"))
	graph.add_node("detention_wait", _clip("motion/detention_wait"))
	var detention_layer := AnimationNodeBlend2.new()
	detention_layer.filter_enabled = true
	for bone in ["spine_01","spine_02","head","upperarm_l","upperarm_r","lowerarm_l","lowerarm_r","hand_l","hand_r"]:
		detention_layer.set_filter_path(NodePath("Arjun_Rig/Skeleton3D:"+bone),true)
	graph.add_node("detention", detention_layer)
	graph.connect_node("detention_pose", 0, "detention_wait")
	graph.connect_node("detention_pose", 1, "detention_arrest")
	graph.connect_node("detention", 0, "climb")
	graph.connect_node("detention", 1, "detention_pose")
	var actions := AnimationNodeBlendSpace1D.new()
	actions.min_space = 0.0
	actions.max_space = 9.0
	actions.blend_mode = AnimationNodeBlendSpace1D.BLEND_MODE_DISCRETE
	var action_index := 0
	for action in ["punch","punch_left","kick","jump_kick","grapple","sword","knife","hit","block","dodge"]:
		actions.add_blend_point(_clip("motion/"+action),float(action_index),-1,action)
		action_index += 1
	graph.add_node("melee_action",actions)
	graph.add_node("melee_seek",AnimationNodeTimeSeek.new())
	var melee_layer:=AnimationNodeBlend2.new()
	for bone in ["spine_01","spine_02","head","upperarm_l","upperarm_r","lowerarm_l","lowerarm_r","hand_l","hand_r"]:
		melee_layer.set_filter_path(NodePath("Arjun_Rig/Skeleton3D:"+bone),true)
	for side in ["l","r"]:
		for finger in ["index","middle","ring","pinky","thumb"]:
			for joint in ["01","02","03"]:melee_layer.set_filter_path(NodePath("Arjun_Rig/Skeleton3D:"+finger+"_"+joint+"_"+side),true)
	graph.add_node("melee",melee_layer)
	graph.connect_node("melee_seek",0,"melee_action")
	graph.connect_node("melee",0,"detention")
	graph.connect_node("melee",1,"melee_seek")
	graph.connect_node("output", 0, "melee")
	tree_root = graph
	callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	active = true
	return true

func _clip(name: String) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.animation = name
	return node

func _climb_pose_clip(rig: Skeleton3D, idle: Animation, beat: String) -> Animation:
	var clip := Animation.new()
	clip.length = 0.25
	clip.loop_mode = Animation.LOOP_LINEAR
	var poses := {
		"reach": {"pelvis":Vector3(-.10,0,0), "spine_01":Vector3(-.20,0,0), "spine_02":Vector3(-.13,0,0), "head":Vector3(.13,0,0), "upperarm_l":Vector3(-1.55,-.08,-.22), "upperarm_r":Vector3(-1.35,-.08,.22), "lowerarm_l":Vector3(-.45,0,0), "lowerarm_r":Vector3(-.55,0,0), "thigh_l":Vector3(-.40,0,0), "thigh_r":Vector3(-.65,0,0), "calf_l":Vector3(.5,0,0), "calf_r":Vector3(.8,0,0)},
		"load": {"pelvis":Vector3(-.18,.04,.10),"spine_01":Vector3(-.28,0,0),"spine_02":Vector3(-.12,.06,0),"upperarm_l":Vector3(-1.65,0,-.22),"upperarm_r":Vector3(-1.65,0,.22),"lowerarm_l":Vector3(-.40,0,0),"lowerarm_r":Vector3(-.40,0,0),"thigh_l":Vector3(-1.1,0,0),"thigh_r":Vector3(-1.3,0,0),"calf_l":Vector3(1.4,0,0),"calf_r":Vector3(1.5,0,0)},
		"leap": {"pelvis":Vector3(-.10,-.05,-.08),"spine_01":Vector3(-.18,0,0),"head":Vector3(.16,0,0),"upperarm_l":Vector3(-2.15,0,-.20),"upperarm_r":Vector3(-2.00,0,.20),"lowerarm_l":Vector3(-.12,0,0),"lowerarm_r":Vector3(-.20,0,0),"thigh_l":Vector3(-.65,0,0),"thigh_r":Vector3(-1.05,0,0),"calf_l":Vector3(.8,0,0),"calf_r":Vector3(1.4,0,0)},
		"catch": {"pelvis":Vector3(-.06,.05,.08),"spine_01":Vector3(-.12,0,0),"head":Vector3(.15,0,0),"upperarm_l":Vector3(-2.05,0,-.20),"upperarm_r":Vector3(-2.05,0,.20),"lowerarm_l":Vector3(-.18,0,0),"lowerarm_r":Vector3(-.18,0,0),"thigh_l":Vector3(-.65,0,0),"thigh_r":Vector3(-.75,0,0),"calf_l":Vector3(.9,0,0),"calf_r":Vector3(1.0,0,0)},
		"hang": {"pelvis":Vector3(-.05,0,0), "spine_01":Vector3(-.12,0,0), "spine_02":Vector3(-.08,0,0), "head":Vector3(.12,0,0), "upperarm_l":Vector3(-1.65,-.08,-.22), "upperarm_r":Vector3(-1.65,-.08,.22), "lowerarm_l":Vector3(-.28,0,0), "lowerarm_r":Vector3(-.28,0,0), "thigh_l":Vector3(-.65,0,0), "thigh_r":Vector3(-.65,0,0), "calf_l":Vector3(.85,0,0), "calf_r":Vector3(.85,0,0)},
		"pull_left": {"pelvis":Vector3(-.08,.04,-.035), "spine_01":Vector3(-.24,-.04,0), "spine_02":Vector3(-.16,-.03,0), "head":Vector3(.10,.03,0), "upperarm_l":Vector3(-1.72,-.08,-.22), "upperarm_r":Vector3(-1.60,-.08,.22), "lowerarm_l":Vector3(-.68,0,0), "lowerarm_r":Vector3(-.42,0,0), "thigh_l":Vector3(-1.0,0,0), "thigh_r":Vector3(-.45,0,0), "calf_l":Vector3(1.35,0,0), "calf_r":Vector3(.55,0,0)},
		"pull_right": {"pelvis":Vector3(-.08,-.04,.035), "spine_01":Vector3(-.24,.04,0), "spine_02":Vector3(-.16,.03,0), "head":Vector3(.10,-.03,0), "upperarm_l":Vector3(-1.60,-.08,-.22), "upperarm_r":Vector3(-1.72,-.08,.22), "lowerarm_l":Vector3(-.42,0,0), "lowerarm_r":Vector3(-.68,0,0), "thigh_l":Vector3(-.45,0,0), "thigh_r":Vector3(-1.0,0,0), "calf_l":Vector3(.55,0,0), "calf_r":Vector3(1.35,0,0)},
		"mantle": {"pelvis":Vector3(.08,0,0), "spine_01":Vector3(.15,0,0), "spine_02":Vector3(.10,0,0), "head":Vector3(-.10,0,0), "upperarm_l":Vector3(-.75,0,-.13), "upperarm_r":Vector3(-.75,0,.13), "lowerarm_l":Vector3(-.65,0,0), "lowerarm_r":Vector3(-.65,0,0), "thigh_l":Vector3(-1.05,0,0), "thigh_r":Vector3(-.75,0,0), "calf_l":Vector3(.7,0,0), "calf_r":Vector3(.6,0,0)},
		"mantle_press": {"pelvis":Vector3(.15,0,0), "spine_01":Vector3(.65,0,0), "spine_02":Vector3(.40,0,0), "head":Vector3(-.20,0,0), "upperarm_l":Vector3(-.55,0,-.13), "upperarm_r":Vector3(-.55,0,.13), "lowerarm_l":Vector3(-.60,0,0), "lowerarm_r":Vector3(-.60,0,0), "thigh_l":Vector3(-.90,0,0), "thigh_r":Vector3(-.50,0,0), "calf_l":Vector3(1.10,0,0), "calf_r":Vector3(.70,0,0)},
		"mantle_step": {"pelvis":Vector3(.08,0,-.04), "spine_01":Vector3(.27,0,0), "spine_02":Vector3(.12,0,0), "head":Vector3(-.12,0,0), "upperarm_l":Vector3(-.55,0,-.13), "upperarm_r":Vector3(-.55,0,.13), "lowerarm_l":Vector3(-.35,0,0), "lowerarm_r":Vector3(-.35,0,0), "thigh_l":Vector3(-1.15,0,0), "thigh_r":Vector3(-.35,0,0), "calf_l":Vector3(1.25,0,0), "calf_r":Vector3(.45,0,0)},
		"jump_rise": {"spine_01":Vector3(.12,0,0), "thigh_l":Vector3(-.60,0,0), "thigh_r":Vector3(-.35,0,0), "calf_l":Vector3(.95,0,0), "calf_r":Vector3(.70,0,0), "foot_l":Vector3(-.15,0,0), "foot_r":Vector3(-.12,0,0), "upperarm_l":Vector3(-.45,0,-.15), "upperarm_r":Vector3(-.45,0,.15), "lowerarm_l":Vector3(-.65,0,0), "lowerarm_r":Vector3(-.65,0,0)},
		"jump_fall": {"spine_01":Vector3(.08,0,0), "thigh_l":Vector3(-.18,0,0), "thigh_r":Vector3(-.12,0,0), "calf_l":Vector3(.30,0,0), "calf_r":Vector3(.25,0,0), "upperarm_l":Vector3(-.18,0,-.25), "upperarm_r":Vector3(-.18,0,.25), "lowerarm_l":Vector3(-.35,0,0), "lowerarm_r":Vector3(-.35,0,0)},
		"recover": {}
	}
	var angles: Dictionary = poses[beat]
	for bone in ["pelvis","spine_01","spine_02","head","upperarm_l","upperarm_r","lowerarm_l","lowerarm_r","thigh_l","thigh_r","calf_l","calf_r","foot_l","foot_r"]:
		var index := rig.find_bone(bone)
		if index < 0: continue
		var path := NodePath("Arjun_Rig/Skeleton3D:" + bone)
		var track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track, path)
		var idle_track := idle.find_track(path, Animation.TYPE_ROTATION_3D)
		var base: Quaternion = idle.track_get_key_value(idle_track, 0) if idle_track >= 0 else rig.get_bone_pose_rotation(index)
		var axes := rig.get_bone_global_rest(index).basis.orthonormalized().inverse()
		var angle: Vector3 = angles.get(bone, Vector3.ZERO)
		var rotation := base * Quaternion(axes * Vector3.RIGHT, angle.x) * Quaternion(axes * Vector3.UP, angle.y) * Quaternion(axes * Vector3.BACK, angle.z)
		clip.rotation_track_insert_key(track, 0.0, rotation)
		clip.rotation_track_insert_key(track, clip.length, rotation)
	return clip

func update_climb(delta: float, progress: float, leap_phase: String = "", phase_clock: float = 0.0) -> void:
	preload("res://player/climb_animation.gd").update(self,leap_phase,phase_clock)
	climb_blend = minf(1.0, climb_blend + delta * 10.0)
	set("parameters/climb/blend_amount", climb_blend)
	set("parameters/climb_pose/blend_position", clampf(progress, 0.0, 1.0))
	advance(delta)

func release_climb(delta: float) -> void:
	climb_blend = maxf(0.0, climb_blend - delta * 10.0)
	set("parameters/climb/blend_amount", climb_blend)

func _longgun_pose_clip(rig: Skeleton3D, idle: Animation, aimed: bool) -> Animation:
	# A library pose for cheek weld and upper-torso support. Hand/stock contact
	# remains a post-tree solve so locomotion never pulls palms off the gun.
	var clip := Animation.new()
	clip.length = 0.5
	clip.loop_mode = Animation.LOOP_LINEAR
	var angles := {
		"spine_02": Vector3(-0.055 if aimed else -0.025, -0.035 if aimed else 0.0, 0.0),
		"head": Vector3(0.11 if aimed else 0.025, -0.055 if aimed else 0.0, -0.025 if aimed else 0.0)
	}
	for bone in angles:
		var index := rig.find_bone(bone)
		if index < 0: continue
		var track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track, NodePath("Arjun_Rig/Skeleton3D:" + bone))
		var idle_track := idle.find_track(NodePath("Arjun_Rig/Skeleton3D:" + bone), Animation.TYPE_ROTATION_3D)
		var base: Quaternion = idle.track_get_key_value(idle_track, 0) if idle_track >= 0 else rig.get_bone_pose_rotation(index)
		var axes := rig.get_bone_global_rest(index).basis.orthonormalized().inverse()
		var angle: Vector3 = angles[bone]
		var rotation := base * Quaternion(axes * Vector3.RIGHT, angle.x) * Quaternion(axes * Vector3.UP, angle.y) * Quaternion(axes * Vector3.BACK, angle.z)
		clip.rotation_track_insert_key(track, 0.0, rotation)
		clip.rotation_track_insert_key(track, clip.length, rotation)
	return clip

func _walk_clip(skeleton: Skeleton3D, idle: Animation, running := false) -> Animation:
	var clip := Animation.new()
	clip.length = 0.65 if running else 0.88
	clip.loop_mode = Animation.LOOP_LINEAR
	var tracks: Dictionary = {}
	for bone in ["pelvis", "spine_01", "spine_02", "head", "thigh_l", "thigh_r", "calf_l", "calf_r", "foot_l", "foot_r", "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r"]:
		if skeleton.find_bone(bone) < 0: continue
		var track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track, NodePath("Arjun_Rig/Skeleton3D:" + bone))
		tracks[bone] = track
	if running:
		for side in ["l", "r"]:
			for finger in ["index", "middle", "ring", "pinky"]:
				for joint in ["01", "02"]:
					var bone: String = finger + "_" + joint + "_" + side
					if skeleton.find_bone(bone) < 0: continue
					var track := clip.add_track(Animation.TYPE_ROTATION_3D)
					clip.track_set_path(track, NodePath("Arjun_Rig/Skeleton3D:" + bone))
					tracks[bone] = track
	for frame in 25:
		# Reverse the in-place stride so a low foot travels against the body.
		var cycle := -TAU * float(frame) / 24.0
		var left := cos(cycle)
		var right := -left
		var stride := 0.80 if running else 0.52
		var knee := 1.05 if running else 0.72
		var arm_swing := 0.72 if running else 0.30
		var angles := {
			"pelvis": Vector3(0.0, sin(cycle) * (0.085 if running else 0.06), sin(cycle) * 0.025),
			"spine_01": Vector3(0.17 if running else 0.07, -sin(cycle) * 0.045, 0.0),
			"spine_02": Vector3(-0.025, -sin(cycle) * 0.035, 0.0),
			"head": Vector3(-0.045, 0.0, 0.0),
			"thigh_l": Vector3(left * stride, 0.0, 0.0),
			"thigh_r": Vector3(right * stride, 0.0, 0.0),
			"calf_l": Vector3(maxf(0.0, -sin(cycle)) * knee + 0.10, 0.0, 0.0),
			"calf_r": Vector3(maxf(0.0, sin(cycle)) * knee + 0.10, 0.0, 0.0),
			"foot_l": Vector3(-left * 0.20, 0.0, 0.0),
			"foot_r": Vector3(-right * 0.20, 0.0, 0.0),
			"upperarm_l": Vector3(-left * arm_swing, 0.0, 0.0),
			"upperarm_r": Vector3(-right * arm_swing, 0.0, 0.0),
			"lowerarm_l": Vector3(-0.72 if running else -0.12, 0.0, 0.0),
			"lowerarm_r": Vector3(-0.72 if running else -0.12, 0.0, 0.0)
		}
		for bone in tracks:
			var index := skeleton.find_bone(bone)
			if bone.contains("_01_") or bone.contains("_02_"):
				var idle_finger_track := idle.find_track(NodePath("Arjun_Rig/Skeleton3D:" + bone), Animation.TYPE_ROTATION_3D)
				var finger_base: Quaternion = idle.track_get_key_value(idle_finger_track, 0) if idle_finger_track >= 0 else skeleton.get_bone_pose_rotation(index)
				var bend := 0.50 if bone.contains("_01_") else 0.40
				clip.rotation_track_insert_key(tracks[bone], clip.length * float(frame) / 24.0, finger_base * Quaternion(Vector3.RIGHT, bend))
				continue
			var axes := skeleton.get_bone_global_rest(index).basis.orthonormalized().inverse()
			var angle: Vector3 = angles[bone]
			var idle_track := idle.find_track(NodePath("Arjun_Rig/Skeleton3D:" + bone), Animation.TYPE_ROTATION_3D)
			var base: Quaternion = idle.track_get_key_value(idle_track, 0) if idle_track >= 0 else skeleton.get_bone_pose_rotation(index)
			var rotation := base * Quaternion(axes * Vector3.RIGHT, angle.x) * Quaternion(axes * Vector3.UP, angle.y) * Quaternion(axes * Vector3.BACK, angle.z)
			clip.rotation_track_insert_key(tracks[bone], clip.length * float(frame) / 24.0, rotation)
	return clip

func update_motion(delta: float, ground_speed: float, water_speed: float, in_water: bool, grounded: bool = true, vertical_speed: float = 0.0) -> void:
	set("parameters/detention/blend_amount", 0.0)
	set("parameters/sleep/blend_amount", 0.0)
	set("parameters/rest/blend_amount", rest_blend)
	var weight := 1.0 - exp(-8.0 * delta)
	ground_blend = lerpf(ground_blend, clampf(ground_speed, 0.0, 1.75), weight)
	water_blend = lerpf(water_blend, clampf(water_speed, 0.0, 1.0), weight)
	air_blend = lerpf(air_blend, 1.0 if not grounded and not in_water else 0.0, 1.0 - exp(-16.0 * delta))
	set("parameters/air/blend_amount", air_blend)
	set("parameters/air_pose/blend_position", clampf(vertical_speed / 3.0, -1.0, 1.0))
	swim_blend = lerpf(swim_blend, 1.0 if in_water else 0.0, weight)
	set("parameters/ground/blend_position", ground_blend)
	set("parameters/water/blend_position", water_blend)
	set("parameters/swim/blend_amount", swim_blend)
	# The collision body travels at 4 m/s at its normal pace. Match the
	# in-place gait cadence to that travel so planted feet slide less.
	var run_mix := clampf((ground_speed - 1.0) / 0.75, 0.0, 1.0)
	var ground_rate := lerpf(clampf(ground_speed * 1.7, 0.7, 1.7), 1.4, run_mix)
	playback_rate = lerpf(playback_rate, lerpf(ground_rate, lerpf(0.75, 1.25, water_blend), swim_blend), weight)
	advance(delta * playback_rate)
	# The source boots rise as the thighs swing. Move only the visual rig down
	# toward the lowest boot while leaving collision and travel untouched.
	var correction := clampf((_lowest_foot_y() - idle_foot_y) + ground_blend * 0.04, 0.0, 0.20)
	foot_contact_offset = lerpf(foot_contact_offset, correction * (1.0 - swim_blend) * (1.0 - air_blend), weight)

func update_rest(delta: float, seated_weight: float, progress: float = 0.38, waking: bool = false) -> void:
	preload("res://player/pistol_motion_layer.gd").clear(self)
	pistol_aim_blend = 0.0
	pistol_reload_blend = 0.0
	pistol_recoil_blend = 0.0
	pistol_aim_phase = 0.0
	pistol_reload_phase = 0.0
	var recline := clampf((progress - 0.38) / 0.52, 0.0, 1.0)
	set("parameters/sleep/blend_amount", smoothstep(0.36, 0.42, progress))
	set("parameters/sleep_motion/blend_amount", 1.0 if waking else 0.0)
	set("parameters/lie_down_seek/seek_request", recline * 0.52)
	set("parameters/rise_from_lie_seek/seek_request", (1.0 - recline) * 0.36)
	rest_blend = clampf(seated_weight, 0.0, 1.0)
	longgun_ready_blend = 0.0
	longgun_aim_blend = 0.0
	set("parameters/longgun_ready/blend_amount", 0.0)
	set("parameters/longgun_aim/blend_amount", 0.0)
	set("parameters/ground/blend_position", 0.0)
	set("parameters/swim/blend_amount", 0.0)
	set("parameters/sit_transition/blend_amount", 1.0 if waking else 0.0)
	set("parameters/sit/blend_amount", smoothstep(0.2, 0.38, progress))
	set("parameters/sit_down_seek/seek_request", clampf(progress / 0.38, 0.0, 1.0) * sit_down_seconds)
	set("parameters/stand_up_seek/seek_request", clampf((0.38 - progress) / 0.38, 0.0, 1.0) * stand_up_seconds)
	set("parameters/rest/blend_amount", rest_blend)
	advance(delta)

func update_pistol_motion(delta: float, equipped: bool, aiming: bool, reload_fraction: float, shot_recoil: float) -> void:
	# Keep the upper-body action envelopes on the same clock as locomotion.
	# The grip solver consumes these after the tree advances, so contact follows
	# the final blended skeleton rather than a stale idle pose.
	var weight := 1.0 - exp(-14.0 * delta)
	pistol_aim_phase = move_toward(pistol_aim_phase,1.0 if equipped and aiming and reload_fraction < 0.0 else 0.0,delta*3.5)
	pistol_reload_phase = move_toward(pistol_reload_phase,1.0 if equipped and reload_fraction >= 0.0 else 0.0,delta*3.5)
	pistol_aim_blend = smoothstep(0.0,1.0,pistol_aim_phase)
	pistol_reload_blend = smoothstep(0.0,1.0,pistol_reload_phase)
	pistol_recoil_blend = lerpf(pistol_recoil_blend, clampf(shot_recoil / 0.075, 0.0, 1.0) if equipped else 0.0, weight)
	set("parameters/pistol_aim/blend_amount",pistol_aim_blend)
	set("parameters/pistol_reload/blend_amount",pistol_reload_blend)
	set("parameters/pistol_recoil/blend_amount",pistol_recoil_blend)

func update_longgun_motion(delta: float, equipped: bool, aiming: bool, reload_fraction: float, shot_recoil: float) -> void:
	# These weights follow the same manual tree advance as locomotion. The
	# stock and two palm targets are solved after the blended skeleton updates.
	var weight := 1.0 - exp(-12.0 * delta)
	longgun_ready_blend = lerpf(longgun_ready_blend, 1.0 if equipped else 0.0, weight)
	longgun_aim_blend = lerpf(longgun_aim_blend, 1.0 if equipped and aiming and reload_fraction < 0.0 else 0.0, weight)
	longgun_reload_blend = lerpf(longgun_reload_blend, 1.0 if equipped and reload_fraction >= 0.0 else 0.0, weight)
	longgun_recoil_blend = lerpf(longgun_recoil_blend, clampf(shot_recoil / 0.075, 0.0, 1.0) if equipped else 0.0, weight)
	set("parameters/longgun_ready/blend_amount", longgun_ready_blend)
	set("parameters/longgun_aim/blend_amount", longgun_aim_blend)

func _lowest_foot_y() -> float:
	if skeleton == null: return 0.0
	var lowest := INF
	for bone in ["foot_l", "foot_r"]:
		var index := skeleton.find_bone(bone)
		if index >= 0:
			lowest = minf(lowest, (skeleton.transform * skeleton.get_bone_global_pose(index)).origin.y)
	return 0.0 if lowest == INF else lowest

func _detention_clip(idle: Animation, restrained: bool) -> Animation:
	var clip: Animation = idle.duplicate(true)
	clip.length = 6.0
	clip.loop_mode = Animation.LOOP_LINEAR
	# Hold the planted lower body; author the six-second breathing loop above it.
	for track in clip.get_track_count():
		if clip.track_get_key_count(track)==0: continue
		var first: Variant = clip.track_get_key_value(track, 0)
		for key in range(clip.track_get_key_count(track)-1,-1,-1): clip.track_remove_key(track,key)
		clip.track_insert_key(track,0.0,first)
		clip.track_insert_key(track,clip.length,first)
	for bone in ["spine_01", "spine_02", "head", "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r"]:
		var index := skeleton.find_bone(bone)
		if index < 0: continue
		var path := NodePath("Arjun_Rig/Skeleton3D:" + bone)
		var old := clip.find_track(path, Animation.TYPE_ROTATION_3D)
		if old >= 0: clip.remove_track(old)
		var track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track, path)
		var source_track := idle.find_track(path, Animation.TYPE_ROTATION_3D)
		var base: Quaternion = idle.track_get_key_value(source_track, 0) if source_track >= 0 else skeleton.get_bone_pose_rotation(index)
		var axes := skeleton.get_bone_global_rest(index).basis.orthonormalized().inverse()
		for frame in 33:
			var t := float(frame)/32.0
			var breathe := sin(t*TAU*2.0)
			var angles := Vector3.ZERO
			if bone=="spine_01": angles.x = 0.055 if restrained else 0.035
			if bone=="spine_02": angles.x = breathe*0.012
			if bone=="head": angles = Vector3(0.055, sin(t*TAU)*0.10 if not restrained else sin(t*TAU)*0.035, 0)
			if restrained and bone.begins_with("upperarm"): angles = Vector3(0.40,0,0.12 if bone.ends_with("l") else -0.12)
			if restrained and bone.begins_with("lowerarm"): angles.x = -1.05
			var rotation := base * Quaternion(axes*Vector3.RIGHT,angles.x) * Quaternion(axes*Vector3.UP,angles.y) * Quaternion(axes*Vector3.BACK,angles.z)
			clip.rotation_track_insert_key(track, t*clip.length, rotation)
	return clip

func update_detention(delta: float, amount: float, arrested: bool, speed: float = 0.0) -> void:
	preload("res://player/pistol_motion_layer.gd").clear(self)
	set("parameters/ground/blend_position", clampf(speed/4.0,0,1))
	set("parameters/air/blend_amount", 0.0)
	set("parameters/swim/blend_amount", 0.0)
	set("parameters/rest/blend_amount", 0.0)
	set("parameters/sleep/blend_amount", 0.0)
	set("parameters/climb/blend_amount", 0.0)
	set("parameters/longgun_ready/blend_amount", 0.0)
	set("parameters/longgun_aim/blend_amount", 0.0)
	set("parameters/detention/blend_amount", amount)
	var mode_weight: float = get("parameters/detention_pose/blend_amount")
	set("parameters/detention_pose/blend_amount", move_toward(mode_weight, 1.0 if arrested else 0.0, delta*1.5))
	advance(delta)

func set_melee(action: int, progress: float) -> void:
	(tree_root as AnimationNodeBlendTree).get_node("melee").filter_enabled=action < 2 or (action >= 4 and action != 9)
	set("parameters/melee/blend_amount",1.0 if progress >= 0.0 else 0.0)
	set("parameters/melee_action/blend_position",float(action))
	if progress >= 0.0:
		set("parameters/melee_seek/seek_request",clampf(progress,0,1)*(.45 if action==7 else .5 if action==8 else .42 if action==9 else .68 if action==5 else .55 if action==6 else 1.2 if action == 4 else .52 if action >= 2 else .42))
