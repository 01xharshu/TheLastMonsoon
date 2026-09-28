extends SceneTree
## Player-sized sweep against every British preview actor's physical body.

const OUTPUT := "res://docs/characters/british/candidates/body_collision_validation.json"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var roster := Node3D.new()
	roster.set_script(load("res://world/suryagarh/british_npc_roster.gd"))
	root.add_child(roster)
	await physics_frame
	var errors: Array[String] = []
	var stopped := 0
	var shapes := 0
	for actor in roster.get_children():
		actor.set_process(false)
		var collider := actor.get_node_or_null("BodyCollider") as AnimatableBody3D
		var shape_node := actor.get_node_or_null("BodyCollider/BodyShape") as CollisionShape3D
		if collider == null or shape_node == null or not (shape_node.shape is CapsuleShape3D):
			errors.append(str(actor.name) + ": missing capsule")
			continue
		shapes += 1
		if collider.collision_layer & 1 == 0:
			errors.append(str(actor.name) + ": not on player collision layer")
		var probe := CharacterBody3D.new()
		probe.name = "PlayerSizedProbe"
		probe.collision_mask = 1
		var probe_shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.4
		capsule.height = 1.8
		probe_shape.shape = capsule
		probe_shape.position.y = 0.9
		probe.add_child(probe_shape)
		root.add_child(probe)
		probe.global_position = (actor as Node3D).global_position + Vector3(0, 0, -1.45)
		await physics_frame
		var hit := probe.move_and_collide(Vector3(0, 0, 2.9))
		if hit != null and hit.get_collider() == collider and hit.get_travel().length() < 1.45:
			stopped += 1
		else:
			errors.append(str(actor.name) + ": sweep hit=" + (str(hit.get_collider().get_path()) if hit != null else "none") + " travel=" + (str(hit.get_travel().length()) if hit != null else "2.9") + " actor=" + str((actor as Node3D).global_position) + " collider=" + str(collider.global_position))
		probe.queue_free()
		await physics_frame
	var passed := roster.get_child_count() == 16 and shapes == 16 and stopped == 16 and errors.is_empty()
	var report := {"passed": passed, "actors": roster.get_child_count(), "capsules": shapes, "player_sweeps_stopped": stopped, "errors": errors, "scope": "isolated player-sized physical sweeps; live route and clothing contact separate"}
	FileAccess.open(OUTPUT, FileAccess.WRITE).store_string(JSON.stringify(report, "  ") + "\n")
	print("BRITISH_BODY_COLLISION ", JSON.stringify(report))
	quit(0 if passed else 1)
