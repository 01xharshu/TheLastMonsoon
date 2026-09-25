extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var scene: Node3D = load("res://world/ruined_fort/ruined_fort.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var region: NavigationRegion3D = scene.get_node("Navigation/FortWalkableRoutes")
	var nav: NavigationMesh = region.navigation_mesh
	assert(nav != null and nav.get_polygon_count() > 50, "Fort navigation bake is empty")
	var start := Vector3(0,scene.height_at(0,40),40)
	var finish := Vector3(0,scene.height_at(0,-42),-42)
	var path := NavigationServer3D.map_get_path(region.get_navigation_map(),start,finish,true)
	assert(path.size() >= 2, "No route through the fort")
	assert(NavigationServer3D.map_get_closest_point(region.get_navigation_map(),start).distance_to(start) < 8.0, "Entry is off navigation")
	assert(NavigationServer3D.map_get_closest_point(region.get_navigation_map(),finish).distance_to(finish) < 8.0, "Keep is off navigation")
	var cover := scene.get_node("Cover")
	assert(cover.get_child_count() >= 25, "Combat cover is missing")
	print("FORT VALIDATION PASS | nav polygons=",nav.get_polygon_count()," | path points=",path.size()," | cover=",cover.get_child_count())
	quit()
