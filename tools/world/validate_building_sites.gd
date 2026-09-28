extends SceneTree

const Layout = preload("res://world/suryagarh/landscape_layout.gd")
var layout := Layout.new()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280,720)
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	stage.add_child(load("res://world/suryagarh/generated/landscape.scn").instantiate())
	var buildings := Node3D.new()
	buildings.set_script(load("res://world/suryagarh/settlements/settlement_builder.gd"))
	buildings.name = "Settlement"
	stage.add_child(buildings)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(.61,.69,.70)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(.72,.72,.69)
	environment.environment.ambient_light_energy = .8
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45,-35,0)
	sun.light_energy = 1.0
	stage.add_child(sun)
	var expected := {
		"TownHall": Layout.PLOTS["TownHall"].center,
		"DistrictPolice": Layout.PLOTS["DistrictPolice"].center,
		"GovernmentHouse": Layout.PLOTS["GovernmentHouse"].center,
	}
	for name in expected:
		var node: Node3D = buildings.get_node(name)
		var p := Vector2(node.global_position.x,node.global_position.z)
		if p.distance_to(expected[name]) > .01:
			push_error(name + " is off its surveyed plot: " + str(p))
			quit(1)
			return
	if Layout.ROUTES["town_hall"][-1] != Vector2(-320,-432) or Layout.ROUTES["east_bridge"][-1] != Vector2(320,150) or Layout.ROUTES["government_house_avenue"][-1] != Vector2(-390,-123):
		push_error("A building approach no longer meets its surveyed endpoint")
		quit(1)
		return
	print("BUILDING SITE POSITIONS PASS: Town Hall (-320,-470), Police (320,120), Government House (-390,-110)")
	if DisplayServer.get_name() != "headless":
		var camera := Camera3D.new()
		stage.add_child(camera)
		camera.fov = 68
		var views := [
			["town_hall",Vector3(-291,17,-420),Vector3(-320,11,-470)],
			["district_police",Vector3(344,18,166),Vector3(320,13,120)],
			["government_house",Vector3(-350,28,-55),Vector3(-390,14,-143)],
		]
		for view in views:
			camera.position = view[1]
			camera.look_at(view[2])
			camera.current = true
			for i in 5: await process_frame
			RenderingServer.force_draw(false)
			var path: String = "res://docs/world/captures/building_site_"+str(view[0])+".png"
			root.get_texture().get_image().save_png(path)
			print("BUILDING SITE CAPTURE ",path)
	quit()
