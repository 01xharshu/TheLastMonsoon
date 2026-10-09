extends "res://tools/characters/export_village_test_surfaces.gd"
## Full imported body and garment samples; caller must clean the OS temporary folder.
func run() -> void:
	var folder := OS.get_environment("TLM_RIVER_TEST_OUTPUT")
	if folder.is_empty(): push_error("Temporary output folder required");quit(2);return
	var stage := Node3D.new();root.add_child(stage)
	var woman := preload("res://characters/npcs/indian/river_woman_study.gd").new()
	woman.home=Vector3.ZERO;woman.bank=Vector3(0,0,-4)
	stage.add_child(woman);woman.set_process(false)
	var rig: Skeleton3D=woman.skeleton
	var sample := 0
	if OS.get_environment("TLM_RIVER_EXACT")=="1":
		woman.travel_override=true;woman.travel_speed=1.15;woman.travel_direction=Vector3.FORWARD
		woman.travel_gait_time=4.0/48.0*woman.WALK_STRIDE/.6/.4
		woman.sample(1.0);_export(folder,woman,rig,0,"exact walking")
		woman.travel_override=false
		for time in [17.2,48.25,52.25,65.25]:
			woman.sample(time);sample+=1;_export(folder,woman,rig,sample,"exact "+str(time))
		print("RIVER_NATIVE_SURFACES samples=5 exact=true")
		stage.free();quit();return
	woman.travel_override=true;woman.travel_speed=1.15;woman.travel_direction=Vector3.FORWARD
	for slope in [-.45,-.225,0.0,.225,.45]:
		woman.ground_height=func(_x:float,z:float)->float:return -z*slope
		for frame in 24:
			woman.locomotion_blend=1.0
			woman.travel_gait_time=(float(frame)+.37)/24.0*woman.WALK_STRIDE/.6/.4
			woman.sample(1.0)
			_export(folder,woman,rig,sample,"walk slope="+str(slope));sample+=1
	# Intermediate slopes exercise the two-slope morph blend used on real banks.
	for slope in [-.3375,-.1125,.1125,.3375]:
		woman.ground_height=func(_x:float,z:float)->float:return -z*slope
		for frame in 12:
			woman.locomotion_blend=1.0
			woman.travel_gait_time=(float(frame)+.37)/12.0*woman.WALK_STRIDE/.6/.4
			woman.sample(1.0)
			_export(folder,woman,rig,sample,"walk blended slope="+str(slope));sample+=1
	woman.ground_height=Callable();woman.travel_override=false
	for time in [10.0,12.0,13.5,16.5,17.37,21.37,24.37,29.37,35.37,36.37,43.37,48.37,49.37,51.37,52.37,53.37,65.37,66.37,68.37]:
		woman.sample(time)
		_export(folder,woman,rig,sample,woman.action);sample+=1
	# Other members have independent headings and neck motion; their clothes
	# must remain clear as well as the first actor's fitted pose.
	for member in [1,2]:
		woman.member_index=member;woman.travel_override=true;woman.travel_speed=1.15
		woman.ground_height=func(_x:float,z:float)->float:return -z*.1125
		woman.travel_gait_time=.37*woman.WALK_STRIDE/.6/.4
		woman.sample(1.0);_export(folder,woman,rig,sample,"member="+str(member)+" walk");sample+=1
		woman.ground_height=Callable();woman.travel_override=false
		for time in [17.37,24.37,29.37,43.37,49.37,52.37]:
			woman.sample(time);_export(folder,woman,rig,sample,"member="+str(member)+" "+woman.action);sample+=1
	for member in [0,1,2]:
		woman.member_index=member;woman.travel_override=true;woman.travel_speed=0.0
		for time in [1.37,55.37]:
			woman.sample(time);_export(folder,woman,rig,sample,"member="+str(member)+" waiting "+woman.action);sample+=1
	print("RIVER_NATIVE_SURFACES samples=",sample)
	stage.free();quit()

func pose_matrix(t:Transform3D) -> Array:
	return [[t.basis.x.x,t.basis.y.x,t.basis.z.x,t.origin.x],[t.basis.x.y,t.basis.y.y,t.basis.z.y,t.origin.y],[t.basis.x.z,t.basis.y.z,t.basis.z.z,t.origin.z],[0,0,0,1]]

func _export(folder:String,woman:Node3D,rig:Skeleton3D,sample:int,label:String) -> void:
	rig.force_update_all_bone_transforms()
	var data:Dictionary={"role":"river_woman","walking":woman.walking,"sample":sample,"label":label,"body":[],"garments":[],"bones":{},"skeleton_transform":pose_matrix(rig.global_transform)}
	for bone in rig.get_bone_count():data.bones[rig.get_bone_name(bone)]=pose_matrix(rig.get_bone_global_pose(bone))
	var seated_points: Array[Vector3]=[]
	for node:MeshInstance3D in woman.find_children("*","MeshInstance3D",true,false):
		if node.skin==null and not woman.river_cloth_meshes.has(node):continue
		var body:=str(node.name).contains("export_cutout")
		if not body and not woman.river_cloth_meshes.has(node):continue
		for surface in node.mesh.get_surface_count():
			var arrays:=node.mesh.surface_get_arrays(surface)
			var world_points: PackedVector3Array
			if node.skin!=null:world_points=posed_points(node,rig,surface)
			else:
				world_points=PackedVector3Array()
				for vertex in arrays[Mesh.ARRAY_VERTEX]:world_points.append(node.global_transform*vertex)
			var entry:Dictionary={"name":str(node.name),"vertices":serialize_points(world_points),"indices":arrays[Mesh.ARRAY_INDEX]}
			if body and woman.action=="talk":
				for point in world_points:seated_points.append(woman.to_local(point))
			if body:
				var raw:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
				var ids:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
				for triangle in range(0,ids.size(),3):
					var a:=ids[triangle];var b:=ids[triangle+1];var c:=ids[triangle+2]
					var dot:float=(raw[b]-raw[a]).cross(raw[c]-raw[a]).dot(normals[a]+normals[b]+normals[c])
					if absf(dot)>.00000001:entry["winding_sign"]=signf(dot);break
			else:
				entry["active_keys"]=[]
				for key in node.mesh.get_blend_shape_count():
					var value:float=node.get_blend_shape_value(key)
					if value>.0001:entry.active_keys.append([node.mesh.get_blend_shape_name(key),value])
			data["body" if body else "garments"].append(entry)
	if not seated_points.is_empty():
		var hip: Vector3=woman.to_local(rig.to_global(woman.Contact.point(rig,"pelvis")))
		var gap := INF
		for point in seated_points:
			if absf(point.x-hip.x)<.19 and point.z>hip.z+.025 and point.y>hip.y-.3 and point.y<hip.y+.2:gap=minf(gap,point.y)
		if is_inf(gap):push_error("Seated rear hip surface missing")
		else:data["seated_rear_hip_gap_m"]=gap
	var output:=FileAccess.open(folder+"/river_%03d.json"%sample,FileAccess.WRITE)
	output.store_string(JSON.stringify(data));output.close()
