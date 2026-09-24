extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene: PackedScene = load("res://world/suryagarh/suryagarh_world.tscn")
	var world: Node3D = scene.instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	await process_frame
	var layout = load("res://world/suryagarh/landscape_layout.gd").new()
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 68
	camera.far = 650
	var views := [
		["forest_approach", Vector3(620, layout.height(620,-125)+2.2,-125), Vector3(620,76,-150)],
		["cave_entrance", Vector3(620, layout.height(620,-141)+2.1,-141), Vector3(622,78,-178)],
		["idol_chamber", Vector3(637,79,-201), Vector3(646,81,-220)]
	]
	for view in views:
		camera.position = view[1]
		camera.look_at(view[2])
		camera.current = true
		for i in 5: await process_frame
		var image := root.get_viewport().get_texture().get_image()
		image.save_png("res://docs/world/captures/" + view[0] + ".png")
		print("CAPTURE ", view[0])
	quit()
