extends SceneTree
const Layout = preload("res://world/suryagarh/landscape_layout.gd")
var world: Node3D
var actor: CharacterBody3D
var walks: Dictionary = {}
var failures: Array[String] = []
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	world = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for frame in 8: await physics_frame
	actor = world.get_node("Player")
	actor.set_physics_process(false)
	var lines: Node3D = world.get_node("Settlement/CivilLines")
	var market: Node3D = world.get_node("Settlement/CantonmentBazaar")
	check(get_nodes_in_group("civil_lines_bungalows").size()==2,"Two role-specific bungalows")
	check(get_nodes_in_group("civil_lines_service_quarters").size()==2,"Two service quarters")
	check(get_nodes_in_group("cantonment_bazaar_stalls").size()==6,"Six service stalls")
	check(world.has_node("Settlement/GovernmentHouse"),"Existing regional residence retained")
	for area in [lines,market]: check(area.find_children("*","Label3D",true,false).is_empty(),"No building text")
	for group in ["civil_lines_bungalows","civil_lines_service_quarters","cantonment_bazaar_stalls"]:
		for building in get_nodes_in_group(group):
			var entry: Vector3 = building.get_node("Entrance").global_position
			await walk(str(building.name),[entry,building.to_global(Vector3(0,0.25,2.8 if group == "cantonment_bazaar_stalls" else 0))])
	var exclusions: Array[RID] = [actor.get_rid()]
	for body in world.find_children("*","StaticBody3D",true,false):
		if body.name != "GroundCollision": exclusions.append(body.get_rid())
	var samples := 0
	for id in ["civil_lines_avenue","collector_bungalow_drive","officer_bungalow_drive","cantonment_bazaar_lane"]:
		var path: Array[Vector3] = []
		var route: Array = Layout.ROUTES[id]
		for point in route: path.append(Vector3(point.x,10.0 if id != "cantonment_bazaar_lane" else 8.5,point.y))
		await walk(id,path)
		for i in range(path.size()-1):
			var count := int(path[i].distance_to(path[i+1])/3)+1
			for j in range(count+1):
				var p: Vector3 = path[i].lerp(path[i+1],float(j)/count)
				var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP*50,p-Vector3.UP*20,1)
				ray.exclude = exclusions
				var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
				check(not hit.is_empty() and absf(hit.position.y-p.y)<0.05,"Resident lane terrain "+str(p))
				samples += 1
	var tree_count := 0
	var max_tree_gap := -INF
	for batch in world.get_node("Landscape/NatureTiles").find_children("*BroadleafTrees","MultiMeshInstance3D",true,false):
		for i in batch.multimesh.instance_count:
			var t: Transform3D = batch.multimesh.get_instance_transform(i)
			if is_zero_approx(t.basis.determinant()): continue
			var p: Vector3 = batch.global_transform*t.origin
			var ray := PhysicsRayQueryParameters3D.create(Vector3(p.x,400,p.z),Vector3(p.x,-80,p.z),1)
			ray.exclude = exclusions
			var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
			if hit.is_empty():
				check(false,"Tree has no terrain support "+str(p))
				continue
			var bottom: float = batch.multimesh.mesh.get_aabb().position.y*t.basis.get_scale().y
			var gap: float = p.y+bottom-hit.position.y
			max_tree_gap = maxf(max_tree_gap,gap)
			check(absf(gap+.12)<.025,"Tree root gap "+str(gap)+" at "+str(p))
			tree_count += 1
	var report := {"date":"2026-10-01","walks":walks,"terrain_samples":samples,"trees_checked":tree_count,"max_tree_foot_gap_m":max_tree_gap,"failures":failures,"status":"construction candidate","renderer":RenderingServer.get_current_rendering_method(),"open":"staff, market services, normal-speed motion, historical and owner art approval"}
	var file := FileAccess.open("res://docs/world/civil_lines_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	if DisplayServer.get_name() != "headless":
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.make_current()
		actor.get_node("UI").hide()
		actor.get_node("VisualRoot").hide()
		for view in [
			["civil_lines_overview",Vector3(785,85,355),Vector3(675,10,235)],
			["collector_bungalow",Vector3(665,20,274),Vector3(640,12,235)],
			["cantonment_bazaar",Vector3(692,36,530),Vector3(632,9,470)],
			["collector_interior",Vector3(639,12.1,239),Vector3(633,11.6,232)],
			["officer_interior",Vector3(721,12.1,237),Vector3(726,11.6,232)],
			["collector_veranda",Vector3(648,12.1,253),Vector3(636,11.8,244)],
			["bazaar_player_height",Vector3(633,10.3,465),Vector3(640,10.1,452)]
		]:
			camera.global_position = view[1]
			camera.look_at(view[2])
			for frame in 8: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/world/captures/"+view[0]+".png")
	print("CIVIL LINES / BAZAAR: ","PASS" if failures.is_empty() else "FAIL"," | walks=",walks.size()," terrain samples=",samples," failures=",failures)
	quit(0 if failures.is_empty() else 1)
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
func walk(id: String, points: Array) -> void:
	var half: float = actor.get_node("CollisionShape3D").shape.height*0.5
	actor.global_position = points[0]+Vector3.UP*(half+0.04)
	actor.velocity = Vector3.ZERO
	await physics_frame
	var reached := true
	for target in points.slice(1):
		var arrived := false
		var blocked := 0
		for frame in 1800:
			var before := actor.global_position
			for step in 8:
				var direction: Vector3 = target-actor.global_position
				direction.y = 0
				if direction.length()<0.25:
					arrived = true
					break
				actor.velocity = direction.normalized()*5+Vector3(0,-2,0)
				actor.move_and_slide()
				actor.call("_try_walk_step",1.0/60.0,direction.normalized()*5/60.0)
			if arrived: break
			blocked = blocked+1 if actor.global_position.distance_to(before)<0.005 else 0
			if blocked > 30: break
			await physics_frame
		if not arrived:
			reached = false
			break
	print("WALK ",id," ",reached," ",actor.global_position)
	walks[id] = {"passed":reached,"end":str(actor.global_position)}
	check(reached,"Player collider traversal "+id)
