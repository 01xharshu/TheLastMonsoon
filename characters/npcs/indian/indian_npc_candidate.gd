extends Node3D
## Isolated motion study; clothing and ground contact remain unapproved.
@export_enum("village_farmer", "village_woman", "village_fruit_seller", "village_weaver_assistant", "dock_porter", "boatman", "record_clerk") var candidate_slug: String = "village_farmer"
var animation_player: AnimationPlayer
var animation_tree: AnimationTree
var locomotion_blend := 0.0
var walking := false
var playback_rate := 1.0

func _ready() -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var path := "res://WorkingAssets/NPCs/%s/%s_rigged_candidate.glb" % [candidate_slug, candidate_slug]
	if document.append_from_file(ProjectSettings.globalize_path(path), state) != OK:
		push_error("Cannot load Indian motion candidate: " + path)
		return
	var figure := document.generate_scene(state)
	add_child(figure)
	animation_player = figure.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player == null:
		push_error("Missing candidate AnimationPlayer")
		return
	for clip_name in ["idle", "walk"]:
		if not animation_player.has_animation(clip_name):
			push_error("Missing candidate clip: " + clip_name)
			return
		var clip := animation_player.get_animation(clip_name)
		if candidate_slug in ["dock_porter", "boatman", "record_clerk"]:
			# Exported sampling starts at 1/30 s; normalize the first key to zero
			# so every loop has the authored duration without an initial hold.
			var first_key := INF
			var last_key := 0.0
			for track in clip.get_track_count():
				for key in clip.track_get_key_count(track):
					var time := clip.track_get_key_time(track, key)
					first_key = minf(first_key, time)
					last_key = maxf(last_key, time)
			if first_key < INF and last_key > first_key:
				for track in clip.get_track_count():
					for key in clip.track_get_key_count(track):
						clip.track_set_key_time(track, key, clip.track_get_key_time(track, key) - first_key)
				clip.length = last_key - first_key
		clip.loop_mode = Animation.LOOP_LINEAR
	animation_player.stop()
	animation_tree = AnimationTree.new()
	animation_tree.name = "PersonalAnimationTree"
	add_child(animation_tree)
	animation_tree.anim_player = animation_tree.get_path_to(animation_player)
	animation_tree.root_node = animation_tree.get_path_to(animation_player.get_node(animation_player.root_node))
	var graph := AnimationNodeBlendTree.new()
	for clip_name in ["idle", "walk"]:
		var node := AnimationNodeAnimation.new()
		node.animation = clip_name
		graph.add_node(clip_name, node)
	graph.add_node("walk_rate", AnimationNodeTimeScale.new())
	graph.add_node("locomotion", AnimationNodeBlend2.new())
	graph.connect_node("walk_rate", 0, "walk")
	graph.connect_node("locomotion", 0, "idle")
	graph.connect_node("locomotion", 1, "walk_rate")
	graph.connect_node("output", 0, "locomotion")
	animation_tree.tree_root = graph
	animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animation_tree.active = true
	step_motion(0.0)

func _process(delta: float) -> void:
	step_motion(delta)

func step_motion(delta: float) -> void:
	if animation_tree == null:
		return
	locomotion_blend = move_toward(locomotion_blend, 1.0 if walking else 0.0, maxf(delta, 0.0) / 0.2)
	animation_tree.set("parameters/locomotion/blend_amount", locomotion_blend)
	animation_tree.set("parameters/walk_rate/scale", clampf(playback_rate, 0.1, 3.0))
	animation_tree.advance(maxf(delta, 0.0))
