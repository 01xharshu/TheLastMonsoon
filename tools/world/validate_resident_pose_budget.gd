extends SceneTree
const Startup=preload("res://systems/world_startup.gd")
var checks:=0
func _initialize() -> void:run.call_deferred()
func check(ok:bool,label:String) -> void:
	checks+=1
	assert(ok,label)
func reset(actor:Node,position:Vector3) -> void:
	actor.transform=Transform3D(Basis.IDENTITY,position);actor._home=position;actor._clock=0.0
	actor._resident_pose_elapsed=0.0;actor.resident_pose_time=0.0
	actor._resident_pose_state=&"idle";actor._resident_walk_seconds=0.0
	actor._resident_leg_pose.clear();actor._resident_leg_bones.clear()
	actor.locomotion_blend=0.0;actor.turn_blend=0.0;actor._walk_phase=0.0;actor._last_facing=0.0
	actor.foot_plant.hip_drop=0.008;actor.walk_playback_rate=1.0
	actor.foot_plant.clear();actor.animation_tree.active=false;actor.animation_tree.active=true
	actor._process(0.0);actor.resident_pose_updates=0
	if actor.get_script().resource_path=="res://characters/npcs/indian/indian_street_actor.gd" and actor.drape!=null:
		actor.drape_age=0.0
		if actor.movement_profile==&"female":actor.drape.previous_inputs.clear()
		else:actor.drape.previous.clear()
		actor.drape.update()
func pose(actor:Node) -> Array:
	var result:Array=[actor.transform]
	for bone in actor._skeleton.get_bone_count():result.append(actor._skeleton.get_bone_pose(bone))
	return result
func run() -> void:
	check(OS.get_user_data_dir()==OS.get_environment("TLM_EXPECT_USER_DATA"),"Disposable userdata required")
	if "--world" in OS.get_cmdline_user_args():await world_check();return
	paused=true
	var world:=Node3D.new();root.add_child(world);current_scene=world
	var clock:=Node.new();clock.name="GameTimeSystem";world.add_child(clock)
	var viewer:=Node3D.new();viewer.name="Player";world.add_child(viewer)
	var camera:=Camera3D.new();world.add_child(camera);camera.make_current()
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-30,0);world.add_child(sun)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.18,.23,.28);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_energy=.6;world.add_child(env)
	var records: Array=[
		["British","res://characters/npcs/british/british_npc_actor.gd","res://characters/npcs/british/private_man.glb"],
		["WaterBearer","res://characters/npcs/households/household_npc_actor.gd","res://characters/npcs/motion/village_farmer/village_farmer_rigged_candidate.glb"],
		["StreetMale","res://characters/npcs/indian/indian_street_actor.gd","res://characters/npcs/street_residents/male_01.glb"],
		["StreetFemale","res://characters/npcs/indian/indian_street_actor.gd","res://characters/npcs/street_residents/female_01.glb"]]
	for record in records:
		var actor:Node3D=load(record[1]).new();actor.name=record[0];actor.movement_enabled=false
		if record[0]=="StreetFemale":actor.movement_profile=&"female"
		if record[0]=="WaterBearer":
			actor.household_job="WaterBearer"
			var pot:=Node3D.new();pot.name="CarriedWaterPot";actor.add_child(pot)
		actor.add_child(load(record[2]).instantiate());world.add_child(actor);await process_frame
		check(actor._resident_pose_eligible,"Ordinary actor not eligible")
		var meshes:=actor.find_children("*","MeshInstance3D",true,false).size()
		var poses:Array=[];var images:Array[PackedByteArray]=[];var results:Array=[]
		var routes:Array=[]
		var walking_palms:Array=[];var walking_contacts:Array=[];var walking_phases:Array=[];var walking_near:Array=[];var walking_costs:Array=[]
		for budget in [false,true]:
			actor.resident_pose_budget_enabled=budget;actor.movement_enabled=false
			reset(actor,Vector3(8,0,0))
			for frame in 24:
				actor._process(1.0/60.0)
				if not budget:poses.append(pose(actor))
				else:check(pose(actor)==poses[frame],"Nearby bone pose changed")
				if frame in [0,12,23] and DisplayServer.get_name()!="headless":
					camera.position=actor.position+Vector3(2,1.3,2);camera.look_at(actor.position+Vector3.UP)
					for warm in 5:await process_frame
					RenderingServer.force_draw()
					var pixels:=root.get_texture().get_image().get_data()
					if not budget:images.append(pixels)
					else:check(pixels==images[[0,12,23].find(frame)],"Nearby resident pixels changed")
			check(actor.resident_pose_updates==24,"Nearby idle was throttled")
			actor.movement_enabled=true;reset(actor,Vector3(8,0,0))
			for frame in 110:
				actor._process(1.0/60.0)
				if not budget:walking_near.append(pose(actor))
				else:check(pose(actor)==walking_near[frame],"Nearby walking bone pose changed %s frame %s" % [record[0],frame])
				if frame in [24,64,109] and DisplayServer.get_name()!="headless":
					camera.position=actor.position+Vector3(2,1.3,2);camera.look_at(actor.position+Vector3.UP)
					for warm in 5:await process_frame
					RenderingServer.force_draw()
					var pixels:=root.get_texture().get_image().get_data()
					if not budget:images.append(pixels)
					else:check(pixels==images[3+[24,64,109].find(frame)],"Nearby walking body/clothing pixels changed")
			actor.movement_enabled=false

			reset(actor,Vector3(400,0,0));var tick:=Time.get_ticks_usec()
			for frame in 600:actor._process(1.0/60.0)
			results.append({"budget":budget,"usec":Time.get_ticks_usec()-tick,"poses":actor.resident_pose_updates})
			check(actor.resident_pose_updates<=21 if budget else actor.resident_pose_updates==600,"Far idle cadence wrong")
			check(is_equal_approx(actor.resident_pose_time+actor._resident_pose_elapsed,10.0),"Idle elapsed time lost")
			# Same full-rate autonomous patrol path, collider and schedule clock.
			actor.movement_enabled=true;reset(actor,Vector3(400,0,0))
			var walking_tick:=Time.get_ticks_usec();var worst_contact:=0.0
			for frame in 600:
				actor._process(1.0/60.0)
				if not budget:walking_phases.append(actor._walk_phase)
				elif actor.animation_state==&"walk":check(absf(actor._walk_phase-walking_phases[frame])<0.0001,"Walking phase diverged %s frame %s actual %s expected %s" % [record[0],frame,actor._walk_phase,walking_phases[frame]])
				var contact_error:=0.0
				if actor.foot_plant.active:
					var foot:int=actor.foot_plant.legs[actor.foot_plant.planted_side][2]
					var actual:Vector3=actor._skeleton.to_global(actor._skeleton.get_bone_global_pose(foot).origin)
					contact_error=actual.distance_to(actor.foot_plant.planted_world)
					worst_contact=maxf(worst_contact,contact_error)
				if not budget:walking_contacts.append(contact_error)
				else:check(contact_error<=float(walking_contacts[frame])+.005,"Per-frame planted foot contact worsened")
				if record[0]=="WaterBearer":
					var gap:=0.0
					var pot:Node3D=actor.get_node("CarriedWaterPot")
					for side in ["l","r"]:
						gap=maxf(gap,actor.palm_world(side).distance_to(pot.to_global(Vector3(.135 if side=="l" else -.135,.035,0))))
					if not budget:walking_palms.append(gap)
					else:check(gap<=float(walking_palms[frame])+.001,"Carried pot grip worsened between samples")
				var path_state:Array=[actor.transform,actor.body_collider.global_transform,actor._clock,actor.contact_blocked]
				if not budget:routes.append(path_state)
				else:check(path_state==routes[frame],"Patrol/collider/clock changed")
			walking_costs.append({"budget":budget,"usec":Time.get_ticks_usec()-walking_tick,"poses":actor.resident_pose_updates,"contact_mm":worst_contact*1000.0})
			if budget:
				check(actor.resident_pose_updates<300,"Distant patrol animation samples not reduced")
				check(worst_contact<=float(walking_costs[0].contact_mm)/1000.0+.005,"Planted foot contact worsened")
			check(is_equal_approx(actor.resident_pose_time+actor._resident_pose_elapsed,10.0),"Patrol pose time lost")
		print("RESIDENT IDLE A/B ",record[0]," ",results)
		print("RESIDENT WALK A/B ",record[0]," ",walking_costs)
		# Speed varies within each sample window; expected gait follows travelled distance.
		actor.resident_pose_budget_enabled=true;actor.movement_enabled=false
		reset(actor,Vector3(400,0,0))
		var expected_phase:=0.0
		for frame in 120:
			actor.travel_speed=actor.nominal_walk_speed*(.4 if frame%2==0 else 1.6)
			actor.position.z+=actor.travel_speed/60.0
			expected_phase=fmod(expected_phase+actor.travel_speed/actor.nominal_walk_speed/60.0/actor.animation_player.get_animation("walk").length,1.0)
			actor._update_autonomous_pose(&"walk",1.0/60.0)
			check(absf(actor._walk_phase-expected_phase)<.0001,"Variable speed gait lost distance")
		var sampled:int=actor.resident_pose_updates
		viewer.position=actor.position;actor._update_autonomous_pose(&"walk",1.0/60.0)
		check(actor.resident_pose_updates==sampled+1,"Walking approach did not promote immediately")
		viewer.position=Vector3.ZERO
		actor.movement_enabled=false;actor.resident_pose_budget_enabled=true
		reset(actor,Vector3(120,0,0))
		for frame in 60:actor._process(1.0/60.0)
		check(actor.resident_pose_updates>=8 and actor.resident_pose_updates<=10,"Mid idle cadence wrong")
		reset(actor,Vector3(400,0,0));actor._process(.03);check(actor.resident_pose_updates==0,"Far idle should wait")
		viewer.position=actor.position;actor._process(1.0/60.0);check(actor.resident_pose_updates==1,"Approach did not promote")
		viewer.position=Vector3.ZERO
		for flag in ["mission_active","police_engaged","grappled","combat_action"]:
			actor.set_meta(flag,"hit" if flag=="combat_action" else true);reset(actor,Vector3(400,0,0))
			for frame in 12:actor._process(1.0/60.0)
			check(actor.resident_pose_updates==12,"Essential resident throttled");actor.remove_meta(flag)
		viewer.set_meta("story_cinematic",true);camera.position=actor.position;reset(actor,Vector3(400,0,0))
		for frame in 12:actor._process(1.0/60.0)
		check(actor.resident_pose_updates==12,"Cinematic resident throttled");viewer.remove_meta("story_cinematic")
		# External work owners invoke the public pose method directly; no double budget.
		reset(actor,Vector3(400,0,0));var before:float=actor.resident_pose_time
		for frame in 12:actor._set_animation(&"idle",1.0/60.0)
		check(actor.resident_pose_time==before and actor._resident_pose_elapsed==0.0,"External pose dispatch was intercepted")
		check(actor.find_children("*","MeshInstance3D",true,false).size()==meshes,"Resident meshes changed")
		actor.hide();actor.position=Vector3(2000+checks,0,0);actor.body_collider.force_update_transform()
	print("RESIDENT POSE BUDGET PASS checks=",checks," native=",DisplayServer.get_name()!="headless")
	root.get_node("SaveManager").quit_game()
func world_check() -> void:
	var saves:=root.get_node("SaveManager")
	saves.options.graphics_quality=1;saves.options.fullscreen=false;saves.options.vsync=false;saves.apply_options()
	var session:=Startup.start(self);paused=true
	saves.start_new_game();await scene_changed
	var world:Node3D=current_scene
	while not session.tasks.is_empty():await process_frame
	while saves.pending_slot>=0:await process_frame
	world.show();Startup.close(session);paused=false
	var opening:=world.get_node("OpeningSequence")
	var skip:=InputEventKey.new();skip.keycode=KEY_ESCAPE;skip.pressed=true
	opening._input(skip);await process_frame;opening._input(skip)
	while opening.state!="done":await process_frame
	var viewer:CharacterBody3D=world.get_node("Player");viewer.set_physics_process(false)
	var camera:=Camera3D.new();world.add_child(camera);camera.make_current()
	for spec in [["village",Vector2(-310,245)],["city",Vector2(-350,-310)]]:
		var point:Vector2=spec[1]
		viewer.position=Vector3(point.x,world.layout.height(point.x,point.y)+1,point.y)
		camera.position=viewer.position+Vector3.UP;camera.look_at(camera.position+Vector3(20,-1.4,-20))
		for frame in 40:await process_frame
		var residents:Array[Node]=[];var static_far:Array[Node]=[];var before:Dictionary={}
		for node in world.find_children("*","Node3D",true,false):
			if node.get_script()==null or node.get_script().resource_path not in ["res://characters/npcs/british/british_npc_actor.gd","res://characters/npcs/households/household_npc_actor.gd","res://characters/npcs/indian/indian_street_actor.gd"]:continue
			check(node._resident_pose_eligible,"Live ordinary actor not eligible")
			check(node._resident_pose_viewer==viewer,"Cached resident viewer belongs to wrong world")
			residents.append(node)
			if node.is_processing() and not node.movement_enabled and not node.get_meta("external_combat_motion",false) and not node.get_meta("mission_active",false) and not node.get_meta("police_engaged",false) and not node.get_meta("grappled",false) and node.get_meta("combat_action","")=="" and node.global_position.distance_squared_to(viewer.global_position)>40000:
				static_far.append(node);before[node]=node.resident_pose_updates
		check(residents.size()>=30,"Ordinary resident population missing")
		var bag:Node3D=viewer.get_node("VisualRoot/EquipmentVisuals/WaterBagVisual")
		var bag_scans:Array[int]=[]
		var bag_original_cost:Array[int]=[];var bag_grouped_cost:Array[int]=[]
		var samples:Array[float]=[];var started:=Time.get_ticks_usec();var tick:=started
		for frame in 120:
			await process_frame
			var now:=Time.get_ticks_usec();samples.append((now-tick)/1000.0);tick=now
			var bag_values:Array[float]=[]
			for grouped in ([true,false] if frame%2==0 else [false,true]):
				bag.use_contact_groups=grouped
				var query_tick:=Time.get_ticks_usec()
				bag_values.append(bag._cloth_contact_required())
				(bag_grouped_cost if grouped else bag_original_cost).append(Time.get_ticks_usec()-query_tick)
				if grouped:bag_scans.append(bag.contact_samples_scanned)
			bag.use_contact_groups=true
			check(bag_values[0]==bag_values[1],"Actual-world coat contact bounds changed support")

		var elapsed:=float(Time.get_ticks_usec()-started)/1000000.0
		var updates:=0
		for node in static_far:
			if not is_instance_valid(node):continue
			updates+=node.resident_pose_updates-before[node]
			check(node.resident_pose_updates-before[node]<=ceili(elapsed/.5)+4,"Distant settled idle exceeded cadence")
		samples.sort()
		bag_original_cost.sort();bag_grouped_cost.sort();bag_scans.sort()
		print("BAG LIVE CONTACT region=",spec[0]," source_samples=",bag.contact_points.size()," grouped_scans_min_p50_max=",[bag_scans[0],bag_scans[60],bag_scans[-1]]," original_query_p50_p95_us=",[bag_original_cost[60],bag_original_cost[114]]," grouped_query_p50_p95_us=",[bag_grouped_cost[60],bag_grouped_cost[114]]," exact_parity=true support=",bag.cloth_support)
		print("RESIDENT LIVE WORLD region=",spec[0]," residents=",residents.size()," static_far=",static_far.size()," static_far_poses=",updates," wall_seconds=",elapsed," p50/p95ms=",[samples[60],samples[114]]," viewport=",root.size," scale=",root.scaling_3d_scale," scope=post-change integration sample, not FPS attribution")
	print("RESIDENT POSE BUDGET PASS actual-world checks=",checks)
	saves.quit_game()
