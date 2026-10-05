extends "res://characters/npcs/british/british_npc_actor.gd"
## Personal work branch overlays arms while retaining independent locomotion.
@export var household_job:String="resident"
func _ready() -> void:
	if not has_meta("combat_faction"): set_meta("combat_faction","indian")
	super._ready()
	var vitality := preload("res://combat/npc_vitality.gd").new()
	vitality.name = "Vitality"
	add_child(vitality)
	for node in find_children("*","MeshInstance3D",true,false):
		if household_job=="Coachman" and "kurta loose lower panel" in node.name.to_lower():node.hide()
		if household_job!="resident":continue
		for surface in node.mesh.get_surface_count():
			var original:=node.get_active_material(surface) as StandardMaterial3D
			if original==null:continue
			var label:=original.resource_name.to_lower()
			if not ("cotton" in label or "shawl" in label or "woven" in label or "waistcoat" in label or "ivory coat" in label):continue
			var woven:=ShaderMaterial.new();woven.shader=load("res://characters/npcs/households/household_cloth.gdshader")
			woven.set_shader_parameter("cloth_color",original.albedo_color)
			node.set_surface_override_material(surface,woven)
	if household_job not in ["Cook","WaterBearer"] or animation_tree==null:return
	var clip:=Animation.new();clip.length=2.8;clip.loop_mode=Animation.LOOP_LINEAR
	var skeleton_path:=str(get_path_to(_skeleton))
	var paths:Array[NodePath]=[]
	for side in ["l","r"]:
		for part in ["upperarm_","lowerarm_"]:
			var bone:String=part+side
			var path:=NodePath(skeleton_path+":"+bone);paths.append(path)
			var track:=clip.add_track(Animation.TYPE_ROTATION_3D);clip.track_set_path(track,path)
			for key in 17:
				var fraction:=float(key)/16
				var pitch:float=-.50 if part=="upperarm_" else -.9
				if household_job=="Cook":pitch+=sin(fraction*TAU)*.10
				clip.rotation_track_insert_key(track,fraction*clip.length,_base_rotations[bone]*Quaternion(_pitch_axes[bone],pitch))
	animation_player.get_animation_library("").add_animation("household_work",clip)
	var graph:=animation_tree.tree_root as AnimationNodeBlendTree
	var work:=AnimationNodeAnimation.new();work.animation=&"household_work"
	graph.add_node("household_work",work)
	var overlay:=AnimationNodeBlend2.new();overlay.filter_enabled=true
	for path in paths:overlay.set_filter_path(path,true)
	graph.add_node("work_pose",overlay)
	graph.disconnect_node("output",0)
	graph.connect_node("work_pose",0,"turning")
	graph.connect_node("work_pose",1,"household_work")
	graph.connect_node("output",0,"work_pose")
	animation_tree.set("parameters/work_pose/blend_amount",1.0)
	animation_tree.advance(0.0)

func _process(delta:float) -> void:
	if get_meta("dead",false) or get_meta("knocked_out",false): return
	super._process(delta)
	if household_job=="WaterBearer" and _skeleton!=null:
		var pot:=get_node_or_null("CarriedWaterPot") as Node3D
		if pot!=null:
			# Keep the vessel at the torso and solve each hand to its side.
			pot.position=Vector3(0,.92,.36)
			for side in ["l","r"]:
				var contact:=pot.to_global(Vector3(.135 if side=="l" else -.135,.035,0))
				solve_hand_contact(side,contact)
				set_grip(side,.45)

func palm_world(side:String) -> Vector3:
	var pose:=_skeleton.get_bone_global_pose(_skeleton.find_bone("hand_"+side))
	return _skeleton.to_global(pose*Vector3(0,.055,0))

func solve_hand_contact(side:String,target_world:Vector3) -> void:
	var target:=_skeleton.to_local(target_world)
	for iteration in 18:
		for part in ["lowerarm_","upperarm_"]:
			var index:=_skeleton.find_bone(part+side)
			var current:=_skeleton.get_bone_global_pose(index)
			var palm:=_skeleton.to_local(palm_world(side))
			var from_direction:=(palm-current.origin).normalized()
			var to_direction:=(target-current.origin).normalized()
			var desired:=Basis(Quaternion(from_direction,to_direction))*current.basis
			var parent:=_skeleton.get_bone_parent(index)
			if parent>=0:desired=_skeleton.get_bone_global_pose(parent).basis.inverse()*desired
			_skeleton.set_bone_pose_rotation(index,desired.orthonormalized().get_rotation_quaternion())
			_skeleton.force_update_all_bone_transforms()
		if palm_world(side).distance_to(target_world)<.001:break
	set_meta("hand_contact_"+side,palm_world(side).distance_to(target_world))

func set_grip(side:String,strength:float) -> void:
	for index in _finger_rest:
		var label:=_skeleton.get_bone_name(index)
		if not label.ends_with("_"+side):continue
		var curl:=strength if "_01_" in label else (strength*1.15 if "_02_" in label else strength*.5)
		if label.begins_with("thumb"):curl*=.55
		_skeleton.set_bone_pose_rotation(index,_finger_rest[index]*Quaternion(_finger_pitch[index],curl))

func take_damage(amount: float) -> void:
	var vitality := get_node_or_null("Vitality")
	if vitality != null: vitality.take_damage(amount)
