extends SceneTree
## Focused Forward+/Metal evidence for the authored compound wall climb.

func _initialize() -> void:
	_run.call_deferred()

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "/tmp/tlm_tall_climb_" + label + ".png"
	print("CLIMB CAPTURE ", label, " ", root.get_texture().get_image().save_png(path), " ", path)

func _run() -> void:
	var world := preload("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 5: await physics_frame
	var actor: CharacterBody3D = world.get_node("Player")
	if actor.get_script() == null:
		push_error("TALL CLIMB CAPTURE: Player script did not load")
		quit(1)
		return
	actor.set_physics_process(false)
	actor.get_node("UI").hide()
	world.get_node("LandscapeUI").hide()
	actor.global_position = Vector3(291.3,12.95,300)
	actor.visual_root.global_rotation.y = PI/2
	var camera := Camera3D.new()
	camera.fov = 45.0
	world.add_child(camera)
	camera.make_current()
	camera.global_position = Vector3(288.0,15.8,303.4)
	camera.look_at(Vector3(292.3,15.2,300))
	for i in 3: await physics_frame
	var climb: Node = actor.get_node("ClimbComponent")
	if not climb.try_start():
		push_error("TALL CLIMB CAPTURE: start failed")
		quit(1)
		return
	for beat in [{"name":"reach","frame":18},{"name":"pull","frame":48},{"name":"mantle","frame":99},{"name":"recover","frame":130}]:
		while climb.active and climb.progress < float(beat.frame) / 144.0:
			await physics_frame
		await _capture(beat.name)
	quit()
