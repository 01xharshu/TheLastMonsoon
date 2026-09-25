extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	world.get_node("Player").visible = false
	for layer in world.find_children("*", "CanvasLayer", true, false): layer.visible = false
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(630, 185, -230)
	camera.look_at(Vector3(520, 122, -350))
	camera.fov = 64
	camera.current = true
	for i in range(12): await process_frame
	var image := root.get_viewport().get_texture().get_image()
	var err := image.save_png("res://docs/world/captures/ruined_fort_in_world.png")
	print("FORT IN WORLD CAPTURE ",err," ",image.get_size())
	quit()
