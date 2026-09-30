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
	if get_nodes_in_group("station_furnishing_chairs").size()!=5: errors.append("Office/reception chairs absent")
	if police.find_children("DutyStorageChest","Node3D",true,false).size()!=1: errors.append("Duty room furnishing absent")
	var report := {"passed":errors.is_empty(),"open_vent_rays":rays,"local_lamps":lights.size(),"errors":errors,"scope":"actual open collision paths and fixture budget; airflow simulation and historical reconstruction unclaimed"}
	FileAccess.open("res://docs/world/police_refinement_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("POLICE REFINEMENT ",JSON.stringify(report))
	quit(0 if errors.is_empty() else 1)
