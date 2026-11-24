extends SceneTree
## Build an Arjun AnimationLibrary from a local glTF using an explicit bone map.

func _initialize() -> void:
	bake.call_deferred()

func bake() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3:
		fail("Expected source.glb mapping.json output.res")
		return
	var config = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	if not config is Dictionary or not config.get("bones") is Dictionary or not config.get("clips") is Dictionary:
		fail("Mapping must contain bones and clips dictionaries")
		return
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	if document.append_from_file(args[0], state) != OK:
		fail("Unable to import source glTF")
		return
	var source := document.generate_scene(state)
	var target := load("res://characters/arjun/arjun.glb").instantiate() as Node3D
	root.add_child(source)
	root.add_child(target)
	var source_rig := find_node_by_type(source, "Skeleton3D") as Skeleton3D
	var target_rig := find_node_by_type(target, "Skeleton3D") as Skeleton3D
	var source_player := find_node_by_type(source, "AnimationPlayer") as AnimationPlayer
	var target_player := find_node_by_type(target, "AnimationPlayer") as AnimationPlayer
	if source_rig == null or target_rig == null or source_player == null or target_player == null:
		fail("Both rigs need a skeleton and AnimationPlayer")
		return
	var target_path := target_player.get_node(target_player.root_node).get_path_to(target_rig)
	var library := AnimationLibrary.new()
	for name in config.clips:
		if name not in ["walk", "run", "jump_rise", "jump_fall", "swim_idle", "swim_forward", "climb_leap", "climb_catch", "climb_hang"] or not source_player.has_animation(config.clips[name]):
			fail("Missing or unsupported locomotion clip: " + str(name))
			return
		var input_name: String = config.clips[name]
		var clip := Animation.new()
		clip.length = source_player.get_animation(input_name).length
		clip.loop_mode = Animation.LOOP_LINEAR
		var bindings: Array[Dictionary] = []
		for bone in config.bones:
			var from := source_rig.find_bone(config.bones[bone])
			var to := target_rig.find_bone(bone)
			if from < 0 or to < 0:
				fail("Unknown mapped bone: " + str(bone))
				return
			var track := clip.add_track(Animation.TYPE_ROTATION_3D)
			clip.track_set_path(track, NodePath(str(target_path) + ":" + str(bone)))
			var source_rest := source_rig.get_bone_global_rest(from).basis.orthonormalized()
			var target_rest := target_rig.get_bone_global_rest(to).basis.orthonormalized()
			bindings.append({"from":from, "track":track,
				"alignment":(target_rest.inverse() * source_rest).get_rotation_quaternion(),
				"source_rest":source_rig.get_bone_rest(from).basis.orthonormalized().get_rotation_quaternion(),
				"target_rest":target_rig.get_bone_rest(to).basis.orthonormalized().get_rotation_quaternion()})
		source_rig.reset_bone_poses()
		source_player.play(input_name)
		var frames := maxi(1, ceili(clip.length * 60.0))
		for frame in range(frames + 1):
			var time := clip.length * frame / frames
			source_player.seek(time, true)
			for binding in bindings:
				var alignment: Quaternion = binding.alignment
				var delta: Quaternion = binding.source_rest.inverse() * source_rig.get_bone_pose_rotation(binding.from)
				var rotation: Quaternion = binding.target_rest * alignment * delta * alignment.inverse()
				clip.rotation_track_insert_key(binding.track, time, rotation.normalized())
		source_player.stop()
		library.add_animation(name, clip)
	if library.get_animation_list().is_empty() or ResourceSaver.save(library, args[2]) != OK:
		fail("Could not save locomotion library")
		return
	print("BAKED LOCOMOTION ", library.get_animation_list())
	quit()

func find_node_by_type(parent: Node, type: String) -> Node:
	var matches := parent.find_children("*", type, true, false)
	return matches[0] if not matches.is_empty() else null

func fail(message: String) -> void:
	push_error(message)
	quit(1)
