extends SceneTree
## Focused native-renderer view of the landing and the first fish school.
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	var boat: Node3D = world.get_node("RiverBoat")
	world.get_node("Player/UI").hide()
	world.get_node("LandscapeUI").hide()
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 55.0
	camera.global_position = boat.global_position + Vector3(-7, 5, 6)
	camera.look_at(boat.global_position + Vector3(2, -.5, 0))
	camera.make_current()
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png("res://docs/world/captures/river_refinement_2026-09-28.png")
	print("RIVER REFINEMENT CAPTURE ", result)
	quit(0 if result == OK else 1)
