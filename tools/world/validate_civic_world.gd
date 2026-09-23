extends SceneTree
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
const OUT := "res://docs/world/civic_world_validation.json"
var layout := Layout.new()
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("validate")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func validate() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 8: await physics_frame
	var settlement := world.get_node("Settlement")
	var ground_samples: Dictionary = {}
	var space := world.get_world_3d().direct_space_state
	for name in ["TownHall","DistrictPolice","DistrictJail","CompanyArmoury"]:
		var building: Node3D = settlement.get_node(name)
		var p := building.global_position
		var expected := layout.height(p.x,p.z)
		var gap := p.y-expected
		check(gap >= -0.03 and gap <= 0.5,name+" foundation misses surveyed terrain by "+str(gap)+" m")
		ground_samples[name] = {"position":p,"foundation_above_grade_m":gap}
	var compound: Node3D = settlement.get_node("ColonialCompound")
	check(absf(compound.position.y-Layout.PLOTS["CompanyCompound"].grade)<0.01,"Compound courtyard grade drifted")
	var excluded: Array[RID] = [world.get_node("Player").get_rid()]
	var route_samples := 0
	var worst_contact := 0.0
	for name in Layout.ROUTES:
		var points: Array = Layout.ROUTES[name]
		for i in range(points.size()-1):
			var a: Vector2 = points[i]
			var b: Vector2 = points[i+1]
			for step in range(ceili(a.distance_to(b)/4.0)+1):
				var p := a.lerp(b,float(step)/maxi(1,ceili(a.distance_to(b)/4.0)))
				# A continuous, baked HeightMapShape under the road is required.
				var query := PhysicsRayQueryParameters3D.create(Vector3(p.x,200,p.y),Vector3(p.x,-30,p.y))
				var exclusions: Array[RID] = excluded.duplicate()
				query.exclude = exclusions
				var hit := space.intersect_ray(query)
				for attempt in 12:
					if hit.is_empty() or hit.collider.name=="GroundCollision": break
					exclusions.append(hit.collider.get_rid())
					query.exclude = exclusions
					hit = space.intersect_ray(query)
				check(not hit.is_empty(),name+" has no physical ground at "+str(p))
				if not hit.is_empty():
					var error := absf(hit.position.y-layout.height(p.x,p.y))
					worst_contact = maxf(worst_contact,error)
					check(error < 0.12,name+" road surface and collision differ by "+str(error)+" m")
				route_samples += 1
	var tree_count := 0
	var rock_count := 0
	var intrusions := 0
	var intrusion_samples: Array[Dictionary] = []
	for batch in world.get_node("Landscape/NatureTiles").find_children("*","MultiMeshInstance3D",true,false):
		if batch.name != "BroadleafTrees" and batch.name != "Boulders": continue
		for i in batch.multimesh.instance_count:
			var p: Vector3 = batch.to_global(batch.multimesh.get_instance_transform(i).origin)
			if batch.name == "BroadleafTrees":
				tree_count += 1
				if layout.built_area(p.x,p.z) or layout.road_distance(p.x,p.z)<9.0:
					intrusions += 1
					if intrusion_samples.size()<20: intrusion_samples.append({"kind":"tree","position":p,"road_distance":layout.road_distance(p.x,p.z),"plot_clearance":layout.plot_clearance(p.x,p.z)})
			else:
				rock_count += 1
				if layout.built_area(p.x,p.z) or layout.road_distance(p.x,p.z)<7.0:
					intrusions += 1
					if intrusion_samples.size()<20: intrusion_samples.append({"kind":"rock","position":p,"road_distance":layout.road_distance(p.x,p.z),"plot_clearance":layout.plot_clearance(p.x,p.z)})
	check(intrusions==0,str(intrusions)+" baked trees/rocks intrude into a plot or road")
	var report := {"status":"PASS" if failures.is_empty() else "FAIL","foundations":ground_samples,"route_contact_samples":route_samples,"worst_route_contact_error_m":worst_contact,"trees_checked":tree_count,"rocks_checked":rock_count,"nature_intrusions":intrusions,"intrusion_samples":intrusion_samples,"failures":failures}
	var file := FileAccess.open(OUT,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	print("CIVIC WORLD VALIDATION ",JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
