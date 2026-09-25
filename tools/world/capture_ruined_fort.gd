extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var scene: Node3D = load("res://world/ruined_fort/ruined_fort.tscn").instantiate()
	root.add_child(scene)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(95,125,115)
	camera.look_at(Vector3(0,4,-6))
	camera.fov = 62
	camera.current = true
	for i in range(8): await process_frame
	var image := root.get_viewport().get_texture().get_image()
	var err := image.save_png("res://docs/world/captures/ruined_fort_blockout.png")
	print("FORT CAPTURE ",err," ",image.get_size())
	quit()
