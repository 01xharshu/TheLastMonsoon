extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var stage:=Node3D.new();root.add_child(stage);current_scene=stage
	root.size=Vector2i(1000,1000)
	root.content_scale_size=Vector2i(1000,1000)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(.48,.45,.39)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color=Color.WHITE
	environment.environment.ambient_light_energy=.35
	stage.add_child(environment)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-35,-25,0);light.light_energy=.95;stage.add_child(light)
	var camera:=Camera3D.new();camera.fov=42;stage.add_child(camera);camera.make_current()
	for role in ["daroga","mohurrir","burkundaz"]:
		var actor:=Node3D.new();actor.set_script(load("res://characters/npcs/thana/thana_officer.gd"))
		actor.add_child(load("res://characters/npcs/thana/%s_motion.glb"%role).instantiate());stage.add_child(actor)
		for frame in 8:await process_frame
		assert(actor.animation_tree!=null and actor._skeleton!=null)
		print("THANA REFERENCE RIG PASS ",role)
		for view in ["front","side"]:
			camera.position=Vector3(.35,1.05,2.8) if view=="front" else Vector3(2.5,1.05,1.0)
			camera.look_at(Vector3(0,.85,0))
			for frame in 2:await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/characters/npcs/thana_reference_%s_%s.png"%[role,view])
		actor.queue_free();await process_frame
	print("THANA REFERENCE ISOLATED METAL REVIEW COMPLETE")
	stage.queue_free();await process_frame;quit()
