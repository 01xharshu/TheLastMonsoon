extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1280,720)
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.62,.69,.70)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(.75,.72,.65)
	environment.environment.ambient_light_energy = .65
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-35,0)
	sun.light_energy = 1.1
	stage.add_child(sun)
	var civic := Node3D.new()
	civic.set_script(load("res://world/suryagarh/settlements/civic_building.gd"))
	civic.name = "TownHall"
	civic.set("police",false)
	stage.add_child(civic)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.fov = 68
	for view in [
		["building_refinement_civic_exterior",Vector3(22,14,42),Vector3(0,5,0)],
		["building_refinement_civic_hall",Vector3(-6,2,8),Vector3(0,2,-7)]
	]:
		camera.position = civic.position + view[1]
		camera.look_at(civic.position + view[2])
		camera.current = true
		for i in 5: await process_frame
		RenderingServer.force_draw(false)
		var path: String = "res://docs/world/captures/" + str(view[0]) + ".png"
		root.get_texture().get_image().save_png(path)
		print("BUILDING REFINEMENT CAPTURE ",path)
	quit()
