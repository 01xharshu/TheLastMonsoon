extends "res://tools/characters/export_village_test_surfaces.gd"
## Full imported body and garment samples; caller must clean the OS temporary folder.
func run() -> void:
	var folder := OS.get_environment("TLM_RIVER_TEST_OUTPUT")
	if folder.is_empty(): push_error("Temporary output folder required");quit(2);return
	var stage := Node3D.new();root.add_child(stage);current_scene=stage
	var woman:Node3D
	if OS.get_environment("TLM_RIVER_WORLD_FIXTURE")=="1":
		var clock=load("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";stage.add_child(clock)
		stage.add_child(load("res://world/suryagarh/generated/landscape.scn").instantiate())
		var charpai=load("res://objects/charpai.tscn").instantiate();charpai.name="Charpai";stage.add_child(charpai)
		stage.add_child(load("res://tools/world/river_village_fixture.gd").new())
		for frame in 8:await physics_frame
		var routines=get_nodes_in_group("village_river_routine")
		if routines.size()!=1:push_error("Missing live river fixture");quit(1);return
		var routine=routines[0];routine.set_physics_process(false)
		var member_index:=clampi(int(OS.get_environment("TLM_RIVER_WORLD_MEMBER")),0,routine.women.size()-1)
		woman=routine.women[member_index]
		for actor in routine.women:actor.set_process(false)
		woman.travel_speed=routine.SPEED
		if OS.get_environment("TLM_RIVER_IGNORE_BANK_TERRAIN")=="1":woman.ground_height=Callable()
	else:
		woman=preload("res://characters/npcs/indian/river_woman_study.gd").new()
		var probe_text:=OS.get_environment("TLM_RIVER_BODY_PROBE")
		var probe=JSON.parse_string(probe_text) if not probe_text.is_empty() else null
		if probe is Dictionary:
			for property in ["work_hip_forward","work_drop","work_spine1","work_spine2","work_knee_height","work_knee_forward","work_knee_spread","seated_knee_spread","work_foot_spread","seated_foot_spread","seated_foot_forward"]:
				if probe.has(property):woman.set(property,float(probe[property]))
		woman.home=Vector3.ZERO;woman.bank=Vector3(0,0,-4);woman.water_level=-.03
		if not OS.get_environment("TLM_RIVER_ACTOR_SCALE").is_empty():woman.scale=Vector3.ONE*float(OS.get_environment("TLM_RIVER_ACTOR_SCALE"))
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
		if OS.get_environment("TLM_RIVER_SECONDARY_ENVELOPE")=="1":
			for time in [1.0,17.2,43.0,48.25,52.25,65.25]:
				woman.travel_override=is_equal_approx(time,1.0)
				for direction in [Vector3.LEFT,Vector3.RIGHT,Vector3.UP,Vector3.DOWN,Vector3.FORWARD,Vector3.BACK]:
					woman.sample(time)
					for entry in woman.secondary_motion.entries:
						var parent:Transform3D=rig.get_bone_global_pose(entry.parent)
						var frame:Basis=rig.global_basis*parent.basis
						var scale:=maxf(.001,frame.get_scale().length()/sqrt(3.0))
						rig.set_bone_pose_position(entry.bone,Vector3(entry.neutral)+direction*woman.secondary_motion.limit_m()/scale)
					rig.force_update_all_bone_transforms()
					sample+=1;_export(folder,woman,rig,sample,"secondary bound "+str(time)+" "+str(direction))
		print("RIVER_NATIVE_SURFACES samples="+str(sample+1)+" exact=true")
		stage.free();quit();return
	if OS.get_environment("TLM_RIVER_SEATED_ONLY")=="1":
		for time in [35.37,36.37,38.0,40.0,41.6,42.3,43.0,43.37,45.0,46.0,47.0,48.0,48.37,48.8,49.37]:
			woman.sample(time);_export(folder,woman,rig,sample,"seated "+str(time));sample+=1
		print("RIVER_NATIVE_SURFACES samples="+str(sample)+" seated_only=true")
		stage.free();quit();return
	if OS.get_environment("TLM_RIVER_RINSE_ONLY")=="1":
		for role in ["laundry","bathing"]:
			woman.riverside_role=role
			for time in [25.5,25.75,25.875,26.0,26.125,26.25,26.5,32.0,32.37]:
				woman.sample(time);_export(folder,woman,rig,sample,role+" rinse");sample+=1
		print("RIVER_NATIVE_SURFACES samples="+str(sample)+" rinse_only=true")
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
	for time in [10.0,12.0,13.5,16.5,17.37,21.37,24.37,26.0,29.37,35.37,36.37,43.37,48.37,49.37,51.37,52.37,53.37,65.37,66.37,68.37]:
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
		for time in [17.37,24.37,26.0,29.37,43.37,49.37,52.37]:
			woman.sample(time);_export(folder,woman,rig,sample,"member="+str(member)+" "+woman.action);sample+=1
	# Production companions have distinct body/hand actions, not just identities.
	for role in ["bathing","conversation"]:
		woman.riverside_role=role;woman.member_index=1 if role=="bathing" else 2
		woman.travel_override=false;woman.ground_height=Callable()
		for time in [24.37,26.0,29.37,32.37,43.37,49.37,52.37]:
			woman.sample(time);_export(folder,woman,rig,sample,role+" "+woman.action);sample+=1
	woman.riverside_role="laundry"
	for member in [0,1,2]:
		woman.member_index=member;woman.travel_override=true;woman.travel_speed=0.0
		for time in [1.37,55.37]:
			woman.sample(time);_export(folder,woman,rig,sample,"member="+str(member)+" waiting "+woman.action);sample+=1
	# Real frame-time start/stop blends must preserve the fitted cloth as well
	# as the stationary and full-stride endpoints.
	woman.member_index=0;woman.riverside_role="laundry";woman.ground_height=Callable()
	woman.travel_position=woman.bank;woman.travel_override=true
	for starting in [true,false]:
		woman.travel_speed=0.0 if starting else 1.15
		woman.sample(54.99 if starting else 9.99)
		woman.travel_speed=1.15 if starting else 0.0
		for frame in 14:
			woman.travel_gait_time+=1.0/60.0
			woman.tick_routine(1.0/60.0)
			_export(folder,woman,rig,sample,("start walk " if starting else "stop walk ")+str(frame));sample+=1
	print("RIVER_NATIVE_SURFACES samples=",sample)
	stage.free();quit()

func pose_matrix(t:Transform3D) -> Array:
	return [[t.basis.x.x,t.basis.y.x,t.basis.z.x,t.origin.x],[t.basis.x.y,t.basis.y.y,t.basis.z.y,t.origin.y],[t.basis.x.z,t.basis.y.z,t.basis.z.z,t.origin.z],[0,0,0,1]]

func _export(folder:String,woman:Node3D,rig:Skeleton3D,sample:int,label:String) -> void:
	woman.apply_face_identity()
	rig.force_update_all_bone_transforms()
	var data:Dictionary={"pose_time":woman.elapsed,"hand_errors":woman.hand_errors,"foot_errors":woman.foot_errors,"role":"river_woman","walking":woman.walking,"sample":sample,"label":label,"body":[],"garments":[],"bones":{},"skeleton_transform":pose_matrix(rig.global_transform)}
	for bone in rig.get_bone_count():data.bones[rig.get_bone_name(bone)]=pose_matrix(rig.get_bone_global_pose(bone))
	data["knee_points"]={}
	var knee_clearance:=INF
	for side in ["l","r"]:
		var knee:=rig.to_global(rig.get_bone_global_pose(rig.find_bone("calf_"+side)).origin)
		var floor_y: float=woman.ground_height.call(knee.x,knee.z) if woman.ground_height.is_valid() else 0.0
		data.knee_points[side]={"point":[knee.x,knee.y,knee.z],"ground":floor_y}
		knee_clearance=minf(knee_clearance,knee.y-floor_y-.06*woman.scale.y)
		if OS.get_environment("TLM_RIVER_GROUND_DEBUG")=="1" and is_equal_approx(woman.elapsed,43.0):print("RIVER_GROUND_DEBUG ",side," knee=",knee," floor=",floor_y," bank=",woman.bank," foot=",rig.to_global(rig.get_bone_global_pose(rig.find_bone("foot_"+side)).origin))
	data["minimum_knee_clearance_m"]=knee_clearance
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
				# Dummy rendering cannot read updated GPU vertex buffers. Use the
				# exact CPU upload retained by the drape owner; Metal readback
				# is verified separately by validate_river_drape_buffers.gd.
				var uploaded:PackedVector3Array=node.get_meta("river_sari_points",PackedVector3Array())
				if uploaded.size()!=arrays[Mesh.ARRAY_VERTEX].size():push_error("Missing complete drape upload");quit(1);return
				for vertex in uploaded:world_points.append(node.global_transform*vertex)
			var garment_name:String="Woven sari pallu over blouse" if str(node.name)=="Fitted cotton upper base" and surface>0 else str(node.name)
			var entry:Dictionary={"name":garment_name,"vertices":serialize_points(world_points),"indices":arrays[Mesh.ARRAY_INDEX]}
			if garment_name=="Opaque fitted bra and thong foundation":
				# Stable rest-space regions: pose height can bring the lower
				# foundation close to bent upper cloth, but it is not its support.
				var rest_points:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var foundation_ids:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
				var bra_ids:=PackedInt32Array()
				for j in range(0,foundation_ids.size(),3):
					if minf(rest_points[foundation_ids[j]].y,minf(rest_points[foundation_ids[j+1]].y,rest_points[foundation_ids[j+2]].y))>.94:
						bra_ids.append_array(foundation_ids.slice(j,j+3))
				if bra_ids.is_empty():push_error("Upper foundation region missing");quit(1);return
				if bra_ids.size()==foundation_ids.size():push_error("Lower foundation region missing");quit(1);return
				entry["upper_foundation_indices"]=bra_ids
			if body and woman.action=="talk":
				for point in world_points:seated_points.append(woman.to_local(point))
			if body:
				var raw:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
				var ids:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
				var torso_ids:=PackedInt32Array();var leg_ids:=PackedInt32Array()
				for triangle in range(0,ids.size(),3):
					var rest_height:=Vector3(raw[ids[triangle]].y,raw[ids[triangle+1]].y,raw[ids[triangle+2]].y)
					if minf(rest_height.x,minf(rest_height.y,rest_height.z))>.98:torso_ids.append_array(ids.slice(triangle,triangle+3))
					if maxf(rest_height.x,maxf(rest_height.y,rest_height.z))<.79:leg_ids.append_array(ids.slice(triangle,triangle+3))
				entry["upper_torso_indices"]=torso_ids;entry["lower_body_indices"]=leg_ids
				for triangle in range(0,ids.size(),3):
					var a:=ids[triangle];var b:=ids[triangle+1];var c:=ids[triangle+2]
					var dot:float=(raw[b]-raw[a]).cross(raw[c]-raw[a]).dot(normals[a]+normals[b]+normals[c])
					if absf(dot)>.00000001:entry["winding_sign"]=signf(dot);break
			else:
				entry["active_keys"]=[]
				for key in node.mesh.get_blend_shape_count():
					var value:float=node.get_blend_shape_value(key)
					if value>.0001:entry.active_keys.append([node.mesh.get_blend_shape_name(key),value])
			if str(node.name)=="Wrapped sari lower drape" and woman.get_meta("integral_sari_border",false):
				var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
				var source_ids:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
				var wrap_ids:=PackedInt32Array();var border_ids:=PackedInt32Array()
				for j in range(0,source_ids.size(),3):
					var hem:float=1.0-(uv[source_ids[j]].y+uv[source_ids[j+1]].y+uv[source_ids[j+2]].y)/3.0
					if hem<.035:border_ids.append_array(source_ids.slice(j,j+3))
					else:wrap_ids.append_array(source_ids.slice(j,j+3))
				if wrap_ids.is_empty() or border_ids.is_empty():push_error("Missing integral woven border region");quit(1);return
				entry.indices=wrap_ids;data.garments.append(entry)
				var band:Dictionary=entry.duplicate();band.name="Sari lower border";band.indices=border_ids;data.garments.append(band)
			elif str(node.name)=="Fitted cotton upper base" and node.mesh.get_surface_count()==1 and arrays[Mesh.ARRAY_COLOR]!=null:
				var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
				var source_ids:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
				var blouse_ids:=PackedInt32Array();var pallu_ids:=PackedInt32Array()
				for j in range(0,source_ids.size(),3):
					var mask:float=(colors[source_ids[j]].r+colors[source_ids[j+1]].r+colors[source_ids[j+2]].r)/3.0
					if mask>.5:pallu_ids.append_array(source_ids.slice(j,j+3))
					else:blouse_ids.append_array(source_ids.slice(j,j+3))
				if blouse_ids.is_empty() or pallu_ids.is_empty():push_error("Missing coherent cloth region mask");quit(1);return
				entry.name="Fitted cotton upper base";entry.indices=blouse_ids;data.garments.append(entry)
				var panel:Dictionary=entry.duplicate();panel.name="Woven sari pallu over blouse";panel.indices=pallu_ids;data.garments.append(panel)
			else:data["body" if body else "garments"].append(entry)
	if not seated_points.is_empty():
		var hip: Vector3=woman.to_local(rig.to_global(woman.Contact.point(rig,"pelvis")))
		var gap := INF
		for point in seated_points:
			if absf(point.x-hip.x)<.19 and point.z>hip.z+.025 and point.y>hip.y-.3 and point.y<hip.y+.2:gap=minf(gap,point.y)
		if is_inf(gap):push_error("Seated rear hip surface missing")
		else:data["seated_rear_hip_gap_m"]=gap
	var output:=FileAccess.open(folder+"/river_%03d.json"%sample,FileAccess.WRITE)
	output.store_string(JSON.stringify(data));output.close()
