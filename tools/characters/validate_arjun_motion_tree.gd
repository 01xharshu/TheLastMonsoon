extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var model: Node3D = load("res://characters/arjun/arjun.glb").instantiate()
	root.add_child(model)
	var tree: AnimationTree = load("res://player/arjun_motion_tree.gd").new()
	model.add_child(tree)
	if not tree.configure(model):
		push_error("ARJUN MOTION TREE: failed to configure")
		preload("res://tools/test_audio_cleanup.gd").finish(self,1)
		return
	var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var thigh := skeleton.find_bone("thigh_l")
	tree.update_motion(0.3, 1.0, 0.0, false)
	var walk_rotation := skeleton.get_bone_pose_rotation(thigh)
	if tree.playback_rate <= 1.0:
		push_error("ARJUN MOTION TREE: walk cadence did not increase with travel speed")
		preload("res://tools/test_audio_cleanup.gd").finish(self,1)
		return
	for i in 10: tree.update_motion(0.1, 0.0, 0.0, false)
	var idle_rotation := skeleton.get_bone_pose_rotation(thigh)
	var head := skeleton.find_bone("head")
	var neutral_head := skeleton.get_bone_pose_rotation(head)
	tree.update_climb(0.2, 0.35)
	if tree.climb_blend < 0.99 or absf(float(tree.get("parameters/climb_pose/blend_position")) - 0.35) > 0.01:
		push_error("ARJUN MOTION TREE: climb pull pose did not engage")
		preload("res://tools/test_audio_cleanup.gd").finish(self,1)
		return
	var arm := skeleton.find_bone("upperarm_r")
	tree.update_climb(.2,.28,"settle",.13)
	var settled_arm := skeleton.get_bone_pose_rotation(arm)
	var reference_arm := pair_reference(tree,skeleton,arm,"catch","hang",.5)
	if settled_arm.angle_to(reference_arm)>.01:
		push_error("ARJUN MOTION TREE: settling passed through unrelated pull/leap poses")
		preload("res://tools/test_audio_cleanup.gd").finish(self,1)
		return
	tree.update_climb(.2,.50,"flight",.435)
	var airborne_arm := skeleton.get_bone_pose_rotation(arm)
	var flight_weight: float = preload("res://player/climb_animation.gd").position("flight",.435)-3.0
	reference_arm = pair_reference(tree,skeleton,arm,"leap","catch",flight_weight)
	if airborne_arm.angle_to(reference_arm)>.01:
		push_error("ARJUN MOTION TREE: airborne reach passed through alternating pull pose")
		preload("res://tools/test_audio_cleanup.gd").finish(self,1)
		return
	print("PASS dedicated leap and settle bone poses exclude alternating pulls")
	var spine := skeleton.find_bone("spine_01")
	tree.update_climb(0.2,.78)
	var hanging_spine := skeleton.get_bone_pose_rotation(spine)
	tree.update_climb(0.2,.86)
	if hanging_spine.angle_to(skeleton.get_bone_pose_rotation(spine)) < .30:
		push_error("ARJUN MOTION TREE: mantle press did not transfer torso over the edge")
		preload("res://tools/test_audio_cleanup.gd").finish(self,1)
		return
	tree.release_climb(0.2)
	tree.update_motion(0.1, 0.0, 0.0, false)
	if walk_rotation.angle_to(idle_rotation) < 0.01:
		push_error("ARJUN MOTION TREE: walk and idle poses did not differ")
		preload("res://tools/test_audio_cleanup.gd").finish(self,1)
		return
	for i in 12: tree.update_motion(0.1, 1.0, 0.0, false)
	if tree.foot_contact_offset <= 0.0 or tree.foot_contact_offset > 0.28:
		push_error("ARJUN MOTION TREE: foot contact correction outside bounds")
		preload("res://tools/test_audio_cleanup.gd").finish(self,1)
		return
	for i in 8: tree.update_motion(0.1, 1.75, 0.0, false)
	if tree.ground_blend < 1.65 or tree.playback_rate < 1.3 or tree.playback_rate > 1.5:
		push_error("ARJUN MOTION TREE: sprint did not reach its separate gait and cadence")
		preload("res://tools/test_audio_cleanup.gd").finish(self,1)
		return
	for i in 10: tree.update_motion(0.1, 0.0, 1.0, true)
	if tree.swim_blend < 0.9:
		push_error("ARJUN MOTION TREE: water blend did not engage")
		preload("res://tools/test_audio_cleanup.gd").finish(self,1)
		return
	for i in 10: tree.update_motion(0.1, 1.0, 0.0, false, false, 5.0)
	var rise_pose := skeleton.get_bone_pose_rotation(thigh)
	for i in 10: tree.update_motion(0.1, 1.0, 0.0, false, false, -5.0)
	if tree.air_blend < 0.99 or rise_pose.angle_to(skeleton.get_bone_pose_rotation(thigh)) < 0.1 or tree.foot_contact_offset > 0.01:
		push_error("ARJUN MOTION TREE: jump rise/fall or airborne ground correction failed")
		preload("res://tools/test_audio_cleanup.gd").finish(self,1)
		return
	for i in 10: tree.update_motion(0.1, 1.0, 1.0, true, false, 0.0)
	if tree.air_blend > 0.01:
		push_error("ARJUN MOTION TREE: swimming retained jump pose")
		preload("res://tools/test_audio_cleanup.gd").finish(self,1)
		return
	tree.update_rest(0.3, 1.0)
	if tree.rest_blend < 0.99 or not tree.get("parameters/rest/blend_amount") > 0.99:
		push_error("ARJUN MOTION TREE: seated clip did not engage")
		preload("res://tools/test_audio_cleanup.gd").finish(self,1)
		return
	var seated_pose := skeleton.get_bone_pose_rotation(thigh)
	tree.update_rest(0.1, 0.8, 0.15, false)
	var entering_pose := skeleton.get_bone_pose_rotation(thigh)
	if tree.get("parameters/sit_transition/blend_amount") > 0.01 or entering_pose.angle_to(seated_pose) < 0.01:
		push_error("ARJUN MOTION TREE: sit-down clip not sought")
		preload("res://tools/test_audio_cleanup.gd").finish(self,1)
		return
	tree.update_rest(0.1, 0.8, 0.15, true)
	if tree.get("parameters/sit_transition/blend_amount") < 0.99 or entering_pose.angle_to(skeleton.get_bone_pose_rotation(thigh)) < 0.01:
		push_error("ARJUN MOTION TREE: stand-up clip did not replace sit-down")
		preload("res://tools/test_audio_cleanup.gd").finish(self,1)
		return
	tree.update_longgun_motion(0.3, true, true, -1.0, 0.075)
	tree.update_rest(0.1, 0.0, 1.0)
	if tree.get("parameters/sleep/blend_amount") < 0.99:
		push_error("ARJUN MOTION TREE: sleeping branch did not engage")
		preload("res://tools/test_audio_cleanup.gd").finish(self,1)
		return
	var source: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	var lie_clip := source.get_animation("motion/lie_down")
	var wake_clip := source.get_animation("motion/rise_from_lie")
	var arm_path := NodePath("Arjun_Rig/Skeleton3D:upperarm_r")
	var lie_arm := lie_clip.find_track(arm_path, Animation.TYPE_ROTATION_3D)
	var wake_arm := wake_clip.find_track(arm_path, Animation.TYPE_ROTATION_3D)
	if lie_arm < 0 or wake_arm < 0 or lie_clip.get_track_count() < 12:
		push_error("ARJUN MOTION TREE: authored lie/wake tracks missing")
		preload("res://tools/test_audio_cleanup.gd").finish(self,1)
		return
	if lie_clip.rotation_track_interpolate(lie_arm, lie_clip.length * 0.5).angle_to(lie_clip.rotation_track_interpolate(lie_arm, lie_clip.length)) < 0.08:
		push_error("ARJUN MOTION TREE: lie transition lacks a distinct brace pose")
		preload("res://tools/test_audio_cleanup.gd").finish(self,1)
		return
	tree.update_rest(0.1, 0.5, 0.65, false)
	if tree.get("parameters/sleep_motion/blend_amount") > 0.01:
		push_error("ARJUN MOTION TREE: lie clip was not sought through the middle pose")
		preload("res://tools/test_audio_cleanup.gd").finish(self,1)
		return
	tree.update_rest(0.1, 0.5, 0.65, true)
	if tree.get("parameters/sleep_motion/blend_amount") < 0.99:
		push_error("ARJUN MOTION TREE: wake clip did not replace lie clip")
		preload("res://tools/test_audio_cleanup.gd").finish(self,1)
		return
	tree.update_longgun_motion(0.3, true, true, -1.0, 0.075)
	tree.rest_blend = 0.0
	tree.update_motion(0.1, 0.0, 0.0, false)
	if tree.get("parameters/sleep/blend_amount") > 0.01:
		push_error("ARJUN MOTION TREE: sleeping branch survived locomotion recovery")
		preload("res://tools/test_audio_cleanup.gd").finish(self,1)
		return
	if skeleton.get_bone_pose_rotation(head).angle_to(neutral_head) < 0.03:
		push_error("ARJUN MOTION TREE: long gun library pose did not move head")
		preload("res://tools/test_audio_cleanup.gd").finish(self,1)
		return
	if not tree.get("parameters/longgun_aim/blend_amount") > 0.9:
		push_error("ARJUN MOTION TREE: long gun aim library layer did not engage")
		preload("res://tools/test_audio_cleanup.gd").finish(self,1)
		return
	if tree.longgun_aim_blend < 0.9 or tree.longgun_recoil_blend < 0.9:
		push_error("ARJUN MOTION TREE: long gun aim/recoil blend did not engage")
		preload("res://tools/test_audio_cleanup.gd").finish(self,1)
		return
	tree.update_longgun_motion(0.3, true, false, 0.5, 0.0)
	if tree.longgun_reload_blend < 0.9 or tree.longgun_aim_blend > 0.1:
		push_error("ARJUN MOTION TREE: long gun reload did not release aim")
		preload("res://tools/test_audio_cleanup.gd").finish(self,1)
		return
	print("ARJUN MOTION TREE: PASS | idle, walk, run, swim, sit entry/exit and long gun envelopes")
	preload("res://tools/test_audio_cleanup.gd").finish(self)

func pair_reference(tree: AnimationTree, rig: Skeleton3D, bone: int, first: String, second: String, weight: float) -> Quaternion:
	# Compare the resulting rig to an independent engine blend of only the two
	# intended clips; engine quaternion mixing differs from a direct slerp.
	var graph := tree.tree_root as AnimationNodeBlendTree
	for pair in [{"name":"reference_a","clip":first},{"name":"reference_b","clip":second}]:
		var pose := AnimationNodeAnimation.new()
		pose.animation = "motion/climb_"+pair.clip
		graph.add_node(pair.name,pose)
	graph.add_node("reference_pair",AnimationNodeBlend2.new())
	graph.connect_node("reference_pair",0,"reference_a")
	graph.connect_node("reference_pair",1,"reference_b")
	graph.disconnect_node("climb_selector",0)
	graph.connect_node("climb_selector",0,"reference_pair")
	tree.set("parameters/climb_selector/blend_amount",0.0)
	tree.set("parameters/reference_pair/blend_amount",weight)
	tree.advance(0.0)
	var result := rig.get_bone_pose_rotation(bone)
	graph.disconnect_node("climb_selector",0)
	graph.connect_node("climb_selector",0,"climb_pose")
	for name in ["reference_pair","reference_a","reference_b"]: graph.remove_node(name)
	return result
