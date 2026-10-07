extends SceneTree
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var scene := load("res://characters/npcs/indian/purpose_npc_review.tscn").instantiate() as Node3D
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280,720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(scene)
	var camera := scene.get_node("Camera") as Camera3D
	var roles := ["dock_porter", "boatman", "record_clerk"]
	for role in roles:
		scene.get_node(role).set_process(false)
		scene.get_node(role).hide()
		scene.get_node(role + "Label").hide()
	var requested := OS.get_cmdline_user_args()
	var capture_roles: PackedStringArray = PackedStringArray(["boatman"]) if requested.is_empty() else requested
	for role in capture_roles:
		var actor := scene.get_node(role) as Node3D
		actor.position = Vector3.ZERO
		actor.show()
		actor.set("walking", false)
		actor.call("step_motion", .2)
		var stride: float = {"dock_porter": .40, "boatman": .44, "record_clerk": .28}[role]
		var folder: String = "/tmp/tlm_purpose_transition_" + role
		DirAccess.make_dir_recursive_absolute(folder)
		for frame in 180:
			actor.set("walking", frame >= 30 and frame < 135)
			actor.position.z += stride / .72 / 30.0 * float(actor.get("locomotion_blend"))
			actor.call("step_motion", 1.0 / 30.0)
			camera.global_position = actor.global_position + Vector3(2.5, 1.35, 1.3)
			camera.fov = 42
			camera.look_at(actor.global_position + Vector3(0, .78, 0))
			await process_frame
			RenderingServer.force_draw(false)
			var error := viewport.get_texture().get_image().save_png(folder + "/%04d.png" % frame)
			if error != OK:
				quit(1)
				return
		actor.hide()
		print("PURPOSE_TRANSITION_CAPTURE ", role, " 180 frames at 30 Hz; idle, acceleration, walk, stop and idle flat-floor study")
	quit()
