extends Node3D
## Launch as a scene so project autoloads initialize before world scripts.

func _ready() -> void:
	get_window().size = Vector2i(960, 540)
	_run.call_deferred()

func _run() -> void:
	var world := preload("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	add_child(world)
	for i in 5: await get_tree().physics_frame
	var actor: CharacterBody3D = world.get_node("Player")
	get_window().mode = Window.MODE_WINDOWED
	DisplayServer.window_set_size(Vector2i(960,540))
	if actor.get_script() == null:
		push_error("TALL CLIMB CAPTURE: Player script did not load")
		get_tree().quit(1)
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
	for i in 3: await get_tree().physics_frame
	var climb: Node = actor.get_node("ClimbComponent")
	if not climb.try_start():
		push_error("TALL CLIMB CAPTURE: start failed")
		get_tree().quit(1)
		return
	climb.set_physics_process(false)
	for beat in [{"name":"reach","at":.12},{"name":"pull_left","at":.30},{"name":"pull_right","at":.56},{"name":"mantle","at":.80},{"name":"mantle_step","at":.87},{"name":"recover","at":.95}]:
		climb.progress = beat.at
		climb._physics_process(0.0)
		camera.global_position = actor.global_position + Vector3(-4.0,1.5,3.4)
		camera.look_at(actor.global_position + Vector3.UP*.15)
		for i in 3: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path: String = "/tmp/tlm_tall_climb_" + str(beat.name) + ".png"
		print("CLIMB CAPTURE ", beat.name, " ", get_viewport().get_texture().get_image().save_png(path), " ", path)
	get_tree().quit()
