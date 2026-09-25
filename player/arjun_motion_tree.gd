extends AnimationTree
## Runtime locomotion blend for the imported Arjun clips. Combat and special poses
## remain procedural layers on the same skeleton.

var ground_blend := 0.0
var water_blend := 0.0
var swim_blend := 0.0

func configure(model: Node3D) -> bool:
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_error("Arjun animation tree needs an AnimationPlayer")
		return false
	var source: AnimationPlayer = players[0]
	var library := AnimationLibrary.new()
	for name in ["idle", "walk", "swim_idle", "swim_forward"]:
		if not source.has_animation(name):
			push_error("Arjun animation tree missing clip: " + name)
			return false
		var clip: Animation = source.get_animation(name).duplicate(true)
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

func update_motion(delta: float, ground_speed: float, water_speed: float, in_water: bool) -> void:
	var weight := 1.0 - exp(-8.0 * delta)
	ground_blend = lerpf(ground_blend, clampf(ground_speed, 0.0, 1.0), weight)
	water_blend = lerpf(water_blend, clampf(water_speed, 0.0, 1.0), weight)
	swim_blend = lerpf(swim_blend, 1.0 if in_water else 0.0, weight)
	set("parameters/ground/blend_position", ground_blend)
	set("parameters/water/blend_position", water_blend)
	set("parameters/swim/blend_amount", swim_blend)
	advance(delta)
