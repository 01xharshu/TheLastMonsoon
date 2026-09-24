extends SceneTree
## Structural and motion check for the British NPC study roster.

const OUTPUT := "res://docs/characters/british/candidates/roster_runtime_validation.json"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var script := load("res://world/suryagarh/british_npc_roster.gd")
	var roster := Node3D.new()
	roster.name = "BritishNpcRosterCandidate"
	roster.set_script(script)
	root.add_child(roster)
	await create_timer(0.25).timeout
	var actors: Array[Node] = roster.get_children()
	var first_positions: Dictionary = {}
	var skeleton_count := 0
	var missing_bones: Array[String] = []
	for actor in actors:
		first_positions[actor.name] = (actor as Node3D).position
		var skeletons := actor.find_children("*", "Skeleton3D", true, false)
		skeleton_count += skeletons.size()
		if skeletons.size() != 1:
			missing_bones.append(actor.name + ": skeleton count " + str(skeletons.size()))
		else:
			var skeleton := skeletons[0] as Skeleton3D
			for bone_name in ["pelvis", "spine_02", "head", "upperarm_l", "upperarm_r", "thigh_l", "thigh_r", "calf_l", "calf_r"]:
				if skeleton.find_bone(bone_name) < 0:
					missing_bones.append(actor.name + ": " + bone_name)
	await create_timer(1.0).timeout
	var moved := 0
	var walking := 0
	var posed := 0
	for actor in actors:
		if (actor as Node3D).position.distance_to(first_positions[actor.name]) > 0.02:
			moved += 1
		if actor.get("animation_state") == &"walk":
			walking += 1
		var skeletons := actor.find_children("*", "Skeleton3D", true, false)
		if not skeletons.is_empty():
			var skeleton := skeletons[0] as Skeleton3D
			var bone := skeleton.find_bone("thigh_l")
			if bone >= 0 and absf(skeleton.get_bone_pose_rotation(bone).w) < 0.99999:
				posed += 1
	var passed := actors.size() == 16 and skeleton_count == 16 and missing_bones.is_empty() and moved > 0 and walking > 0 and posed > 0
	var report := {"passed": passed, "actors": actors.size(), "skeletons": skeleton_count, "missing_bones": missing_bones, "moved_after_one_second": moved, "walking_after_one_second": walking, "thigh_pose_changed": posed, "scope": "isolated roster; full-world rendering and foot contact are separate"}
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	print("BRITISH_ROSTER_VALIDATION ", JSON.stringify(report))
	quit(0 if passed else 1)
