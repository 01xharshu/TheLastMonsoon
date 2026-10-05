extends SceneTree
var errors:Array[String]=[]
func _initialize()->void:_run.call_deferred()
func _run()->void:
	var scene:Node3D=load("res://tools/world/capture_street_walk.tscn").instantiate();root.add_child(scene);current_scene=scene
	scene.set_process(false);scene.set_physics_process(false)
	for journey in scene.journeys:journey.set_physics_process(false)
	for frame in 3:await physics_frame
	var report:Array=[]
	for journey in scene.journeys:
		var actor:Node3D=journey.actor;var rig:Skeleton3D=actor._skeleton
		var shoes:Dictionary={}
		for mesh:MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
			if "street leather shoe" in mesh.name.to_lower():shoes["l" if mesh.name.to_lower().ends_with("l") else "r"]=mesh
		var stance_max:=0.0;var min_gap:=10.0;var max_gap:=-10.0;var samples:=0
		for frame in 1500:
			journey.tick(1.0/60)
			if not actor.foot_plant.active:continue
			var side:String=actor.foot_plant.planted_side
			var foot:=rig.find_bone("foot_"+side)
			stance_max=maxf(stance_max,rig.to_global(rig.get_bone_global_pose(foot).origin).distance_to(actor.foot_plant.planted_world))
			var mesh:MeshInstance3D=shoes[side]
			var skin:=rig.get_bone_global_pose(foot)*rig.get_bone_global_rest(foot).affine_inverse()
			var sole:=100.0
			for vertex in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
				var point:=rig.to_global(skin*rig.to_local(mesh.to_global(vertex)))
				sole=minf(sole,point.y-7.2)
			min_gap=minf(min_gap,sole);max_gap=maxf(max_gap,sole);samples+=1
		if stance_max>.025:errors.append(str(actor.name)+" ankle stance drift >25mm")
		if min_gap<-.01 or max_gap>.025:errors.append(str(actor.name)+" actual shoe sole outside -10/+25mm ground range")
		report.append({"actor":str(actor.name),"samples":samples,"stance_max_m":stance_max,"sole_min_gap_m":min_gap,"sole_max_gap_m":max_gap})
	var result:={"passed":errors.is_empty(),"errors":errors,"residents":report,"scope":"continuous 25s with start/stop/turn real skinned shoe soles and planted ankle; cloth and rendered review separate"}
	FileAccess.open("res://docs/world/street_contact_validation.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("STREET CONTACT: ",JSON.stringify(result));scene.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)
