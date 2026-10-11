extends SceneTree
## Print the retained rig and fabric profile without writing test artifacts.
func _initialize()->void:run.call_deferred()
func run()->void:
	var actor:=preload("res://characters/npcs/indian/river_woman_study.gd").new()
	root.add_child(actor);actor.set_process(false)
	for time in [1.0,43.0]:
		actor.sample(time)
		print("RIVER_PROFILE action=",actor.action)
		for bone in ["spine_01","pelvis","thigh_l","calf_l","foot_l"]:
			print("RIVER_PROFILE_BONE ",bone," ",actor.to_local(actor.skeleton.to_global(actor.skeleton.get_bone_global_pose(actor.skeleton.find_bone(bone)).origin)))
		for node:MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
			if str(node.name)!="Wrapped sari lower drape":continue
			var points:PackedVector3Array=node.get_meta("river_sari_points")
			for row in 21:print("RIVER_PROFILE_ROW ",row," front=",points[row*40+30]," back=",points[row*40+10]," side=",points[row*40])
	actor.free();quit()
