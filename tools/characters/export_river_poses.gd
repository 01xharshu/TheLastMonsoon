extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func matrix(t: Transform3D) -> Array:
	return [[t.basis.x.x,t.basis.y.x,t.basis.z.x,t.origin.x],[t.basis.x.y,t.basis.y.y,t.basis.z.y,t.origin.y],[t.basis.x.z,t.basis.y.z,t.basis.z.z,t.origin.z],[0,0,0,1]]
func run() -> void:
	var scene = load("res://characters/npcs/indian/river_routine_review.tscn").instantiate()
	root.add_child(scene)
	var woman = scene.women[0]
	woman.river_cloth_meshes.clear()
	for actor in scene.women: actor.set_process(false)
	var skeleton: Skeleton3D = woman.skeleton
	var rest := {}
	for i in skeleton.get_bone_count(): rest[skeleton.get_bone_name(i)] = matrix(skeleton.get_bone_global_rest(i))
	var poses := []
	woman.sample(0)
	var times:Array=Array(woman.CLOTH_TIMES)
	if "--upper-fit" in OS.get_cmdline_user_args():
		times=[]
		for eighth in 577:
			var at:=float(eighth)*.125
			var contact:bool=(at>=12 and at<=38) or (at>=48 and at<=55) or (at>=65 and at<=68)
			if eighth%2==0 or contact:times.append(at)
		for at in [17.2,48.25,52.25,65.25]:
			if not times.has(at):times.append(at)
		times.sort()
	for sample in times.size():
		woman.sample(times[sample])
		var bones := {}
		for i in skeleton.get_bone_count(): bones[skeleton.get_bone_name(i)] = matrix(skeleton.get_bone_global_pose(i))
		poses.append({"time": times[sample],"bones":bones,"key":"River cloth %03d"%sample})
	woman.travel_override=true;woman.travel_speed=1.15;woman.locomotion_blend=1.0
	woman.home=Vector3.ZERO;woman.bank=Vector3(0,0,-4);woman.travel_position=Vector3.ZERO;woman.travel_direction=Vector3.FORWARD
	for slope_index in 5:
		var slope := float(slope_index-2)*.225
		woman.ground_height=func(_x:float,z:float)->float:return -z*slope
		for frame in woman.WALK_SAMPLES:
			woman.travel_gait_time=float(frame)/woman.WALK_SAMPLES*woman.WALK_STRIDE/.6/.4
			woman.sample(1.0)
			var bones := {}
			for i in skeleton.get_bone_count(): bones[skeleton.get_bone_name(i)] = matrix(skeleton.get_bone_global_pose(i))
			poses.append({"time":1.0,"bones":bones,"key":"River walk %d %02d"%[slope_index,frame],"slope":slope})
	var output:=OS.get_environment("TLM_RIVER_POSE_OUTPUT")
	if output.is_empty():output="res://WorkingAssets/NPCs/river_woman/poses.json"
	var f := FileAccess.open(output,FileAccess.WRITE)
	f.store_string(JSON.stringify({"rest":rest,"poses":poses,"times":times}))
	print("RIVER_POSES ", poses.size())
	quit()
