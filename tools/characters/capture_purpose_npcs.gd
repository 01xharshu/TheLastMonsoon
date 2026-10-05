extends SceneTree
## Isolated target-renderer review; no live-world/contact approval.
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var scene := load("res://characters/npcs/indian/purpose_npc_review.tscn").instantiate() as Node3D
	root.add_child(scene)
	current_scene = scene
	var actors: Array[Node3D] = []
	for role in ["dock_porter", "boatman", "record_clerk"]:
		var actor := scene.get_node(role) as Node3D
		actor.set_process(false)
		actors.append(actor)
	var failed := false
	for view in ["idle", "walk", "stopped"]:
		for index in actors.size():
			var actor := actors[index]
			actor.set("walking", view == "walk" or (view == "stopped" and index != 0))
			for frame in 18:
				actor.call("step_motion", 1.0 / 30.0)
		await process_frame
		RenderingServer.force_draw(false)
		var path := "res://docs/characters/npcs/purpose_%s.png" % view
		var error := root.get_texture().get_image().save_png(path)
		print("PURPOSE_NPC_CAPTURE ", error, " ", path)
		failed = failed or error != OK
	var camera := scene.get_node("Camera") as Camera3D
	for actor in actors:
		actor.set("walking", false)
		actor.call("step_motion", .2)
		var skeleton := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var head := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("head")).origin
		var aim := head + Vector3(0, .07, 0)
		camera.global_position = aim + Vector3(0, .015, 1.0)
		camera.fov = 26
		camera.look_at(aim)
		await process_frame
		RenderingServer.force_draw(false)
		var error := root.get_texture().get_image().save_png("res://docs/characters/npcs/purpose_%s_face.png" % actor.name)
		failed = failed or error != OK
	quit(1 if failed else 0)
