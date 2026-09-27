extends SceneTree
const OUTPUT := "res://docs/characters/british/candidates/animation_tree_validation.json"
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var roster := Node3D.new()
	roster.set_script(load("res://world/suryagarh/british_npc_roster.gd"))
	root.add_child(roster)
	await process_frame
	var errors: Array[String] = []
	var trees: Dictionary = {}
	var graphs: Dictionary = {}
	var moving := 0
	var transitions := 0
	for actor in roster.get_children():
		actor.set_process(false)
		actor.set("foot_plant_enabled", false)
		actor.set("_clock", 0.0)
		var tree: AnimationTree = actor.get("animation_tree")
		if tree == null or not tree.active:
			errors.append(str(actor.name) + ": missing active tree")
			continue
		trees[tree.get_instance_id()] = true
		graphs[tree.tree_root.get_instance_id()] = true
		var skeleton := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var thigh := skeleton.find_bone("thigh_l")
		actor.set("movement_enabled", false)
		actor.call("_process", 0.2)
		var idle := skeleton.get_bone_pose_rotation(thigh)
		actor.set("movement_enabled", true)
		actor.call("_process", 0.1)
		var half: float = actor.get("locomotion_blend")
		actor.call("_process", 0.1)
		var full: float = actor.get("locomotion_blend")
		var before := skeleton.get_bone_pose_rotation(thigh)
		actor.call("_process", 0.15)
		if absf(before.dot(skeleton.get_bone_pose_rotation(thigh))) < 0.99999:
			moving += 1
		else:
			errors.append(str(actor.name) + ": tree did not animate thigh")
		actor.set("movement_enabled", false)
		actor.call("_process", 0.1)
		var stopping: float = actor.get("locomotion_blend")
		actor.call("_process", 0.1)
		var stopped: float = actor.get("locomotion_blend")
		if is_equal_approx(half,0.5) and is_equal_approx(full,1.0) and is_equal_approx(stopping,0.5) and is_zero_approx(stopped) and absf(idle.dot(skeleton.get_bone_pose_rotation(thigh))) > 0.99999:
			transitions += 1
		else:
			errors.append(str(actor.name) + ": start/stop blend or idle recovery failed")
	var first := roster.get_child(0) as Node3D
	var second := roster.get_child(1) as Node3D
	var fixed_position := first.position
	second.set("movement_enabled", true)
	second.call("_process", 0.2)
	first.call("_process", 0.2)
	var independent := first.position.is_equal_approx(fixed_position) and is_zero_approx(float(first.get("locomotion_blend"))) and is_equal_approx(float(second.get("locomotion_blend")),1.0)
	if not independent: errors.append("Trees do not stop independently")
	var passed := trees.size()==16 and graphs.size()==16 and moving==16 and transitions==16 and independent and errors.is_empty()
	var report := {"passed":passed,"personal_trees":trees.size(),"personal_graphs":graphs.size(),"animated_skeletons":moving,"start_stop_idle_recovery":transitions,"independent_stop":independent,"errors":errors,"scope":"actual tree evaluation and pose changes; cloth and foot contact unapproved"}
	FileAccess.open(OUTPUT,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("BRITISH_ANIMATION_TREE ",JSON.stringify(report))
	quit(0 if passed else 1)
