extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	await process_frame
	root.get_node("SaveManager").pending_slot = 0
	root.get_node("SaveManager").apply_pending(world)
	var opening = world.get_node("OpeningSequence")
	opening.set_process(false)
	opening.set_process_input(false)
	for t in [14.0,16.0,19.0]:
		opening.elapsed = t
		opening._process(0.0)
		await create_timer(0.3).timeout
		if t == 16.0:
			for distance in [20.0,40.0,80.0]:
				var start: Vector2 = opening.home.get_meta("brother_approach_start")
				var end: Vector2 = opening.home.get_meta("brother_approach_end")
				var p := start.move_toward(end,distance)
				var target := Vector3(p.x,world.layout.height(p.x,p.y)+1.0,p.y)
				var query := PhysicsRayQueryParameters3D.create(opening.camera.global_position,target)
				query.exclude = [world.player.get_rid()]
				var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
				assert(hit.is_empty(),"Blocked approach sightline at %s metres: %s" % [distance,hit])
			print("APPROACH SIGHTLINES: PASS | 20/40/80 m")
		assert(opening.state == "night", "Capture unexpectedly left the night sequence")
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/world/captures/opening_approach_%02d.png" % int(t))
	print("OPENING APPROACH CAPTURE COMPLETE")
	quit()
