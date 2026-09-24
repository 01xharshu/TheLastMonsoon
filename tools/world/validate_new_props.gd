extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 6:
		await process_frame
	var settlement: Node3D = world.get_node("Settlement")
	var cannon: StaticBody3D = settlement.get_node("CompanyCourtyardCannon")
	var sign: StaticBody3D = settlement.get_node("SuryagarhRoadSign")
	var packet: Node3D
	for node in settlement.find_children("*", "Node3D", true, false):
		if node.name == "enfield_ammo_packet":
			packet = node
	if cannon.get_child_count() < 2 or sign.get_child_count() < 2 or packet == null:
		push_error("One or more new prop instances or colliders are missing")
		quit(1)
		return
	print("NEW PROPS STRUCTURAL PASS: cannon ", cannon.global_position, " sign ", sign.global_position, " ammo ", packet.global_position)
	if DisplayServer.get_name() != "headless":
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.fov = 58
		var views := [
			["new_cannon", cannon.global_position + Vector3(7,3,-8), cannon.global_position + Vector3(0,1,0)],
			["new_signboard", sign.global_position + Vector3(4,2.2,-5), sign.global_position + Vector3(0,1.25,0)],
			["new_ammo", packet.global_position + Vector3(.5,.35,.5), packet.global_position]
		]
		for view in views:
			camera.global_position = view[1]
			camera.look_at(view[2])
			camera.current = true
			for i in 8:
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png("res://docs/world/captures/" + view[0] + ".png")
			print("NEW PROP CAPTURE ", view[0])
	quit()
