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
		(actor.get("animation_tree") as AnimationTree).active = false
		var player: AnimationPlayer = actor.get("animation_player")
		player.pause()
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 30.0
	camera.make_current()
	for actor_node in roster.get_children():
		var actor := actor_node as Node3D
		var actor_name := str(actor.name)
		actor.rotation.y = 0.0
		var player: AnimationPlayer = actor.get("animation_player")
		camera.global_position = actor.global_position + Vector3(0,1.8,5.5)
		camera.look_at(actor.global_position + Vector3(0,0.9,0))
		for phase in [0.0,0.25,0.5,0.75]:
			player.play("walk")
			player.seek(float(phase)*player.get_animation("walk").length,true)
			player.pause()
			for i in 4:
				await process_frame
			await RenderingServer.frame_post_draw
			var path: String = "res://docs/characters/british/candidates/"+actor_name.to_snake_case()+"_walk_"+str(int(phase*100)).pad_zeros(2)+".png"
			var err := root.get_texture().get_image().save_png(path)
			print("BRITISH_INDEPENDENT_CAPTURE ",path," ",err)
	quit(0)
