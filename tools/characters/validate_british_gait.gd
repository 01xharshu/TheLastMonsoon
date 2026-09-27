extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var roster := Node3D.new()
	roster.set_script(load("res://world/suryagarh/british_npc_roster.gd"))
	root.add_child(roster)
	await process_frame
	var errors: Array[String] = []
	var measurements: Array = []
	for actor in roster.get_children():
		actor.set_process(false)
		var tree: AnimationTree = actor.get("animation_tree")
		tree.set("parameters/locomotion/blend_position", 1.0)
		var skeleton := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var foot := skeleton.find_bone("foot_l")
		var minimum := Vector3(INF, INF, INF)
		var maximum := Vector3(-INF, -INF, -INF)
		var clip: Animation = (actor.get("animation_player") as AnimationPlayer).get_animation("walk")
		for sample in 65:
			tree.advance(clip.length / 64.0)
			var position := skeleton.get_bone_global_pose(foot).origin
			minimum = minimum.min(position)
			maximum = maximum.max(position)
		var span := maximum - minimum
		if span.z < 0.08 or span.x > 0.04:
			errors.append(str(actor.name) + ": forward swing/lateral drift failed")
		measurements.append({"actor":str(actor.name),"forward_swing_m":span.z,"lateral_drift_m":span.x,"vertical_span_m":span.y})
	var report := {"passed":errors.is_empty() and measurements.size()==16,"actors":measurements,"errors":errors,"scope":"65 samples through actual tree evaluation per actor; skeleton ankle path, not mesh sole contact or foot locking"}
	FileAccess.open("res://docs/characters/british/candidates/gait_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("BRITISH_GAIT ",JSON.stringify(report))
	quit(0 if report.passed else 1)
