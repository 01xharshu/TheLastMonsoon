extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	assert(not OS.get_environment("TLM_FORT_REVIEW_DIR").is_empty(), "Caller must supply and clean an OS temporary output directory")
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	world.get_node("Player").visible = false
	for layer in world.find_children("*", "CanvasLayer", true, false): layer.visible = false
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(520, 114, -255)
	camera.look_at(Vector3(520, 130, -385))
	camera.fov = 70
	camera.current = true
	for i in range(12): await process_frame
	var image := root.get_viewport().get_texture().get_image()
	var err := image.save_png(OS.get_environment("TLM_FORT_REVIEW_DIR").path_join("ruined_fort_entrance_world.png"))
	print("FORT IN WORLD CAPTURE ",err," ",image.get_size())
	quit()
