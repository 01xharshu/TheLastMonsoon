extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var building := world.get_node("Settlement/DistrictPolice") as Node3D
	var staff := building.get_node("ThanaStaff")
	var expected := ["Daroga", "Mohurrir", "Burkundaz"]
	for role in expected:
		var actor := staff.get_node(role) as Node3D
		assert(actor != null)
		assert(actor.get_meta("station_bound", false))
		assert(absf(actor.position.x) < 12.0 and absf(actor.position.z) < 11.0)
		assert(actor.animation_tree != null)
		assert(actor._skeleton != null)
		assert(actor.get_child(0).get_child_count() > 0)
		assert(actor.body_collider is AnimatableBody3D)
		print("THANA_STAFF_PASS ", role, " ", actor.global_position)
	world.queue_free()
	await process_frame
	quit()
