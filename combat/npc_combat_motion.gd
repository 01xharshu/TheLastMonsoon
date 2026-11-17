extends Node
## Small per-actor tree branch. Clips and graph are built once, never per attack.
var actor: Node3D
var state := ""
var age := 0.0
var duration := .65
var down_drop := .72
var fall_cloth: Array[Dictionary]=[]
var cloth_weight: float=-1
var tracked_bones: Array[int]=[]
var incoming_rotations: Dictionary={}
var incoming_pelvis:=Vector3.ZERO
var pelvis_bone: int=-1
var indices := {"hit":0,"strike":1,"fall":2,"down":3,"rise":4,"held":5,"slap":6}
func _ready() -> void:
	actor = get_parent()
	process_priority = 10
	var rig: Skeleton3D=actor._skeleton
	pelvis_bone=rig.find_bone("pelvis")
	for name in ["pelvis","spine_01","spine_02","neck_01","head","upperarm_l","upperarm_r","lowerarm_l","lowerarm_r","thigh_l","thigh_r","calf_l","calf_r"]:
		var index:=rig.find_bone(name)
		if index>=0:tracked_bones.append(index)
	var hip:=rig.to_global(rig.get_bone_global_pose(rig.find_bone("pelvis")).origin)
	# Each imported adult has its own hip height; settle the pelvis near the floor.
	down_drop=maxf(.35,actor.to_local(hip).y-.145)
	for mesh in actor.find_children("*", "MeshInstance3D", true, false):
		var corrective: int=mesh.find_blend_shape_by_name("Knockdown cotton compression")
		if corrective>=0:
			mesh.set_blend_shape_value(corrective,0.0)
			fall_cloth.append({"mesh":mesh,"index":corrective})
	var graph := actor.animation_tree.tree_root as AnimationNodeBlendTree
	var library := AnimationLibrary.new()
	for action in indices: library.add_animation(action,make_clip(action))
	actor.animation_player.add_animation_library("combat",library)
	var states := AnimationNodeBlendSpace1D.new()
	states.min_space=0; states.max_space=indices.size()-1
	states.blend_mode=AnimationNodeBlendSpace1D.BLEND_MODE_DISCRETE
	for action in indices:
		var node := AnimationNodeAnimation.new()
		node.animation="combat/"+action
		states.add_blend_point(node,float(indices[action]),-1,action)
	graph.add_node("combat_pose",states)
	graph.add_node("combat_seek",AnimationNodeTimeSeek.new())
	graph.add_node("combat",AnimationNodeBlend2.new())
	graph.disconnect_node("output",0)
	graph.connect_node("combat",0,"work_pose" if graph.has_node("work_pose") else "turning")
	graph.connect_node("combat_seek",0,"combat_pose")
	graph.connect_node("combat",1,"combat_seek")
	graph.connect_node("output",0,"combat")
	set_process(false)

func make_clip(action: String) -> Animation:
	var clip := Animation.new()
	clip.length=1.0
	var rig: Skeleton3D=actor._skeleton
	for bone in ["pelvis","spine_01","spine_02","neck_01","head","upperarm_l","upperarm_r","lowerarm_l","lowerarm_r","thigh_l","thigh_r","calf_l","calf_r"]:
		var index:=rig.find_bone(bone)
		if index<0:continue
		var rest: Quaternion=actor._base_rotations.get(bone,rig.get_bone_pose_rotation(index))
		var axes:=rig.get_bone_global_pose(index).basis.orthonormalized().inverse()
		var track:=clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track,NodePath(str(actor.get_path_to(rig))+":"+bone))
		for sample in 25:
			var t:=float(sample)/24
			var pulse:=sin(t*PI)
			var settle:=smoothstep(0,1,t)
			var angles: Dictionary={}
			match action:
				"hit": angles={"spine_02":Vector3(-.35,0,.12)*pulse,"head":Vector3(-.25,0,0)*pulse,"upperarm_l":Vector3(-.8,0,.3)*pulse,"upperarm_r":Vector3(-.65,0,-.3)*pulse,"calf_l":Vector3(.25,0,0)*pulse}
				"strike":
					# Load the rear shoulder first, transfer through the hips and
					# torso at contact, then return smoothly to the prior pose.
					var effort:=smoothstep(0.0,.16,t)*(1.0-smoothstep(.64,1.0,t))
					var extension:=smoothstep(.25,.46,t)
					var twist:=lerpf(-.10,.20,extension)
					angles={"pelvis":Vector3(.04,twist*.5,-.035)*effort,"spine_01":Vector3(.12,twist*.6,0)*effort,"spine_02":Vector3(.10,twist,0)*effort,"head":Vector3(-.04,-twist*.35,0)*effort,"upperarm_r":Vector3(lerpf(-.65,-1.62,extension),0,.35)*effort,"lowerarm_r":Vector3(lerpf(-1.2,-.12,extension),0,0)*effort,"upperarm_l":Vector3(-.55,0,.3)*effort,"lowerarm_l":Vector3(-.8,0,0)*effort,"thigh_l":Vector3(-.10,0,0)*effort,"thigh_r":Vector3(.08,0,0)*effort,"calf_l":Vector3(.16,0,0)*effort,"calf_r":Vector3(.12,0,0)*effort}
				"slap":
					var effort:=smoothstep(0.0,.18,t)*(1.0-smoothstep(.65,1.0,t))
					var sweep:=smoothstep(.18,.48,t)
					angles={"spine_01":Vector3(.035,lerpf(-.15,.14,sweep),0)*effort,"spine_02":Vector3(.06,lerpf(-.22,.26,sweep),0)*effort,"head":Vector3(0,-.08,0)*effort,"upperarm_r":Vector3(lerpf(-.65,-1.45,sweep),lerpf(-.65,.65,sweep),.32)*effort,"lowerarm_r":Vector3(lerpf(-1.0,-.12,sweep),0,0)*effort,"upperarm_l":Vector3(-.45,0,.2)*effort,"lowerarm_l":Vector3(-.7,0,0)*effort}
				"held": angles={"head":Vector3(0,.18*smoothstep(.4,1,t),0),"spine_02":Vector3(-.12,0,0),"upperarm_l":Vector3(-1.2,0,-.55),"upperarm_r":Vector3(-1.2,0,.55),"lowerarm_l":Vector3(-2.1,0,0),"lowerarm_r":Vector3(-2.1,0,0)}
				"fall","down","rise":
					var amount:=1.0 if action=="down" else (1.0-settle if action=="rise" else settle)
					angles={"pelvis":Vector3(-PI*.5,0,0)*amount,"spine_02":Vector3(-.095,0,0)*amount,"neck_01":Vector3(-.13,0,0)*amount,"thigh_l":Vector3(-.3,0,0)*amount,"thigh_r":Vector3(-.18,0,0)*amount,"calf_l":Vector3(.5,0,0)*amount,"calf_r":Vector3(.3,0,0)*amount,"upperarm_l":Vector3(.15,0,.3)*amount,"upperarm_r":Vector3(.12,0,-.35)*amount,"lowerarm_l":Vector3(.25,0,0)*amount,"lowerarm_r":Vector3(.25,0,0)*amount}
			var angle: Vector3=angles.get(bone,Vector3.ZERO)
			if action=="held":angle*=smoothstep(0,.3,t)
			clip.rotation_track_insert_key(track,t,rest*Quaternion(axes*Vector3.RIGHT,angle.x)*Quaternion(axes*Vector3.UP,angle.y)*Quaternion(axes*Vector3.BACK,angle.z))
		if bone=="pelvis" and action in ["fall","down","rise"]:
			var position_track:=clip.add_track(Animation.TYPE_POSITION_3D)
			clip.track_set_path(position_track,NodePath(str(actor.get_path_to(rig))+":"+bone))
			var base:=rig.get_bone_pose_position(index)
			var parent:=rig.get_bone_parent(index)
			var axis:=rig.get_bone_global_rest(parent).basis.inverse()*Vector3.DOWN if parent>=0 else Vector3.DOWN
			for sample in 25:
				var t:=float(sample)/24
				var amount:=1.0 if action=="down" else (1.0-smoothstep(0,1,t) if action=="rise" else smoothstep(0,1,t))
				clip.position_track_insert_key(position_track,t,base+axis*down_drop*amount)
	return clip

func play(action: String) -> void:
	if not indices.has(action):return
	var rig: Skeleton3D=actor._skeleton
	incoming_rotations.clear()
	for index in tracked_bones:incoming_rotations[index]=rig.get_bone_pose_rotation(index)
	incoming_pelvis=rig.get_bone_pose_position(pelvis_bone)
	var overlay:=actor.animation_tree.tree_root.get_node("combat") as AnimationNodeBlend2
	overlay.filter_enabled=action=="hit" and float(actor.travel_speed)>1.5
	if overlay.filter_enabled:
		for bone in ["spine_01","spine_02","neck_01","head","upperarm_l","upperarm_r","lowerarm_l","lowerarm_r"]:
			overlay.set_filter_path(NodePath(str(actor.get_path_to(rig))+":"+bone),true)
	state=action; age=0
	set_process(true);actor.animation_tree.active=true
	actor.get_node("Vitality").set_physics_process(true)
	duration=1.0 if action in ["fall","rise"] else .65
	actor.set_meta("combat_action",state)
	actor.travel_speed=0

func _process(delta: float) -> void:
	if state=="":return
	age+=delta
	if state in ["fall","down","rise"]:
		var amount: float=1.0 if state=="down" else (1.0-smoothstep(0,1,minf(age/duration,1)) if state=="rise" else smoothstep(0,1,minf(age/duration,1)))
		if not is_equal_approx(amount,cloth_weight):
			for garment in fall_cloth:garment.mesh.set_blend_shape_value(garment.index,amount)
			cloth_weight=amount
	actor.animation_tree.set("parameters/combat/blend_amount",1.0)
	actor.animation_tree.set("parameters/combat_pose/blend_position",float(indices[state]))
	actor.animation_tree.set("parameters/combat_seek/seek_request",minf(age/duration,1.0))
	# Apply the requested tree pose after the actor update, then ease from the
	# preceding reaction so held-to-fall and strike-to-hit cannot snap to idle.
	actor.animation_tree.advance(delta if actor.get_meta("dead",false) or actor.get_meta("knocked_out",false) else 0.0)
	if age<.16:
		var rig: Skeleton3D=actor._skeleton
		var weight:=smoothstep(0,.16,age)
		for index in tracked_bones:
			rig.set_bone_pose_rotation(index,(incoming_rotations[index] as Quaternion).slerp(rig.get_bone_pose_rotation(index),weight))
		rig.set_bone_pose_position(pelvis_bone,incoming_pelvis.lerp(rig.get_bone_pose_position(pelvis_bone),weight))
	if state=="hit":apply_impact_direction()
	if state=="slap":
		if actor.has_method("solve_hand_with_elbow"):
			actor.solve_hand_with_elbow("l",actor.to_global(Vector3(.30,1.30,.35)),actor.to_global(Vector3(.48,1.12,.20)))
			var reaction:Node=actor.get_node_or_null("CivilianReaction")
			if age>=.16 and age<=.42:
				var target:Vector3=actor.to_global(Vector3(-.10,1.40,.65))
				if reaction!=null and is_instance_valid(reaction.source):
					var height:=.6 if reaction.source is CharacterBody3D else 1.25
					target=reaction.source.global_position+Vector3.UP*height
					var receiver:Node=reaction.source.get_node_or_null("Vitality")
					if receiver!=null:
						var head_shape=receiver.get("head_shape")
						if head_shape is CollisionShape3D:target=head_shape.global_position
				actor.solve_hand_with_elbow("r",target,actor.to_global(Vector3(-.48,1.12,.20)))
		for finger: int in actor._finger_rest:
			if actor._skeleton.get_bone_name(finger).ends_with("_r"):
				actor._skeleton.set_bone_pose_rotation(finger,actor._finger_rest[finger])

	if actor.has_method("update_combat_clothing"):actor.update_combat_clothing(state)

	if age>=duration:
		if state=="fall": play("down")
		elif state not in ["down","held"]:
			state="";actor.set_meta("combat_action","");actor.animation_tree.set("parameters/combat/blend_amount",0.0);set_process(false)
			if actor.has_method("update_combat_clothing"):actor.update_combat_clothing("")

	if state=="down" and age>duration+1.0:
		actor.animation_tree.active=false
		actor.get_node("Vitality").set_physics_process(false)
		set_process(false)

func apply_impact_direction() -> void:
	if not actor.has_meta("impact_context"):return
	var impact: Dictionary=actor.get_meta("impact_context")
	var direction: Vector3=actor.global_basis.inverse()*impact.direction
	var weight: float=sin(clampf(age/duration,0,1)*PI)*float(impact.strength)
	var kind: String=impact.kind
	var force := .34 if kind=="spear" else .28 if kind=="sword" else .18 if kind=="arrow" else .22
	var rig: Skeleton3D=actor._skeleton
	for bone in ["spine_01","spine_02","head"]:
		var index: int=rig.find_bone(bone)
		if index<0:continue
		var axes := rig.get_bone_global_rest(index).basis.orthonormalized().inverse()
		var head: int=rig.find_bone("head")
		var head_contact: bool=head>=0 and rig.to_global(rig.get_bone_global_pose(head).origin).distance_to(impact.point)<.32
		var scale := .6 if bone=="spine_01" else (1.0 if head_contact else .5) if bone=="head" else 1.0
		var turn: float=direction.x*(.25 if kind=="sword" else .1)
		var delta := Quaternion(axes*Vector3.RIGHT,direction.z*force*weight*scale)*Quaternion(axes*Vector3.UP,turn*weight*scale)*Quaternion(axes*Vector3.BACK,-direction.x*force*weight*scale)
		rig.set_bone_pose_rotation(index,rig.get_bone_pose_rotation(index)*delta)
