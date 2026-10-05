extends SceneTree
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const Grass = preload("res://world/suryagarh/grass_blades.gd")
func _initialize() -> void: call_deferred("run")
func sample(layout: RefCounted,p: Vector2) -> Vector3:
	var tile := ((p+Vector2.ONE*Layout.HALF)/Layout.TILE).floor()
	var origin := tile*Layout.TILE-Vector2.ONE*Layout.HALF
	var step := 1.5 if int(tile.x) in [9,10] and int(tile.y) in [3,4] else Layout.STEP
	return Grass.surface_frame(layout,origin,p,step).origin
func run() -> void:
	var landscape: Node3D = load("res://world/suryagarh/generated/landscape.scn").instantiate()
	root.add_child(landscape)
	for i in 4: await physics_frame
	var layout := Layout.new()
	var space := landscape.get_world_3d().direct_space_state
	var results: Dictionary = {}
	var defects: Array = []
	for label in Layout.ROUTES:
		var route: Array = Layout.ROUTES[label]
		var steepest := 0.0
		var crossfall := 0.0
		var worst_contact := 0.0
		var count := 0
		var worst_point := Vector2.ZERO
		for segment in range(route.size()-1):
			var a: Vector2 = route[segment]
			var b: Vector2 = route[segment+1]
			var direction := (b-a).normalized()
			var across := Vector2(-direction.y,direction.x)
			for i in ceili(a.distance_to(b))+1:
				var p := a.lerp(b,float(i)/maxi(1,ceili(a.distance_to(b))))
				var grade := absf(sample(layout,p+direction*.5).y-sample(layout,p-direction*.5).y)
				if grade > steepest: steepest = grade; worst_point = p
				crossfall = maxf(crossfall,absf(sample(layout,p+across*2).y-sample(layout,p-across*2).y)/4.0)
				for offset in [-2.0,0.0,2.0]:
					var surface := sample(layout,p+across*offset)
					var ray := PhysicsRayQueryParameters3D.create(surface+Vector3.UP*2,surface-Vector3.UP*2)
					var hit := space.intersect_ray(ray)
					if hit.is_empty(): defects.append({"route":label,"missing_ground":surface})
					elif hit.collider.name == "GroundCollision": worst_contact = maxf(worst_contact,absf(hit.position.y-surface.y))
					count += 1
		results[label] = {"samples":count,"max_longitudinal_grade":steepest,"max_cross_grade":crossfall,"worst_grade_point":worst_point,"maximum_render_collision_difference_m":worst_contact}
		if steepest > .45: defects.append({"route":label,"steep_grade":steepest,"point":worst_point})
	var report := {"routes":results,"defects":defects,"scope":"baked triangle/terrain collision at road centre and +/-2 m shoulders; >45% longitudinal grade flagged for transition review, not final player acceptance"}
	FileAccess.open("res://docs/world/terrain_routes_2026-10-05.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print("TERRAIN ROUTES ",JSON.stringify(report))
	quit()
