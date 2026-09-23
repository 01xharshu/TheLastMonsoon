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
	assert(mesh_count > 0 and absf(dimensions.x - 1.41) < 0.025)
	print("ENFIELD SCALE: PASS | meshes=", mesh_count, " dimensions_m=", dimensions)
	quit()
