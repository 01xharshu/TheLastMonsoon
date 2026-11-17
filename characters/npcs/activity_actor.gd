extends "res://characters/npcs/indian/indian_street_actor.gd"
## Existing complete adult MPFB body, personal work graph and reusable face shapes.
const SeatProfiles = preload("res://characters/npcs/activity_people/seat_profiles.gd")
const SeatCache = preload("res://characters/npcs/activity_seat_hash_cache.gd")
const SEATED_WORK := ["repair", "shape", "read", "write"]
var activity := "idle"
var retained_seat_support := false
var rising_from_seat := false
var activity_age := 0.0
var outfit_correctives: RefCounted
var face_entries: Array[Dictionary] = []
var activities := {"repair":0,"shape":1,"read":2,"write":3,"teach":4,"talk":5,"listen":6,"cower":7,"guard":8,"stumble":9,"push":10}
var incoming: Array[Quaternion] = []
var incoming_pelvis := Vector3.ZERO
var seat_height := .45
var seat_foot_forward := .35
var seat_foot_half_width := .17
var seat_foot_yaw := 0.0
var seat_samples: Array[Dictionary] = []
var seat_body: MeshInstance3D

func _ready() -> void:
	set_meta("adult_character",true)
	super._ready()
	prepare_seat_samples()
	for mesh: MeshInstance3D in find_children("*","MeshInstance3D",true,false):
		var indices: Array[int] = []
		for label in ["activity_speech","activity_fear","activity_blink"]:
			indices.append(mesh.find_blend_shape_by_name(label))
		if indices[0]>=0: face_entries.append({"mesh":mesh,"indices":indices})
	var graph := animation_tree.tree_root as AnimationNodeBlendTree
	var library := AnimationLibrary.new()
	var states := AnimationNodeBlendSpace1D.new()
	states.min_space=0;states.max_space=10
	states.blend_mode=AnimationNodeBlendSpace1D.BLEND_MODE_DISCRETE
	for label: String in activities:
		library.add_animation(label,work_clip(label))
		var point := AnimationNodeAnimation.new();point.animation="activity/"+label
		states.add_blend_point(point,float(activities[label]),-1,label)
	animation_player.add_animation_library("activity",library)
	graph.add_node("activity_pose",states)
	graph.add_node("activity_seek",AnimationNodeTimeSeek.new())
	graph.add_node("work_pose",AnimationNodeBlend2.new())
	graph.disconnect_node("output",0)
	graph.connect_node("work_pose",0,"turning")
	graph.connect_node("activity_seek",0,"activity_pose")
	graph.connect_node("work_pose",1,"activity_seek")
	graph.connect_node("output",0,"work_pose")

func work_clip(label: String) -> Animation:
	var clip := Animation.new();clip.length=4.0;clip.loop_mode=Animation.LOOP_LINEAR
	for bone: String in ["spine_02","head","upperarm_l","upperarm_r","lowerarm_l","lowerarm_r","thigh_l","thigh_r","calf_l","calf_r"]:
		var index := _skeleton.find_bone(bone)
		if index<0:continue
		var track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track,NodePath(str(get_path_to(_skeleton))+":"+bone))
		for sample in 33:
			var time := float(sample)/32.0*4.0
			var wave := sin(time*TAU/2.0)
			var pitch := 0.0;var yaw := 0.0
			if label in ["repair","shape","read","write"]:
				if bone.begins_with("thigh_"):pitch=-1.35
				if bone.begins_with("calf_"):pitch=1.5
				if bone=="spine_02":pitch=.09 if label=="shape" else .04
				if bone=="head":pitch=.16
			if label in ["repair","shape","read","write","push"]:
				if bone.begins_with("upperarm_"):pitch=-.45
				if bone.begins_with("lowerarm_"):pitch=-.85
				if label=="repair" and bone=="upperarm_r":pitch+=.12*wave
			if label in ["teach","talk","listen"]:
				if bone=="head":pitch=.025*sin(time*2.4);yaw=.04*sin(time*.7)
				if label!="listen" and bone=="upperarm_r":pitch=-.35-.09*wave;yaw=.10
				if label!="listen" and bone=="lowerarm_r":pitch=-1.05-.12*wave
			if label in ["cower","guard","stumble"]:
				if bone=="spine_02":pitch=-.15 if label=="stumble" else .16
				if bone=="head":pitch=-.12
				if bone.begins_with("upperarm_"):pitch=-1.05
				if bone.begins_with("lowerarm_"):pitch=-1.65
			var rest: Quaternion = _base_rotations.get(bone,_skeleton.get_bone_pose_rotation(index))
			var axis: Vector3 = _pitch_axes.get(bone,Vector3.RIGHT)
			var yaw_axis: Vector3 = _yaw_axes.get(bone,Vector3.UP)
			clip.rotation_track_insert_key(track,time,rest*Quaternion(axis,pitch)*Quaternion(yaw_axis,yaw))
	return clip

func perform(label: String, delta: float, speaking := false, fear := 0.0) -> void:
	var seated := label in SEATED_WORK
	if label!=activity:
		var was_seated := activity in SEATED_WORK
		rising_from_seat = was_seated and not seated
		retained_seat_support = seated and was_seated and (activity_age >= .65 or retained_seat_support)
		incoming.clear()
		for bone in _skeleton.get_bone_count():incoming.append(_skeleton.get_bone_pose_rotation(bone))
		incoming_pelvis=_skeleton.get_bone_pose_position(_skeleton.find_bone("pelvis"))
		activity=label;activity_age=0.0;foot_plant.clear()
	activity_age+=maxf(delta,0.0)
	var combat := get_node_or_null("CombatMotion")
	if get_meta("dead",false) or get_meta("knocked_out",false) or (combat!=null and combat.state!=""):return
	_set_animation(&"idle",delta)
	animation_tree.set("parameters/work_pose/blend_amount",1.0 if activities.has(label) else 0.0)
	if activities.has(label):
		animation_tree.set("parameters/activity_pose/blend_position",float(activities[label]))
		animation_tree.set("parameters/activity_seek/seek_request",fposmod(activity_age,4.0))
		animation_tree.advance(0.0)
	# Seated work changes can blend the hands without lowering onto the same seat again.
	var seat_blend := 1.0 if retained_seat_support else smoothstep(0, .65, activity_age)
	var pelvis := _skeleton.find_bone("pelvis")
	if pelvis>=0:
		var base := _skeleton.get_bone_rest(pelvis).origin
		var parent := _skeleton.get_bone_parent(pelvis)
		var axis := _skeleton.get_bone_global_rest(parent).basis.inverse()*Vector3.DOWN if parent>=0 else Vector3.DOWN
		var target:=base+axis*(.48 if seated else 0.0)
		_skeleton.set_bone_pose_position(pelvis,incoming_pelvis.lerp(target,seat_blend) if not incoming.is_empty() else target)
	if activity_age<.65 and incoming.size()==_skeleton.get_bone_count():
		var blend:=smoothstep(0,.65,activity_age)
		for bone in incoming.size():
			if retained_seat_support and is_seat_support_bone(_skeleton.get_bone_name(bone)):
				continue
			_skeleton.set_bone_pose_rotation(bone, incoming[bone].slerp(_skeleton.get_bone_pose_rotation(bone), blend))
	if seated and not seat_samples.is_empty():
		var ankle_error:=0.0
		for iteration in 2:
			_skeleton.force_update_all_bone_transforms()
			var lowest:=seat_bottom()
			var correction: float=(global_position.y+seat_height-lowest)*seat_blend
			var parent:=_skeleton.get_bone_parent(pelvis)
			var frame:=_skeleton.global_basis*(_skeleton.get_bone_global_pose(parent).basis if parent>=0 else Basis.IDENTITY)
			_skeleton.set_bone_pose_position(pelvis,_skeleton.get_bone_pose_position(pelvis)+frame.inverse()*Vector3.UP*correction)
			for side in ["l","r"]:
				var footprint:=Vector3(seat_foot_half_width if side=="l" else -seat_foot_half_width,0,seat_foot_forward)
				var target:=to_global(footprint.rotated(Vector3.UP,seat_foot_yaw))
				target.y=(float(ground_height.call(target.x,target.z)) if ground_height.is_valid() else global_position.y)+.07
				foot_plant._solve(foot_plant.legs[side],_skeleton.to_local(target))
				if iteration==1:
					var ankle_bone:=_skeleton.find_bone("foot_"+side)
					if not is_zero_approx(seat_foot_yaw):
						var foot_pose:=_skeleton.get_bone_global_pose(ankle_bone)
						var parent_pose:=_skeleton.get_bone_global_pose(_skeleton.get_bone_parent(ankle_bone))
						var turned:=parent_pose.basis.inverse()*Basis(Vector3.UP,seat_foot_yaw)*foot_pose.basis
						_skeleton.set_bone_pose_rotation(ankle_bone,turned.orthonormalized().get_rotation_quaternion())
					var ankle:=_skeleton.to_global(_skeleton.get_bone_global_pose(ankle_bone).origin)
					ankle_error=maxf(ankle_error,ankle.distance_to(target))
		set_meta("seat_error",absf(seat_bottom()-(global_position.y+seat_height)))
		set_meta("seated_ankle_error",ankle_error)
	elif rising_from_seat and activity_age < .65 and not seat_samples.is_empty():
		support_rising_feet()
	var age := activity_age
	var lips := (.25+.40*pow(sin(age*11.7),2)) if speaking and fposmod(age,2.6)<2.1 else 0.0
	var blink := preload("res://story/dialogue_expression.gd").blink_weight(age,float(get_instance_id()%17)*.27)
	for entry in face_entries:
		for pair in [[0,lips],[1,fear],[2,blink]]:
			if entry.indices[pair[0]]>=0:entry.mesh.set_blend_shape_value(entry.indices[pair[0]],pair[1])
	set_meta("activity",label)
	set_meta("speaking",speaking)
	set_meta("fear",fear)

func finish_contacts() -> void:
	if outfit_correctives != null: outfit_correctives.update()
	if drape!=null and DisplayServer.get_name()!="headless":drape.update()

func support_rising_feet() -> void:
	_skeleton.force_update_all_bone_transforms()
	for side in ["l", "r"]:
		var leg: Array = foot_plant.legs[side]
		var ankle: int = leg[2]
		var standing := _skeleton.get_bone_global_rest(ankle)
		var target := _skeleton.to_global(_skeleton.get_bone_global_pose(ankle).origin)
		var ground := float(ground_height.call(target.x, target.z)) if ground_height.is_valid() else global_position.y
		var supported_height := ground + _skeleton.to_global(standing.origin).y - global_position.y
		if target.y >= supported_height:
			continue
		target.y = supported_height
		foot_plant._solve(leg, _skeleton.to_local(target))
		var parent_pose := _skeleton.get_bone_global_pose(_skeleton.get_bone_parent(ankle))
		var foot_basis := parent_pose.basis.inverse() * standing.basis
		_skeleton.set_bone_pose_rotation(ankle, foot_basis.orthonormalized().get_rotation_quaternion())

func is_seat_support_bone(label: StringName) -> bool:
	return label == &"pelvis" or label.begins_with("thigh_") or label.begins_with("calf_") or label.begins_with("foot_") or label.begins_with("toe_")

func prepare_seat_samples() -> void:
	var hip:=to_local(_skeleton.to_global(_skeleton.get_bone_global_pose(_skeleton.find_bone("pelvis")).origin))
	for node: MeshInstance3D in find_children("*","MeshInstance3D",true,false):
		if "makehuman_body" not in str(node.name).to_lower() or node.skin==null:continue
		seat_body=node
		if load_seat_profile(node):
			return
		var palette:=seat_palette()
		for surface in node.mesh.get_surface_count():
			var arrays:=node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
			var slots:=bones.size()/vertices.size()
			for index in vertices.size():
				var point:=Vector3.ZERO;var pelvis_weight:=0.0
				var bindings: Array[Dictionary]=[]
				for slot in slots:
					var offset:=index*slots+slot
					if weights[offset]<=0:continue
					var bind:=bones[offset];var bone:=node.skin.get_bind_name(bind)
					if bone==&"pelvis":pelvis_weight+=weights[offset]
					point+=(palette[bind]*vertices[index])*weights[offset]
					bindings.append({"bind":bind,"weight":weights[offset]})
				var local:=to_local(point)
				if pelvis_weight>.45 and local.y>hip.y-.14 and local.y<hip.y-.025 and local.z<hip.z-.025 and absf(local.x-hip.x)<.19:
					seat_samples.append({"vertex":vertices[index],"bindings":bindings})
		return

func load_seat_profile(body: MeshInstance3D) -> bool:
	var owner_node := body.owner
	if owner_node == null:
		return false
	var path := owner_node.scene_file_path
	if not SeatProfiles.PROFILES.has(path) or not FileAccess.file_exists(path) or not FileAccess.file_exists(path + ".import"):
		return false
	if not SeatCache.hashes.has(path):
		SeatCache.hashes[path] = [FileAccess.get_sha256(path), FileAccess.get_sha256(path + ".import")]
	var profile: Dictionary = SeatProfiles.PROFILES[path]
	if SeatCache.hashes[path] != [profile.sha256, profile.import_sha256]:
		return false
	for sample in profile.samples:
		var vertex: Array = sample.vertex
		seat_samples.append({"vertex": Vector3(float(vertex[0]), float(vertex[1]), float(vertex[2])),
			"bindings": sample.bindings.duplicate(true)})
	set_meta("seat_profile_cached", true)
	return true

func seat_palette() -> Array[Transform3D]:
	var result: Array[Transform3D]=[]
	for bind in seat_body.skin.get_bind_count():
		var bone:=seat_body.skin.get_bind_bone(bind)
		if bone<0:bone=_skeleton.find_bone(seat_body.skin.get_bind_name(bind))
		result.append(_skeleton.global_transform*_skeleton.get_bone_global_pose(bone)*seat_body.skin.get_bind_pose(bind))
	return result

func seat_bottom() -> float:
	var palette:=seat_palette();var lowest:=INF
	for sample in seat_samples:
		var point:=Vector3.ZERO
		for binding in sample.bindings:point+=(palette[binding.bind]*sample.vertex)*binding.weight
		lowest=minf(lowest,point.y)
	return lowest

func solve_hand_contact(side: String, target_world: Vector3) -> void:
	var target:=_skeleton.to_local(target_world)
	for iteration in 32:
		for part in ["lowerarm_","upperarm_"]:
			var index:=_skeleton.find_bone(part+side)
			var current:=_skeleton.get_bone_global_pose(index)
			var palm:=_skeleton.to_local(palm_world(side))
			var from:=palm-current.origin;var to:=target-current.origin
			if from.length()<.001 or to.length()<.001:continue
			var orientation:=current.basis.get_rotation_quaternion()
			var correction:=Quaternion(from.normalized(),to.normalized())
			var local_delta:=orientation.inverse()*correction*orientation
			_skeleton.set_bone_pose_rotation(index,_skeleton.get_bone_pose_rotation(index)*local_delta)
			_skeleton.force_update_all_bone_transforms()
		if palm_world(side).distance_to(target_world)<.001:break
	set_meta("hand_contact_"+side,palm_world(side).distance_to(target_world))
