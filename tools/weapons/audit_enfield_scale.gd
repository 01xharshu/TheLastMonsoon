extends SceneTree
## Measure weapon geometry without instancing a character.
func _initialize() -> void:
	call_deferred("audit")

func audit() -> void:
	var scene: Node3D = load("res://environment/weapons/enfield_p53/weapon_enfield_p53_01.glb").instantiate()
	root.add_child(scene)
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	var mesh_count := 0
	for mesh in scene.find_children("*", "MeshInstance3D", true, false):
		mesh_count += 1
		var bounds: AABB = mesh.get_aabb()
		for x in [bounds.position.x, bounds.end.x]:
			for y in [bounds.position.y, bounds.end.y]:
				for z in [bounds.position.z, bounds.end.z]:
					var point: Vector3 = scene.to_local(mesh.to_global(Vector3(x, y, z)))
					minimum = minimum.min(point)
					maximum = maximum.max(point)
	var dimensions := maximum - minimum
	for name in ["enfield_ramrod", "enfield_barrel", "enfield_stock_walnut"]:
		var part: Node3D = scene.find_child(name, true, false)
		if part: print("ENFIELD PART ", name, " local=", scene.to_local(part.global_position))
	assert(mesh_count > 0 and absf(dimensions.x - 1.41) < 0.025)
	var runtime_length := dimensions.x * preload("res://player/arjun_equipment.gd").ENFIELD_SCALE
	assert(absf(runtime_length - 1.1985) < .005)
	print("ENFIELD RUNTIME LENGTH: ",runtime_length," m | 1.41 m source retained")
	var double_gun: Node3D = load("res://environment/weapons/double_percussion_gun/double_percussion_gun.glb").instantiate()
	root.add_child(double_gun)
	var double_min := INF
	var double_max := -INF
	for mesh in double_gun.find_children("*", "MeshInstance3D", true, false):
		var bounds: AABB = mesh.get_aabb()
		for x in [bounds.position.x, bounds.end.x]:
			for y in [bounds.position.y, bounds.end.y]:
				for z in [bounds.position.z, bounds.end.z]:
					var local: Vector3 = double_gun.to_local(mesh.to_global(Vector3(x, y, z)))
					double_min = minf(double_min, local.x)
					double_max = maxf(double_max, local.x)
	var double_length: float = (double_max - double_min) * preload("res://player/arjun_equipment.gd").DOUBLE_GUN_SCALE
	assert(absf(double_length - 1.19966) < .005)
	print("DOUBLE GUN RUNTIME LENGTH: ", double_length, " m")
	var body: Node3D = load("res://characters/arjun/arjun.glb").instantiate()
	root.add_child(body)
	var body_min := Vector3(INF, INF, INF)
	var body_max := Vector3(-INF, -INF, -INF)
	for mesh in body.find_children("*", "MeshInstance3D", true, false):
		var bounds: AABB = mesh.get_aabb()
		for x in [bounds.position.x, bounds.end.x]:
			for y in [bounds.position.y, bounds.end.y]:
				for z in [bounds.position.z, bounds.end.z]:
					var point: Vector3 = body.to_local(mesh.to_global(Vector3(x, y, z)))
					body_min = body_min.min(point)
					body_max = body_max.max(point)
	var body_height: float = body_max.y-body_min.y
	assert(body_height > 1.4 and body_height < 2.2)
	print("LONG GUN SCALE: PASS | meshes=", mesh_count, " source_dimensions_m=", dimensions, " body_height_m=", body_height, " rendered_rifle_to_body=", runtime_length/body_height)
	quit()
