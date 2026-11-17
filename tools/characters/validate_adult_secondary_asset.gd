extends "res://tools/characters/audit_village_runtime_contact.gd"
var failures: Array[String] = []
var checks := 0
func check(value: bool, label: String) -> void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func run() -> void:
	var actor=load("res://characters/npcs/indian/river_woman_study.gd").new()
	actor.home=Vector3.ZERO;actor.bank=Vector3(0,0,-4);root.add_child(actor);actor.set_process(false)
	await process_frame
	check(actor.get_meta("adult_character",false),"explicit adult asset")
	check(actor.secondary_motion.entries.size()==2,"two authored MPFB breast bones")
	check(actor.secondary_meshes.size()>=3,"body foundation and outerwear have shared profile morphs")
	var body: MeshInstance3D
	for mesh: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
		if "makehuman_body" in str(mesh.name).to_lower():body=mesh;break
	check(body!=null,"complete MPFB body present")
	if body==null:quit(1);return
	var raw: PackedVector3Array=body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check(raw.size()==14517,"complete body vertex count retained")
	for label in ["Adult MPFB smaller","Adult MPFB fuller"]:
		var index:=body.find_blend_shape_by_name(label);var maximum:=0.0
		if index>=0:
			var target: PackedVector3Array=body.mesh.surface_get_blend_shape_arrays(0)[index][Mesh.ARRAY_VERTEX]
			for vertex in raw.size():maximum=maxf(maximum,target[vertex].distance_to(raw[vertex]))
		check(index>=0 and maximum>.002 and maximum<.05,"actual MPFB shape variation "+label)
	var peaks: Array[float]=[]
	for profile in 3:
		actor.member_index=profile;actor.travel_override=true;actor.travel_speed=1.15;actor.travel_direction=Vector3.FORWARD;actor.travel_position=Vector3.ZERO;actor.travel_gait_time=0
		actor.sample(1.0)
		check(actor.get_meta("adult_body_profile")==["smaller","original","fuller"][profile],"stable individual profile "+str(profile))
		for entry in actor.secondary_meshes:
			check(is_equal_approx(entry.mesh.get_blend_shape_value(entry.smaller),1.0 if profile==0 else 0.0) and is_equal_approx(entry.mesh.get_blend_shape_value(entry.fuller),1.0 if profile==2 else 0.0),"same physique across body and clothing "+str(profile))
		for frame in 180:
			actor.travel_position+=Vector3.FORWARD*(1.15/60.0);actor.travel_gait_time+=1.0/60.0;actor.tick_routine(1.0/60.0)
		var peak: float=actor.secondary_motion.peak_displacement_m;peaks.append(peak)
		check(peak>.0001 and peak<=actor.secondary_motion.limit_m()+.00001,"walking drives bounded secondary motion "+str(profile))
	check(peaks[0]<peaks[1] and peaks[1]<peaks[2],"individual mass changes supported walking response")
	actor.member_index=1;actor.sample(1.0)
	var foundation: MeshInstance3D=actor.find_child("Opaque fitted bra and thong foundation",true,false)
	check(foundation!=null,"opaque foundation retained")
	if foundation!=null:check_coherence(actor,body,foundation)
	actor.sample(1.0)
	check(actor.secondary_motion.peak_displacement_m==0.0,"sample/load reset has no stale impulse")
	actor.free()
	print("ADULT_SECONDARY_ASSET ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"issues":failures,"walking_peak_m":peaks}))
	quit(0 if failures.is_empty() else 1)

func cell(point: Vector3) -> Vector3i:
	return Vector3i(floori(point.x/.02),floori(point.y/.02),floori(point.z/.02))

func check_coherence(actor: Node3D, body: MeshInstance3D, foundation: MeshInstance3D) -> void:
	var rig: Skeleton3D=actor.skeleton
	var before_body:=posed_points(body,rig,0);var before_cloth:=posed_points(foundation,rig,0)
	var raw_body: PackedVector3Array=body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var raw_cloth: PackedVector3Array=foundation.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var cells: Dictionary={};var positions:=PackedVector3Array()
	for vertex in raw_body.size():
		var at:=body.to_global(raw_body[vertex]);positions.append(at)
		var key:=cell(at)
		if not cells.has(key):cells[key]=[]
		cells[key].append(vertex)
	for entry in actor.secondary_motion.entries:rig.set_bone_pose_position(entry.bone,Vector3(entry.neutral)+Vector3(.004,0,0))
	rig.force_update_all_bone_transforms()
	var after_body:=posed_points(body,rig,0);var after_cloth:=posed_points(foundation,rig,0)
	var compared:=0;var worst:=0.0
	for vertex in raw_cloth.size():
		var movement:=after_cloth[vertex]-before_cloth[vertex]
		if movement.length()<.00001:continue
		var at:=foundation.to_global(raw_cloth[vertex]);var key:=cell(at);var nearest: int=-1;var error:=INF
		for x in range(-1,2):
			for y in range(-1,2):
				for z in range(-1,2):
					for index: int in cells.get(key+Vector3i(x,y,z),[]):
						# Match the authored three-millimetre foundation offset;
						# UV seam duplicates have the same physical skin weights.
						var distance_error:=absf(at.distance_to(positions[index])-.003)
						if distance_error<error:error=distance_error;nearest=index
		if nearest<0 or error>.00002:continue
		compared+=1;worst=maxf(worst,movement.distance_to(after_body[nearest]-before_body[nearest]))
	check(compared>=30,"sufficient actual influenced body/foundation pairs")
	check(worst<.00005,"body and foundation move together within0.05mm: "+str(worst))
	print("SECONDARY_COHERENCE ",JSON.stringify({"pairs":compared,"maximum_difference_m":worst}))
