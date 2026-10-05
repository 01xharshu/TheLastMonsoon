extends Node

const Layout = preload("res://world/suryagarh/landscape_layout.gd")
var layout := Layout.new()

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	get_tree().root.mode = Window.MODE_WINDOWED
	get_tree().root.size = Vector2i(1280,720)
	get_tree().root.content_scale_size = Vector2i(1280,720)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var stage: Node3D = preload("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	get_tree().root.add_child(stage)
	get_tree().current_scene = stage
	var buildings: Node3D = stage.get_node("Settlement")
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
			get_tree().quit(1)
			return
	if Layout.ROUTES["town_hall"][-1] != Vector2(-320,-432) or Layout.ROUTES["east_bridge"][-1] != Vector2(320,150) or Layout.ROUTES["government_house_avenue"][-1] != Vector2(-390,-123):
		push_error("A building approach no longer meets its surveyed endpoint")
		get_tree().quit(1)
		return
	print("BUILDING SITE POSITIONS PASS: Town Hall (-320,-470), Police (320,120), Government House (-390,-110)")
	if DisplayServer.get_name() != "headless":
		stage.get_node("Player/UI").hide()
		stage.get_node("LandscapeUI").hide()
		var camera := Camera3D.new()
		stage.add_child(camera)
		camera.fov = 68
		var views := [
			["town_hall",Vector3(-291,17,-420),Vector3(-320,11,-470)],
			["district_police",Vector3(344,18,166),Vector3(320,13,120)],
			["government_house",Vector3(-350,28,-55),Vector3(-390,14,-143)],
		]
		var hall: Node3D = buildings.get_node("TownHall")
		var police: Node3D = buildings.get_node("DistrictPolice")
		var house: Node3D = buildings.get_node("GovernmentHouse/MainHouse")
		views.append(["realism_town_hall",hall.to_global(Vector3(-4,1.85,11)),hall.to_global(Vector3(2,1.4,-5))])
		views.append(["realism_police",police.to_global(Vector3(0,1.85,16)),police.to_global(Vector3(3,1.3,8))])
		views.append(["realism_house_hall",house.to_global(Vector3(0,2,17)),house.to_global(Vector3(0,1.8,-10))])
		views.append(["realism_house_study",house.to_global(Vector3(-19,2,16)),house.to_global(Vector3(-23.5,1.4,10.5))])
		views.append(["realism_house_drawing",house.to_global(Vector3(-5,6.2,5.5)),house.to_global(Vector3(-5,5.25,9))])
		views.append(["realism_house_bedroom",house.to_global(Vector3(-19,11, -5)),house.to_global(Vector3(-23,10.4,-11))])
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--view="):
				var selected := argument.trim_prefix("--view=")
				views = views.filter(func(view): return view[0] == selected)
				if views.is_empty():
					push_error("Unknown building capture view: "+selected)
					get_tree().quit(1)
					return
		for view in views:
			camera.position = view[1]
			camera.look_at(view[2])
			camera.current = true
			for i in 5: await get_tree().process_frame
			RenderingServer.force_draw(false)
			var path: String = "res://docs/world/captures/building_site_"+str(view[0])+".png"
			if get_tree().root.get_texture().get_image().save_png(path) != OK:
				push_error("Could not save "+path)
				get_tree().quit(1)
				return
			print("BUILDING SITE CAPTURE ",path)
	get_tree().quit()
