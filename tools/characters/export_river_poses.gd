extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func matrix(t: Transform3D) -> Array:
	return [[t.basis.x.x,t.basis.y.x,t.basis.z.x,t.origin.x],[t.basis.x.y,t.basis.y.y,t.basis.z.y,t.origin.y],[t.basis.x.z,t.basis.y.z,t.basis.z.z,t.origin.z],[0,0,0,1]]
func run() -> void:
	var scene = load("res://characters/npcs/indian/river_routine_review.tscn").instantiate()
	root.add_child(scene)
	var woman = scene.women[0]
	for actor in scene.women: actor.set_process(false)
	var skeleton: Skeleton3D = woman.skeleton
	var rest := {}
	for i in skeleton.get_bone_count(): rest[skeleton.get_bone_name(i)] = matrix(skeleton.get_bone_global_rest(i))
	var poses := []
	woman.sample(0)
	for sample in 97:
		if sample > 0:
			for frame in 45: woman.tick_routine(1.0/60.0)
		var bones := {}
		for i in skeleton.get_bone_count(): bones[skeleton.get_bone_name(i)] = matrix(skeleton.get_bone_global_pose(i))
		poses.append({"time": sample*.75,"bones":bones})
	var f := FileAccess.open("res://WorkingAssets/NPCs/river_woman/poses.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"rest":rest,"poses":poses}))
	print("RIVER_POSES ", poses.size())
	quit()
