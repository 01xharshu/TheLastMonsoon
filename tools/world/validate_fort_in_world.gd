extends SceneTree
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await physics_frame
	var fort: Node3D = world.get_node("OldFort")
	var layout := Layout.new()
	assert(fort.position.distance_to(Vector3(Layout.FORT_CENTER.x, Layout.FORT_BASE_HEIGHT, Layout.FORT_CENTER.y)) < 0.01)
	assert(not fort.get_node("Terrain").has_node("IrregularGround"), "Fort has duplicate terrain")
	var region: NavigationRegion3D = fort.get_node("Navigation/FortWalkableRoutes")
	assert(region.navigation_mesh.get_polygon_count() > 100, "Fort route bake missing")
	var space := world.get_world_3d().direct_space_state
	var fort_colliders: Array[RID] = []
	for body in fort.find_children("*", "StaticBody3D", true, false): fort_colliders.append(body.get_rid())
	for local_z in [43.0, 0.0, -43.0]:
		var x: float = Layout.FORT_CENTER.x
		var z: float = Layout.FORT_CENTER.y + local_z
		var query := PhysicsRayQueryParameters3D.create(Vector3(x,190,z),Vector3(x,60,z))
		query.exclude = fort_colliders
		var hit := space.intersect_ray(query)
		assert(not hit.is_empty(), "World terrain absent at fort")
		var expected: float = layout.height(x,z)
		assert(absf(hit.position.y-expected) < 0.65, "Fort ground mismatch at z=%s: %s vs %s" % [z, hit.position.y, expected])
		print("FORT GROUND ",z," terrain=",hit.position.y," expected=",expected," collider=",hit.collider.name)
	var access: Array = Layout.ROUTES["fort_access"]
	var max_grade := 0.0
	for i in range(access.size()-1):
		var a: Vector2 = access[i]
		var b: Vector2 = access[i+1]
		var steps: int = int(ceil(a.distance_to(b)/2.0))
		for j in range(steps):
			var p: Vector2 = a.lerp(b,float(j)/steps)
			var q: Vector2 = a.lerp(b,float(j+1)/steps)
			max_grade = maxf(max_grade,absf(layout.height(q.x,q.y)-layout.height(p.x,p.y))/p.distance_to(q))
	assert(max_grade < 0.30, "Fort approach is too steep")
	print("FORT ACCESS MAX GRADE ",max_grade)
	var trail: Array = Layout.ROUTES["fort_trail"]
	assert(trail[0] == Layout.ROUTES["east_bridge"][-1], "Fort trail misses the bridge road")
	assert(trail[-1] == access[0], "Fort trail misses the access ramp")
	var trail_max_grade := 0.0
	for i in range(trail.size()-1):
		var a: Vector2 = trail[i]
		var b: Vector2 = trail[i+1]
		var steps: int = int(ceil(a.distance_to(b)/2.0))
		for j in range(steps):
			var p: Vector2 = a.lerp(b,float(j)/steps)
			var q: Vector2 = a.lerp(b,float(j+1)/steps)
			trail_max_grade = maxf(trail_max_grade,absf(layout.height(q.x,q.y)-layout.height(p.x,p.y))/p.distance_to(q))
	assert(trail_max_grade < 0.31, "Fort trail is too steep")
	for index in [1,3,5,7,10,12,14]:
		var p: Vector2 = trail[index]
		var trail_query := PhysicsRayQueryParameters3D.create(Vector3(p.x,175,p.y),Vector3(p.x,-20,p.y))
		trail_query.exclude = fort_colliders
		var trail_hit := space.intersect_ray(trail_query)
		assert(not trail_hit.is_empty() and absf(trail_hit.position.y-layout.height(p.x,p.y)) < 0.8, "Baked fort trail contact mismatch")
	print("FORT TRAIL MAX GRADE ",trail_max_grade," | connected to east bridge")
	var start := Vector3(Layout.FORT_CENTER.x, layout.height(Layout.FORT_CENTER.x,Layout.FORT_CENTER.y+40),Layout.FORT_CENTER.y+40)
	var finish := Vector3(Layout.FORT_CENTER.x, layout.height(Layout.FORT_CENTER.x,Layout.FORT_CENTER.y-42),Layout.FORT_CENTER.y-42)
	var path := NavigationServer3D.map_get_path(region.get_navigation_map(),start,finish,true)
	assert(path.size() >= 2, "No entry-to-keep path in main world")
	print("FORT IN WORLD PASS | polygons=",region.navigation_mesh.get_polygon_count()," | path=",path.size()," | no duplicate terrain | access grade=",max_grade)
	quit()
