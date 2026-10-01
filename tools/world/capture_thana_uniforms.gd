extends "res://tools/world/validate_police_arrest.gd"
func run() -> void:
	world=load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene=world
	actor=world.get_node("Player")
	actor.get_node("UI").hide()
	world.get_node("LandscapeUI").hide()
	police=world.get_node("Settlement/DistrictPolice")
	root.size=Vector2i(1280,720)
	root.content_scale_size=root.size
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	camera=Camera3D.new();camera.fov=62;world.add_child(camera);camera.make_current()
	for frame in 15:await physics_frame
	for role in ["Daroga","Mohurrir","Burkundaz"]:
		var person: Node3D=police.get_node("ThanaStaff/"+role)
		for offset in [police.global_basis.inverse()*person.global_basis*Vector3(.6,1.05,1.45),Vector3(1.4,1.15,1.4),Vector3(-1.4,1.15,1.4),Vector3(1.4,1.15,-1.4),Vector3(-1.4,1.15,-1.4),Vector3(0,1.15,1.0)]:
			var at: Vector3=person.global_position+police.global_basis*offset
			var ray:=PhysicsRayQueryParameters3D.create(at,person.global_position+Vector3.UP*.9,1)
			ray.exclude=[person.body_collider.get_rid()]
			if person.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():camera.global_position=at;break
		camera.look_at(person.global_position+Vector3.UP*.88)
		for frame in 3:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/characters/npcs/thana_%s_uniform.png"%role.to_lower())
	print("THANA UNIFORM METAL CAPTURE COMPLETE")
	quit()
