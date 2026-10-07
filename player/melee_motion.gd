extends RefCounted
## Rig-space action curves: anticipation, contact, follow-through and recovery.
static func make(rig: Skeleton3D, idle: Animation, action: String) -> Animation:
	var clip := Animation.new()
	clip.length = .45 if action == "hit" else .42 if action == "dodge" else .5 if action == "block" else .68 if action == "sword" else .55 if action == "knife" else 1.2 if action == "grapple" else .52 if action in ["kick","jump_kick"] else .42
	var bones := ["pelvis","spine_01","spine_02","head","upperarm_l","upperarm_r","lowerarm_l","lowerarm_r","thigh_l","thigh_r","calf_l","calf_r","foot_l","foot_r"]
	for side in ["l","r"]:
		for finger in ["index","middle","ring","pinky","thumb"]:
			for joint in ["01","02","03"]:bones.append(finger+"_"+joint+"_"+side)
	for bone in bones:
		var index := rig.find_bone(bone)
		if index < 0: continue
		var path := NodePath("Arjun_Rig/Skeleton3D:"+bone)
		var source := idle.find_track(path,Animation.TYPE_ROTATION_3D)
		var base: Quaternion = idle.track_get_key_value(source,0) if source >= 0 else rig.get_bone_pose_rotation(index)
		var axes := rig.get_bone_global_rest(index).basis.orthonormalized().inverse()
		var track := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track,path)
		for sample in 33:
			var phase := float(sample)/32.0
			var recover := 1.0-smoothstep(.58,1.0,phase)
			var effort := smoothstep(0.0,.22,phase)*recover
			var strike := smoothstep(.25,.43,phase)
			var angles: Dictionary
			if action == "hit":
				angles={"spine_01":Vector3(-.22,0,.10),"spine_02":Vector3(-.25,0,0),"head":Vector3(-.12,0,0),"upperarm_l":Vector3(-.55,0,.3),"upperarm_r":Vector3(-.5,0,-.3)}
				effort=sin(phase*PI)
			elif action == "block":
				angles={"spine_02":Vector3(.08,0,0),"upperarm_l":Vector3(-1.25,0,.15),"upperarm_r":Vector3(-1.2,0,-.15),"lowerarm_l":Vector3(-1.3,0,0),"lowerarm_r":Vector3(-1.3,0,0)}
				effort=1.0
			elif action == "dodge":
				angles={"pelvis":Vector3(.2,0,-.15),"spine_01":Vector3(.25,0,-.2),"thigh_l":Vector3(-.5,0,.2),"calf_l":Vector3(.8,0,0),"thigh_r":Vector3(.3,0,-.2),"calf_r":Vector3(.4,0,0),"upperarm_l":Vector3(-.6,0,.35),"upperarm_r":Vector3(-.5,0,-.4)}
				effort=sin(phase*PI)
			elif action == "knife":
				angles={"spine_01":Vector3(.28,.10*strike,0),"spine_02":Vector3(.12,.18*strike,0),"upperarm_r":Vector3(lerpf(-.55,-1.62,strike),0,.35),"lowerarm_r":Vector3(lerpf(-1.35,-.08,strike),0,0),"upperarm_l":Vector3(-.48,0,.42),"lowerarm_l":Vector3(-.9,0,0)}
			elif action == "sword":
				var sweep:=smoothstep(.18,.72,phase)
				effort=smoothstep(0,.12,phase)*(1.0-smoothstep(.76,1.0,phase))
				angles={"spine_02":Vector3(-.1,lerpf(-.25,.38,sweep),0),"upperarm_r":Vector3(lerpf(-1.15,.35,sweep),lerpf(-.65,.65,sweep),lerpf(-.6,.1,sweep)),"lowerarm_r":Vector3(lerpf(-1.15,-.4,sweep),0,0),"upperarm_l":Vector3(-.5,0,.35),"lowerarm_l":Vector3(-.7,0,0)}
			elif action == "grapple":
				angles={"spine_01":Vector3(.28,0,0),"spine_02":Vector3(.12,0,0),"upperarm_l":Vector3(-1.2,0,.15),"upperarm_r":Vector3(-1.2,0,-.15),"lowerarm_l":Vector3(-1.25,0,0),"lowerarm_r":Vector3(-1.25,0,0)}
				effort=smoothstep(0,.25,phase)*(1.0-smoothstep(.82,1.0,phase))
			elif action in ["kick","jump_kick"]:
				var extension := smoothstep(.28,.46,phase)
				angles = {"pelvis":Vector3(-.12,-.10,-.10),"spine_01":Vector3(.20,0,.08),"spine_02":Vector3(.12,0,0),"thigh_r":Vector3(-1.2,0,0),"calf_r":Vector3(lerpf(1.15,.12,extension),0,0),"foot_r":Vector3(-.18,0,0),"thigh_l":Vector3(-.6 if action=="jump_kick" else .14,0,0),"calf_l":Vector3(.8 if action=="jump_kick" else .14,0,0),"upperarm_l":Vector3(-.55,0,.48),"upperarm_r":Vector3(-.42,0,-.4)}
			else:
				var left := action == "punch_left"
				var hand := "l" if left else "r"
				var guard := "r" if left else "l"
				var sign_side := -1.0 if left else 1.0
				angles = {"pelvis":Vector3(.08,.16*strike*sign_side,0),"spine_01":Vector3(.28,.10*strike*sign_side,0),"spine_02":Vector3(.12,.18*strike*sign_side,0)}
				angles["upperarm_"+hand]=Vector3(lerpf(-.55,-1.62,strike),0,.35*sign_side)
				angles["lowerarm_"+hand]=Vector3(lerpf(-1.35,-.08,strike),0,0)
				angles["upperarm_"+guard]=Vector3(-.48,0,.42*sign_side)
				angles["lowerarm_"+guard]=Vector3(-.9,0,0)
			var angle: Vector3 = angles.get(bone,Vector3.ZERO)*effort
			if bone.begins_with("index_") or bone.begins_with("middle_") or bone.begins_with("ring_") or bone.begins_with("pinky_") or bone.begins_with("thumb_"):
				angle=Vector3(.5 if bone.begins_with("thumb_") else .95,0,0)*effort
				axes=Basis.IDENTITY
			clip.rotation_track_insert_key(track,phase*clip.length,base*Quaternion(axes*Vector3.RIGHT,angle.x)*Quaternion(axes*Vector3.UP,angle.y)*Quaternion(axes*Vector3.BACK,angle.z))
	return clip
