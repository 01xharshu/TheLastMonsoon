extends RefCounted
## Filtered firearm torso poses; hands solve against the weapon after evaluation.

static func configure(graph: AnimationNodeBlendTree, library: AnimationLibrary, rig: Skeleton3D, idle: Animation) -> void:
	var poses := {
		"pistol_aim": {"spine_02": Vector3(-0.035,-0.035,0.0), "head": Vector3(0.025,-0.025,0.0)},
		"pistol_reload": {"spine_02": Vector3(0.04,0.0,0.0), "head": Vector3(0.20,-0.04,0.0)},
		"pistol_recoil": {"spine_02": Vector3(0.035,-0.035,0.0), "head": Vector3(0.045,-0.025,0.0)}
	}
	var previous := "longgun_aim"
	for name in ["pistol_aim","pistol_reload","pistol_recoil"]:
		var clip := Animation.new()
		clip.length = 0.5
		clip.loop_mode = Animation.LOOP_LINEAR
		var layer := AnimationNodeBlend2.new()
		layer.filter_enabled = true
		for bone: String in poses[name]:
			var path := NodePath("Arjun_Rig/Skeleton3D:"+bone)
			var index := rig.find_bone(bone)
			if index < 0: continue
			var track := clip.add_track(Animation.TYPE_ROTATION_3D)
			clip.track_set_path(track,path)
			var source_track := idle.find_track(path,Animation.TYPE_ROTATION_3D)
			var base: Quaternion = idle.track_get_key_value(source_track,0) if source_track >= 0 else rig.get_bone_pose_rotation(index)
			var axes := rig.get_bone_global_rest(index).basis.orthonormalized().inverse()
			var angle: Vector3 = poses[name][bone]
			var rotation := base*Quaternion(axes*Vector3.RIGHT,angle.x)*Quaternion(axes*Vector3.UP,angle.y)
			clip.rotation_track_insert_key(track,0.0,rotation)
			clip.rotation_track_insert_key(track,clip.length,rotation)
			layer.set_filter_path(path,true)
		library.add_animation(name,clip)
		var animation := AnimationNodeAnimation.new()
		animation.animation = "motion/"+name
		graph.add_node(name+"_pose",animation)
		graph.add_node(name,layer)
		graph.connect_node(name,0,previous)
		graph.connect_node(name,1,name+"_pose")
		previous = name

static func clear(tree: AnimationTree) -> void:
	for name in ["pistol_aim","pistol_reload","pistol_recoil"]:
		tree.set("parameters/"+name+"/blend_amount",0.0)
