extends SceneTree
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var actors: Array[Node3D] = []
	var errors: Array[String] = []
	var trees := {}
	var graphs := {}
	for slug in ["village_farmer", "village_woman", "village_fruit_seller", "village_weaver_assistant"]:
		var actor := Node3D.new()
		actor.set_script(load("res://characters/npcs/indian/indian_npc_candidate.gd"))
		actor.set("candidate_slug", slug)
		root.add_child(actor)
		actor.set_process(false)
		actors.append(actor)
		var tree: AnimationTree = actor.get("animation_tree")
		if tree == null:
			errors.append(slug + ": tree missing")
			continue
		trees[tree.get_instance_id()] = true
		graphs[tree.tree_root.get_instance_id()] = true
		var skeleton := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var bone := skeleton.find_bone("thigh_l")
		var idle := skeleton.get_bone_pose_rotation(bone)
		actor.set("walking", true)
		actor.call("step_motion", 0.1)
		if not is_equal_approx(actor.get("locomotion_blend"), 0.5): errors.append(slug + ": half blend failed")
		actor.call("step_motion", 0.1)
		if not is_equal_approx(actor.get("locomotion_blend"), 1.0): errors.append(slug + ": full blend failed")
		var before := skeleton.get_bone_pose_rotation(bone)
		actor.call("step_motion", 0.15)
		if absf(before.dot(skeleton.get_bone_pose_rotation(bone))) > 0.99999: errors.append(slug + ": thigh did not move")
		# Advance through multiple loops to exercise continuous evaluation.
		for frame in 180: actor.call("step_motion", 1.0 / 30.0)
		actor.set("walking", false)
		actor.call("step_motion", 0.1)
		if not is_equal_approx(actor.get("locomotion_blend"), 0.5): errors.append(slug + ": stop blend failed")
		actor.call("step_motion", 0.1)
		if not is_zero_approx(actor.get("locomotion_blend")) or absf(idle.dot(skeleton.get_bone_pose_rotation(bone))) < 0.99999: errors.append(slug + ": idle recovery failed")
	actors[2].set("walking", true)
	actors[2].call("step_motion", 0.2)
	if not is_zero_approx(actors[3].get("locomotion_blend")) or not is_equal_approx(actors[2].get("locomotion_blend"), 1.0): errors.append("Independent stop failed")
	var report := {"passed": errors.is_empty() and trees.size() == 4 and graphs.size() == 4, "personal_trees": trees.size(), "personal_graphs": graphs.size(), "errors": errors, "scope": "candidate blending, skeleton motion, looping and independent stop; no cloth/contact approval"}
	FileAccess.open("res://docs/characters/npcs/animation_tree_validation.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  ") + "\n")
	print("INDIAN_TREE ", JSON.stringify(report))
	quit(0 if report.passed else 1)
