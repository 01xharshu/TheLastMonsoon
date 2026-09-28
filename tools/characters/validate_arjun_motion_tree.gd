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
		quit(1)
		return
	var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var thigh := skeleton.find_bone("thigh_l")
	tree.update_motion(0.3, 1.0, 0.0, false)
	var walk_rotation := skeleton.get_bone_pose_rotation(thigh)
	if tree.playback_rate <= 1.0:
		push_error("ARJUN MOTION TREE: walk cadence did not increase with travel speed")
		quit(1)
		return
	for i in 10: tree.update_motion(0.1, 0.0, 0.0, false)
	var idle_rotation := skeleton.get_bone_pose_rotation(thigh)
	var head := skeleton.find_bone("head")
	var neutral_head := skeleton.get_bone_pose_rotation(head)
	tree.update_climb(0.2, 0.35)
	if tree.climb_blend < 0.99 or absf(float(tree.get("parameters/climb_pose/blend_position")) - 0.35) > 0.01:
		push_error("ARJUN MOTION TREE: climb pull pose did not engage")
		quit(1)
		return
	tree.release_climb(0.2)
	tree.update_motion(0.1, 0.0, 0.0, false)
	if walk_rotation.angle_to(idle_rotation) < 0.01:
		push_error("ARJUN MOTION TREE: walk and idle poses did not differ")
		quit(1)
		return
	for i in 12: tree.update_motion(0.1, 1.0, 0.0, false)
	if tree.foot_contact_offset <= 0.0 or tree.foot_contact_offset > 0.28:
		push_error("ARJUN MOTION TREE: foot contact correction outside bounds")
		quit(1)
		return
	for i in 8: tree.update_motion(0.1, 1.75, 0.0, false)
	if tree.ground_blend < 1.65 or tree.playback_rate < 1.3 or tree.playback_rate > 1.5:
		push_error("ARJUN MOTION TREE: sprint did not reach its separate gait and cadence")
		quit(1)
		return
	for i in 10: tree.update_motion(0.1, 0.0, 1.0, true)
	if tree.swim_blend < 0.9:
		push_error("ARJUN MOTION TREE: water blend did not engage")
		quit(1)
		return
	tree.update_rest(0.3, 1.0)
	if tree.rest_blend < 0.99 or not tree.get("parameters/rest/blend_amount") > 0.99:
		push_error("ARJUN MOTION TREE: seated clip did not engage")
		quit(1)
		return
	tree.update_longgun_motion(0.3, true, true, -1.0, 0.075)
	tree.rest_blend = 0.0
	tree.update_motion(0.1, 0.0, 0.0, false)
	if skeleton.get_bone_pose_rotation(head).angle_to(neutral_head) < 0.03:
		push_error("ARJUN MOTION TREE: long gun library pose did not move head")
		quit(1)
		return
	if not tree.get("parameters/longgun_aim/blend_amount") > 0.9:
		push_error("ARJUN MOTION TREE: long gun aim library layer did not engage")
		quit(1)
		return
	if tree.longgun_aim_blend < 0.9 or tree.longgun_recoil_blend < 0.9:
		push_error("ARJUN MOTION TREE: long gun aim/recoil blend did not engage")
		quit(1)
		return
	tree.update_longgun_motion(0.3, true, false, 0.5, 0.0)
	if tree.longgun_reload_blend < 0.9 or tree.longgun_aim_blend > 0.1:
		push_error("ARJUN MOTION TREE: long gun reload did not release aim")
		quit(1)
		return
	print("ARJUN MOTION TREE: PASS | idle, walk, run, swim, sit and long gun envelopes")
	quit()
