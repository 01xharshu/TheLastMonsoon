extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	var world := load("res://world/suryagarh/suryagarh_world.tscn").instantiate() as Node3D
	root.add_child(world)
	current_scene = world
	world.get_node("Player").hide()
	world.get_node("Player/UI").hide()
	world.get_node("LandscapeUI").hide()
	var roster := world.get_node("BritishNpcRosterCandidate")
	for actor in roster.get_children():
		actor.set_process(false)
		var player: AnimationPlayer = actor.get("animation_player")
		player.pause()
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 30.0
	camera.make_current()
	for actor_name in ["PrivateMan", "PrivateWoman"]:
		var actor := roster.get_node(actor_name) as Node3D
		actor.rotation.y = 0.0
		camera.global_position = actor.global_position + Vector3(5.5,1.8,0)
		camera.look_at(actor.global_position + Vector3(0,0.9,0))
		var tree: AnimationTree = actor.get("animation_tree")
		for amount in [0.0, 0.5, 1.0]:
			tree.set("parameters/locomotion/blend_position", amount)
			tree.advance(0.21)
			for i in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			var path: String = "res://docs/characters/british/candidates/" + actor_name.to_snake_case() + "_tree_side_" + str(int(amount*100)) + ".png"
			print("BRITISH_TREE_CAPTURE ",path," ",root.get_texture().get_image().save_png(path))
	quit(0)
