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
	for i in 10: tree.update_motion(0.1, 0.0, 0.0, false)
	var idle_rotation := skeleton.get_bone_pose_rotation(thigh)
	if walk_rotation.angle_to(idle_rotation) < 0.01:
		push_error("ARJUN MOTION TREE: walk and idle poses did not differ")
		quit(1)
		return
	for i in 10: tree.update_motion(0.1, 0.0, 1.0, true)
	if tree.swim_blend < 0.9:
		push_error("ARJUN MOTION TREE: water blend did not engage")
		quit(1)
		return
	print("ARJUN MOTION TREE: PASS | idle, walk, swim blends and in-place root")
	quit()
