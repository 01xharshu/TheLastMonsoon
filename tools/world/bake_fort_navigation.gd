extends SceneTree
func _initialize() -> void:
	call_deferred("_bake")
func _bake() -> void:
	var fort: Node3D = load("res://world/ruined_fort/fort_world_piece.tscn").instantiate()
	fort.force_navigation_rebake = true
	root.add_child(fort)
	var nav: NavigationMesh = fort.get_node("Navigation/FortWalkableRoutes").navigation_mesh
	assert(nav != null and nav.get_polygon_count() > 100)
	var err := ResourceSaver.save(nav,"res://world/ruined_fort/fort_navigation.res",ResourceSaver.FLAG_COMPRESS)
	assert(err == OK)
	print("FORT NAVIGATION BAKE PASS | polygons=",nav.get_polygon_count())
	quit()
