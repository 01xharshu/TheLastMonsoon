extends SceneTree
## Disposable target-renderer views. Caller owns and removes the OS temporary folder.
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var folder := OS.get_environment("TLM_FORT_REVIEW_DIR")
	assert(not folder.is_empty() and not folder.begins_with(ProjectSettings.globalize_path("res://")),"Use an OS temporary output directory")
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	DisplayServer.window_set_size(Vector2i(1280,720))
	var main_world: bool = OS.get_cmdline_user_args().has("--main-world")
	var scene: Node3D = load("res://world/suryagarh/suryagarh_world.tscn" if main_world else "res://world/ruined_fort/ruined_fort.tscn").instantiate()
	root.add_child(scene)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.size = Vector2i(1280,720)
	var fort: Node3D = scene.get_node("OldFort") if main_world else scene
	for layer in scene.find_children("*","CanvasLayer",true,false): layer.visible = false
	var actor: CharacterBody3D = scene.get_node("Player") if main_world else fort.get_node("Gameplay/Player")
	actor.global_position = fort.to_global(Vector3(0,fort.height_at(0,48)+.94,48))
	actor.visible = false
	var camera := Camera3D.new()
	camera.fov = 65
	fort.add_child(camera)
	camera.make_current()
	var views := [
		{"id":"overview","eye":Vector3(80,55,88),"target":Vector3(0,3,-3)},
		{"id":"approach","eye":Vector3(8,2.5,49),"target":Vector3(0,4,15)},
		{"id":"central","eye":Vector3(4,5.3,14),"target":Vector3(-8,5,-8)}]
	for view in views:
		camera.position = view.eye
		camera.look_at(fort.to_global(view.target))
		for frame in range(8): await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(folder.path_join(view.id+".png")) == OK)
	var encounter := fort.get_node("Gameplay/FortEncounter")
	encounter.set_physics_process(false)
	if encounter.guards.is_empty(): encounter.player = actor; encounter.activate()
	var guard: Dictionary = encounter.guards[0]
	var npc: Node3D = guard.actor
	npc.global_position = fort.to_global(Vector3(0,fort.height_at(0,42),42))
	var gun: Node3D = guard.weapon
	gun.set_process(true)
	gun.hostile = true
	gun.moving = false
	camera.global_position = npc.global_position+Vector3(-3,1.7,2)
	camera.look_at(npc.global_position+Vector3.UP*1.3)
	for frame in range(60):
		npc.travel_speed = 0
		await process_frame
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(folder.path_join("guard.png")) == OK)
	print("FORT RENDER REVIEW READY | ","main world" if main_world else "standalone"," | masonry instances=",fort.get_node("Architecture/ModularChippedMasonry").multimesh.instance_count)
	scene.queue_free()
	await process_frame
	quit()
