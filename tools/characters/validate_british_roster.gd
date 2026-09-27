extends SceneTree
const OUTPUT := "res://docs/characters/british/candidates/roster_runtime_validation.json"
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var roster := Node3D.new()
	roster.set_script(load("res://world/suryagarh/british_npc_roster.gd"))
	root.add_child(roster)
	await process_frame
	var actors := roster.get_children()
	var errors: Array[String] = []
	var players: Dictionary = {}
	var animated := 0
	var profiles: Dictionary = {"male":0,"female":0}
	for actor in actors:
		actor.set_process(false)
		actor.set("_clock", 0.0)
		var player: AnimationPlayer = actor.get("animation_player")
		if player == null or not player.has_animation("walk") or not player.has_animation("idle"):
			errors.append(actor.name + ": missing personal idle/walk clips")
			continue
		players[player.get_instance_id()] = true
		var profile := str(actor.get("movement_profile"))
		profiles[profile] += 1
		actor.call("_process", 0.25)
		player.advance(0.1)
		var skeleton := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var index := skeleton.find_bone("thigh_l")
		var before := skeleton.get_bone_pose_rotation(index)
		player.advance(0.2)
		var after := skeleton.get_bone_pose_rotation(index)
		if absf(before.dot(after)) < 0.99999:
			animated += 1
		else:
			errors.append(actor.name + ": walking track did not change thigh pose")
	var frozen := actors[0] as Node3D
	var other := actors[1] as Node3D
	frozen.set("movement_enabled", false)
	var frozen_before := frozen.position
	var other_before := other.position
	frozen.call("_process", 0.5)
	other.call("_process", 0.5)
	var independent := frozen.position.is_equal_approx(frozen_before) and other.position.distance_to(other_before) > 0.02
	if not independent:
		errors.append("Freezing one actor affected independent movement")
	var passed := actors.size() == 16 and players.size() == 16 and animated == 16 and independent and errors.is_empty()
	var report := {"passed":passed,"actors":actors.size(),"personal_animation_players":players.size(),"walk_tracks_changed_pose":animated,"profiles":profiles,"independent_stop_test":independent,"errors":errors,"scope":"actual AnimationPlayer playback and independent movement; foot contact remains visual review"}
	FileAccess.open(OUTPUT, FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("BRITISH_ROSTER_VALIDATION ",JSON.stringify(report))
	quit(0 if passed else 1)
