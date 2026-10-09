extends SceneTree
const Actor=preload("res://characters/npcs/households/household_npc_actor.gd")
const Humans=preload("res://characters/human_scene.gd")
const ActorReference=preload("res://tools/characters/npc_frame_work_reference.gd")
var failed:=false
var checked_poses:=0
func check(ok:bool,label:String)->void:
	if not ok and not failed:failed=true;push_error(label)
func _initialize()->void:_run.call_deferred()
func create_actor(path:String,profile:StringName,reference:bool)->Node3D:
	var actor:Node3D=(ActorReference if reference else Actor).new();actor.movement_enabled=false;actor.movement_profile=profile
	actor.add_child(Humans.instantiate(path));root.add_child(actor);actor.set_process(false)
	return actor
func _run()->void:
	var viewport:=SubViewport.new();viewport.size=Vector2i(480,640);viewport.world_3d=root.world_3d
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
	var camera:=Camera3D.new();viewport.add_child(camera);camera.position=Vector3(1.6,1.15,3);camera.look_at(Vector3(0,.9,0));camera.current=true
	var light:=DirectionalLight3D.new();root.add_child(light);light.rotation_degrees=Vector3(-35,-25,0);root.disable_3d=true
	for spec in [["village_farmer",&"male"],["village_woman",&"female"],["errand_passenger",&"male"]]:
		var path: String="res://characters/npcs/motion/%s/%s_rigged_candidate.glb"%[spec[0],spec[0]]
		if spec[0]=="errand_passenger":path="res://characters/npcs/motion/errand_passenger/errand_passenger.glb"
		var original:=create_actor(path,spec[1],true);var current:=create_actor(path,spec[1],false)
		for frame in 4:await process_frame
		for step in 270:
			var state: StringName=&"idle" if step<60 or (step>=150 and step<180) else (&"turn" if step>=120 and step<150 else &"walk")
			for actor in [original,current]:
				actor.set_meta("combat_action","strike" if step>=240 else "");actor.foot_plant_enabled=step<180;actor.travel_speed=actor.nominal_walk_speed if state==&"walk" else 0.0;actor._turn_progress=float(step%30)/30.0
				actor._set_animation(state,1.0/60.0)
			for bone in original._skeleton.get_bone_count():
				check(original._skeleton.get_bone_pose_position(bone)==current._skeleton.get_bone_pose_position(bone),"NPC foot position changed")
				check(original._skeleton.get_bone_pose_rotation(bone)==current._skeleton.get_bone_pose_rotation(bone),"NPC foot rotation changed")
			check(original.foot_plant.active==current.foot_plant.active and original.foot_plant.planted_world==current.foot_plant.planted_world and original.foot_plant.hip_drop==current.foot_plant.hip_drop,"NPC planted contact state changed")
			checked_poses+=1
			if DisplayServer.get_name()!="headless" and step in [59,119,149,239,269]:
				original.show();current.hide();RenderingServer.force_draw(false);RenderingServer.force_draw(false)
				var expected:=viewport.get_texture().get_image().get_data()
				var content_samples:=0
				for byte in range(0,expected.size(),1024):
					if expected[byte]!=expected[0] or expected[byte+1]!=expected[1] or expected[byte+2]!=expected[2]:content_samples+=1
				check(content_samples>20,"NPC native view contains no visible character detail")
				RenderingServer.force_draw(false);check(expected==viewport.get_texture().get_image().get_data(),"Frozen foot pixel control changed")
				original.hide();current.show();RenderingServer.force_draw(false)
				check(expected==viewport.get_texture().get_image().get_data(),"NPC foot native pixels changed")
		var old_times:Array[int]=[];var new_times:Array[int]=[]
		for round_index in 9:
			for variant in ([0,1] if round_index%2==0 else [1,0]):
				var actor:Node3D=original if variant==0 else current
				actor.set_meta("combat_action","");var start:=Time.get_ticks_usec()
				for step in 120:actor._set_animation(&"idle",1.0/60.0)
				(old_times if variant==0 else new_times).append(Time.get_ticks_usec()-start)
		old_times.sort();new_times.sort()
		print("NPC FRAME WORK ",JSON.stringify({"model":spec[0],"original_120_idle_updates_us":old_times[4],"cached_120_idle_updates_us":new_times[4]}))
		original.free();current.free()
	viewport.free();light.free()
	print("NPC FRAME WORK: ","FAIL" if failed else "PASS"," | ",checked_poses," exact full-rig poses and planted contact states; idle/walk/turn/disabled-plant/strike native pixels compared in memory" if DisplayServer.get_name()!="headless" else "")
	await root.get_node("SaveManager").quit_game(1 if failed else 0)
