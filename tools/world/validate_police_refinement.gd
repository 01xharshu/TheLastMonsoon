extends SceneTree
var errors: Array[String] = []
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	var police: Node3D = world.get_node("Settlement/DistrictPolice")
	world.get_node("Player").set_physics_process(false)
	for i in 3: await physics_frame
	var rays := 0
	for level in 2:
		for side in [-1,1]:
			for z in [-16.0,-8.0,0.0,8.0,16.0]:
				var from := police.to_global(Vector3(side*21,level*5.4+4.0,z))
				var to := police.to_global(Vector3(side*17,level*5.4+4.0,z))
				if not world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to)).is_empty():
					errors.append("External high vent is a solid wall: "+str(Vector3(side,level,z)))
				rays += 1
		for z in [-7.0,0.0,4.0]:
			var from := police.to_global(Vector3(-4,level*5.4+3.8,z))
			var to := police.to_global(Vector3(-8,level*5.4+3.8,z))
			if not world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to)).is_empty():
				errors.append("Office high vent blocked: "+str(Vector2(level,z)))
			rays += 1
	var lights := police.find_children("LocalOilLight","OmniLight3D",true,false)
	if lights.size()!=8: errors.append("Expected eight local fixture lights")
	for light in lights:
		if light.shadow_enabled or not light.distance_fade_enabled or light.omni_range>7.5:
			errors.append("Local lamp exceeds shadow/range budget")
	var chair_count := get_nodes_in_group("station_furnishing_chairs").size()
	if chair_count < 5: errors.append("Office/reception chairs absent: " + str(chair_count))
	var doors := get_nodes_in_group("station_office_doors")
	if doors.size()!=12: errors.append("Expected twelve paired office doors")
	for door in doors:
		if not door.opened or door.leaf_pivots.size()!=2: errors.append("Office door not open with paired leaves: "+str(door.name))
	if not doors.is_empty():
		var sample = doors[0]
		sample.restore_state(false)
		if sample.opened or not is_zero_approx(sample.swing): errors.append("Office door did not close")
		await physics_frame
		var close_from: Vector3 = sample.to_global(Vector3(.25,.52,-.8))
		var close_to: Vector3 = sample.to_global(Vector3(.25,.52,.8))
		var closed_hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(close_from,close_to))
		if closed_hit.is_empty() or closed_hit.collider != sample: errors.append("Closed office door has no physical leaf")
		sample.restore_state(true)
		if not sample.opened or not is_equal_approx(sample.swing,1.0): errors.append("Office door did not reopen")
	await physics_frame
	for level in 2:
		for z in [-7.0,4.0]:
			var a := police.to_global(Vector3(-4.8,level*5.4+1.0,z))
			var c := police.to_global(Vector3(-7.2,level*5.4+1.0,z))
			if not world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,c)).is_empty(): errors.append("Hall door obstructs entrance: "+str(Vector2(level,z)))
	for level in 2:
		var a := police.to_global(Vector3(16,level*5.4+1.0,-8.7))
		var c := police.to_global(Vector3(16,level*5.4+1.0,-11.3))
		var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(a,c))
		if not hit.is_empty(): errors.append("Records door obstructs entrance: "+str(level)+" collider "+str(hit.collider.get_path()))
	if police.find_children("SeniorWallMap","Node3D",true,false).size()!=1: errors.append("Senior chamber map absent")
	if police.find_children("DutyStorageChest","Node3D",true,false).size()!=1: errors.append("Duty room furnishing absent")
	var report := {"passed":errors.is_empty(),"open_vent_rays":rays,"local_lamps":lights.size(),"errors":errors,"scope":"actual open collision paths and fixture budget; airflow simulation and historical reconstruction unclaimed"}
	print("POLICE REFINEMENT ",JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
