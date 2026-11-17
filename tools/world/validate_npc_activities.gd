extends SceneTree
var issues: Array[String] = []
var checks := 0
class Gear:
	extends Node
	var stowed:=true
	var aiming:=false
	var selected:=1
func _initialize() -> void:run.call_deferred()
func check(value: bool, label: String) -> void:
	checks+=1
	if not value:issues.append(label);push_error(label)

func vector_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]

func sample_repair_outfit(actor: Node3D, frame: int) -> void:
	var skinner = load("res://tools/characters/audit_village_runtime_contact.gd")
	var rig: Skeleton3D = actor._skeleton
	rig.force_update_all_bone_transforms()
	var data := {"pose": "village_repair", "sample": frame, "age": actor.activity_age,
		"meshes": [], "bones": []}
	var local_from_world := actor.global_transform.affine_inverse()
	for index in rig.get_bone_count():
		var current := local_from_world * rig.global_transform * rig.get_bone_global_pose(index)
		var rest := local_from_world * rig.global_transform * rig.get_bone_global_rest(index)
		data.bones.append({"name": rig.get_bone_name(index), "origin": vector_array(current.origin),
			"basis": [vector_array(current.basis.x), vector_array(current.basis.y), vector_array(current.basis.z)],
			"rest_origin": vector_array(rest.origin),
			"rest_basis": [vector_array(rest.basis.x), vector_array(rest.basis.y), vector_array(rest.basis.z)]})
		if frame == 47 and rig.get_bone_name(index) in [&"foot_l", &"foot_r", &"pelvis"]:
			print("REPAIR_FIT_POSE ", rig.get_bone_name(index), " ", current.origin)
	for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
		var label := str(mesh.name)
		if mesh.skin == null or not ("complete_MakeHuman_body" in label or "cotton" in label or "opaque foundation" in label):
			continue
		for surface in mesh.mesh.get_surface_count():
			var points: PackedVector3Array = skinner.posed_points(mesh, rig, surface, local_from_world)
			var vertices := []
			for point in points:
				vertices.append(vector_array(point))
			var weights := {}
			for key in mesh.mesh.get_blend_shape_count():
				weights[str(mesh.mesh.get_blend_shape_name(key))] = mesh.get_blend_shape_value(key)
			data.meshes.append({"name": label, "vertices": vertices,
				"indices": mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX], "morphs": weights})
	var path := OS.get_environment("TLM_ACTIVITY_REVIEW").path_join("repair_surfaces/frame_%02d.json" % frame)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))

func repair_wheel_clearance(record: Dictionary) -> float:
	var actor: Node3D=record.actor
	var cart: Node3D=record.cart
	var wheel: Node3D=cart.get_node("WheelRight")
	var rig: Skeleton3D=actor._skeleton
	var minimum:=INF
	for side in ["l","r"]:
		var knee:=rig.to_global(rig.get_bone_global_pose(rig.find_bone("calf_"+side)).origin)
		var ankle:=rig.to_global(rig.get_bone_global_pose(rig.find_bone("foot_"+side)).origin)
		var toe:=ankle+(actor.global_basis*Vector3.BACK.rotated(Vector3.UP,actor.seat_foot_yaw))*.15+Vector3.DOWN*.045
		for segment in [[knee,ankle,.045],[ankle,toe,.026]]:
			for probe in 13:
				var point: Vector3=cart.to_local(segment[0].lerp(segment[1],float(probe)/12.0))-wheel.position
				var radial:=Vector2(point.y,point.z).length()
				var clearance:=maxf(absf(point.x)-.03,radial-.47)-float(segment[2])
				minimum=minf(minimum,clearance)
	return minimum

func run() -> void:
	create_timer(180).timeout.connect(func():quit(2))
	check(OS.get_user_data_dir()==OS.get_environment("TLM_EXPECT_USER_DATA"),"isolated user data")
	var world:=Node3D.new();world.name="ActivityValidation";root.add_child(world);current_scene=world
	var clock=load("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock);clock.clock_paused=true;clock.current_hour=9
	var viewer:=CharacterBody3D.new();viewer.name="Player";world.add_child(viewer)
	var camera:=Camera3D.new();world.add_child(camera);camera.make_current()
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-42,-25,0);sun.light_energy=1.2;world.add_child(sun)
	var env:=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.30,.37,.42);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_energy=.7;world.add_child(env)
	var actual: bool="--village" in OS.get_cmdline_user_args()
	if actual:
		world.add_child(load("res://world/suryagarh/generated/landscape.scn").instantiate())
		var charpai=load("res://objects/charpai.tscn").instantiate();charpai.name="Charpai";world.add_child(charpai)
		var settlement=load("res://tools/world/river_village_fixture.gd").new();settlement.name="Settlement";world.add_child(settlement)
		while not settlement.has_node("BhairavpurHouse30"):await process_frame
		for frame in 12:await physics_frame
		var jobs=load("res://world/suryagarh/settlements/named_occupations.gd").new();world.add_child(jobs)
		var candidate_path := OS.get_environment("TLM_REPAIR_OUTFIT")
		var correctives: RefCounted
		var sample_cycle := OS.get_environment("TLM_REPAIR_CYCLE") == "1"
		if not candidate_path.is_empty():
			var document := GLTFDocument.new()
			var state := GLTFState.new()
			if document.append_from_file(candidate_path, state, GLTFDocument.IMPORT_FLAG_USE_NAMED_SKIN_BINDS) != OK:
				quit(2)
				return
			var model := document.generate_scene(state)
			var appearance := PackedScene.new()
			var packed := appearance.pack(model)
			model.free()
			if packed != OK:
				quit(2)
				return
			jobs.spawn_worker(0, settlement, appearance)
			jobs.spawn_index = 1
			correctives = load("res://characters/npcs/occupation_cloth_correctives.gd").new()
			correctives.setup(jobs.workers[0])
			jobs.workers[0].outfit_correctives = correctives
		while jobs.workers.size()<3:jobs._process(1.0);await process_frame
		if sample_cycle and candidate_path.is_empty():
			correctives = jobs.workers[0].outfit_correctives
			check(correctives != null, "cart maker uses fitted outfit through normal spawn")
			check(jobs.records[0].station.get_node("RepairSeat/Legs").get_child_count() == 4, "repair stool has four grounded legs")
		if correctives != null:
			DirAccess.make_dir_absolute(OS.get_environment("TLM_ACTIVITY_REVIEW").path_join("repair_surfaces"))
		jobs.set_physics_process(false)
		for reaction in get_nodes_in_group("civilian_reactions"):reaction.set_physics_process(false)
		for record in jobs.records:
			if candidate_path.is_empty():
				check(record.actor.get_meta("seat_profile_cached", false), "installed occupation uses baked seat samples")
			check(record.actor.get_meta("adult_character",false),"adult MPFB workplace actor")
			check(not record.actor.face_entries.is_empty(),"authored facial shapes")
			var role: String = record.actor.get_meta("world_role")
			check(record.actor.get_meta("occupation_fabric_role", "") == role, "job fabric applied to "+role)
			var found := 0
			var skin_found := false
			for part: MeshInstance3D in record.actor.find_children("*", "MeshInstance3D", true, false):
				var name := str(part.name).to_lower().replace("_", " ")
				if "complete makehuman body" in name:
					var material := part.get_surface_override_material(0) as StandardMaterial3D
					skin_found = material != null and material.albedo_texture != null
				if name.begins_with("activity cotton shirt") or name.begins_with("activity cotton trousers"):
					var material := part.get_surface_override_material(0)
					var slot := 0 if name.begins_with("activity cotton shirt") else 1
					if material is StandardMaterial3D or material is ShaderMaterial:
						found += 1
						var color: Color = material.albedo_color if material is StandardMaterial3D else material.get_shader_parameter("cloth_color")
						check(color.is_equal_approx(load("res://world/suryagarh/settlements/occupation_wardrobe.gd").CLOTHES[role][slot]), "correct job fabric on "+role)
			check(found == 2, "two individual fabric materials on "+role)
			check(skin_found, "individual textured complete body on "+role)
		var repair_stance := OS.get_environment("TLM_REPAIR_STANCE").split(",",false)
		if repair_stance.size()>=3:
			var repair: Dictionary=jobs.records[0]
			var actor: Node3D=repair.actor
			actor.seat_foot_forward=repair_stance[0].to_float()
			actor.seat_foot_half_width=repair_stance[1].to_float()
			if repair_stance.size()>=4:actor.seat_foot_yaw=deg_to_rad(repair_stance[3].to_float())
			var before:=actor.global_position
			actor.global_position += repair.cart.global_basis.x * repair_stance[2].to_float()
			actor.global_position.y=actor.ground_height.call(actor.global_position.x,actor.global_position.z)
			var stool: MeshInstance3D = repair.station.get_node("RepairSeat")
			stool.global_position += actor.global_position-before
			if repair_stance.size()==5:
				var height := repair_stance[4].to_float()
				stool.global_position.y += height - actor.seat_height
				actor.seat_height = height
			jobs.support_repair_seat(stool)
			repair.home_position=actor.position
		var wheel_clearance:=INF
		var roll_seen:=false
		var roll_error:=0.0
		for step in 600:
			for record in jobs.records:
				var cart_before: Vector3=record.cart.global_position if record==jobs.records[1] else Vector3.ZERO
				var wheel_before: float=record.cart.get_node("WheelLeft").rotation.x if record==jobs.records[1] else 0.0
				jobs.tick_worker(record,1.0/30.0)
				if correctives != null and record.job == 0:
					var in_cycle := step < 24 or (step < 66 and step % 3 == 0)
					if step < 20 or step == 47 or (sample_cycle and in_cycle):
						sample_repair_outfit(record.actor, step)
				if (repair_stance.size()>=3 or sample_cycle) and record.job==0 and step>30:
					wheel_clearance=minf(wheel_clearance,repair_wheel_clearance(record))
				if record==jobs.records[1]:
					var wheel: Node3D=record.cart.get_node("WheelLeft")
					var travel: float=(record.cart.global_position-cart_before).dot(record.cart.global_basis.z)
					if absf(travel)>.00001:
						roll_seen=true
						roll_error=maxf(roll_error,absf((wheel.rotation.x-wheel_before)+travel/wheel.position.y))
				record.last_hand=maxf(record.actor.get_meta("hand_contact_l",0.0),record.actor.get_meta("hand_contact_r",0.0))
				if step>30:record.max_settled=maxf(float(record.get("max_settled",0.0)),record.last_hand)
				record.max_hand=maxf(float(record.get("max_hand",0.0)),maxf(record.actor.get_meta("hand_contact_l",0.0),record.actor.get_meta("hand_contact_r",0.0)))
			if step%60==0:await physics_frame
		if repair_stance.size()>=3 or sample_cycle:
			print("REPAIR_WHEEL_CLEARANCE ",wheel_clearance)
			check(wheel_clearance>=0.0,"repair calves and feet clear actual wheel envelope")
		print("MILK_ROUTE ",jobs.records[1].get("obstacle","")," distance=",jobs.records[1].distance," blocked=",jobs.records[1].blocked)
		check(jobs.records[1].distance>5.0,"milk cart physically travels delivery strip")
		check(roll_seen and roll_error<.001,"milk cart wheel rolls in actual travel direction without sliding")
		check(jobs.records[1].blocked==0,"milk cart route unobstructed")
		check(jobs.records[0].cart.get_meta("cart_design")==jobs.records[1].cart.get_meta("cart_design"),"repair and milk carts share design")
		var balti_count:=0
		for node in jobs.records[1].cart.get_children():
			if node.get_meta("milk_balti",false):balti_count+=1
		check(balti_count==6,"six milk baltis")
		var data: Dictionary=jobs.export_state();jobs.records[1].elapsed=0;jobs.restore_state(JSON.parse_string(JSON.stringify(data)))
		check(absf(jobs.records[1].elapsed-float(data.Milkman.elapsed))<.00001,"work phase save round trip")
		for record in jobs.records:
			var rig: Skeleton3D=record.actor._skeleton
			print("WORK_RIG ",record.actor.name," shoulders=",record.actor.to_local(rig.to_global(rig.get_bone_global_pose(rig.find_bone("upperarm_l")).origin))," elbow=",record.actor.to_local(rig.to_global(rig.get_bone_global_pose(rig.find_bone("lowerarm_l")).origin))," palm=",record.actor.to_local(record.actor.palm_world("l"))," rightpalm=",record.actor.to_local(record.actor.palm_world("r"))," errors=",record.actor.get_meta("hand_contact_l",0),"/",record.actor.get_meta("hand_contact_r",0))
			print("WORK_CONTACT ",record.actor.name," ",record.max_hand," settled=",record.max_settled," last=",record.last_hand)
			check(record.max_hand<.03,"work palms within30mm "+str(record.actor.name))
			if record.job!=1:
				print("SEAT_CONTACT ",record.actor.name," samples=",record.actor.seat_samples.size()," seat=",record.actor.get_meta("seat_error",INF)," ankle=",record.actor.get_meta("seated_ankle_error",INF))
				check(not record.actor.seat_samples.is_empty() and record.actor.get_meta("seat_error",INF)<.005,"actual MPFB seat contact "+str(record.actor.name))
				check(record.actor.get_meta("seated_ankle_error",INF)<.015,"supported seated ankles "+str(record.actor.name))
			await capture(camera,record.actor.global_position,str(record.actor.name))
		var routine: Node=get_first_node_in_group("village_river_routine")
		routine.set_physics_process(false)
		for woman in routine.women:woman.sample(28.2)
		check(routine.women[0].get_meta("river_action")=="wash","independent river laundry")
		check(routine.women[1].get_meta("river_action")=="bathe" and not routine.women[1].cloth.visible,"independent clothed bathing")
		check(routine.women[2].action in ["sit_down","talk"],"independent river conversation")
		check(routine.has_node("RiverAccessFootpath"),"visible river footpath integrated")
		check(routine.get_node("RiverAccessFootpath").reserved(Vector2(routine.shore.x,routine.shore.z)),"path grass reservation reaches shore")
		check(routine.has_node("PrivateRiverGhat/GhatShadeTrees"),"ghat has shared shade trees")
		await capture(camera,routine.shore,"RiverGroup")
		if DisplayServer.get_name()!="headless":
			camera.global_position=routine.shore+Vector3(10,9,12);camera.look_at(routine.shore+Vector3(-6,0,0));camera.fov=60
			for warm in 6:await process_frame
			RenderingServer.force_draw()
			var folder:=OS.get_environment("TLM_ACTIVITY_REVIEW")
			if not folder.is_empty():root.get_texture().get_image().save_png(folder+"/GhatPath.png")
		if "--playback" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless":
			clock.total_game_minutes=540;clock.current_hour=9;clock.clock_paused=false
			jobs.set_physics_process(true)
			for index in 3:await playback(camera,viewer,jobs.records[index].actor,jobs.records[index],8.0 if index==0 else 24.0 if index==1 else 16.0)
			jobs.set_physics_process(false);clock.clock_paused=true
	else:
		var floor:=StaticBody3D.new();var hit:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(40,.2,40);hit.shape=shape;hit.position.y=-.1;floor.add_child(hit);world.add_child(floor)
		var plane:=MeshInstance3D.new();var mesh:=PlaneMesh.new();mesh.size=Vector2(40,40);plane.mesh=mesh;world.add_child(plane)
		var actor=load("res://characters/npcs/activity_actor.gd").new();actor.name="ActivityAdult";actor.movement_enabled=false;actor.add_child(load("res://characters/npcs/activity_people/artisan.glb").instantiate());world.add_child(actor)
		await process_frame;actor.set_process(false)
		check(actor._skeleton.get_bone_count()>40,"retained MPFB skeleton")
		check(not actor.face_entries.is_empty(),"Blender-authored facial shapes imported")
		for action in actor.activities:
			for step in 90:actor.perform(action,1.0/30.0,action in ["talk","teach"],.8 if action=="cower" else 0.0)
			check(actor.animation_tree.tree_root.has_node("combat"),"combat tree retained for "+action)
			check(actor.get_meta("activity")==action,"work pose "+action)
			actor.finish_contacts()
			if action in ["repair","shape","read","teach","cower"]:await capture(camera,actor.global_position,action)
		var reaction: Node=actor.get_node("CivilianReaction");reaction.set_physics_process(false)
		viewer.position=Vector3(0,0,2)
		var awareness=load("res://world/suryagarh/civilian_awareness.gd").new();world.add_child(awareness);awareness.set_process(false);awareness.set_physics_process(false)
		var gear:=Gear.new();world.add_child(gear);awareness.equipment=gear
		camera.position=viewer.position+Vector3.UP*1.3;camera.look_at(actor.global_position+Vector3.UP*1.2)
		check(not awareness.threatening(viewer,actor),"stowed weapon does not frighten civilians")
		gear.stowed=false
		check(not awareness.threatening(viewer,actor),"carried un-aimed gun does not cause panic")
		gear.aiming=true
		check(awareness.threatening(viewer,actor),"aimed visible gun is a threat")
		check(awareness.visible(actor,viewer),"clear threat sight")
		var wall=load("res://world/suryagarh/settlements/activity_props.gd").box(world,"ThreatOccluder",Vector3(0,1.1,1),Vector3(2,2,.2),StandardMaterial3D.new(),true)
		await physics_frame
		check(not awareness.visible(actor,viewer),"walls occlude threat perception")
		reaction.source=viewer;reaction.state="flee";reaction.choose_escape()
		check(reaction.sheltered,"road wall can be selected as cover without a home registry")
		reaction.finish();reaction.cooldown=0;reaction.set_physics_process(false)
		wall.queue_free();await physics_frame
		var arguing_peer:=Node3D.new();world.add_child(arguing_peer);arguing_peer.position=Vector3(1,0,2)
		awareness.argument(viewer,arguing_peer)
		check(reaction.state=="startle","nearby argument frightens a witness")
		reaction.finish();reaction.cooldown=0;reaction.set_physics_process(false);arguing_peer.queue_free()
		reaction.witness(viewer,true)
		check(reaction.state=="startle" and actor.get_meta("civilian_reacting"),"weapon startles and interrupts")
		reaction._physics_process(.8)
		check(reaction.state in ["flee","hide"],"fear progresses to escape or shelter")
		for frame in 180:
			if not reaction.navigation_pending:break
			await physics_frame
		var start: Vector3=actor.global_position
		for step in 90:reaction._physics_process(1.0/30.0)
		check(actor.global_position.distance_to(start)>2.0,"escape follows real queued navigation")
		# Return under the same swept movement and restore the workstation heading
		# before a seated/tool-contact owner resumes.
		reaction.state="return";reaction.path.clear();reaction.path.append(reaction.origin);reaction.navigation_pending=false;reaction.threat_ttl=0
		for step in 420:
			reaction._physics_process(1.0/30.0)
			if reaction.state=="":break
		check(reaction.state=="" and actor.global_position.distance_to(reaction.origin)<.15,"physical return reaches workplace")
		check(absf(angle_difference(actor.global_rotation.y,reaction.origin_yaw))<.02,"return restores workplace heading")
		reaction.finish();reaction.set_physics_process(false);actor.position=Vector3.ZERO;reaction.cooldown=0
		actor.set_meta("world_role","cart_maker");reaction.witness(viewer,false,true)
		check(reaction.state=="guard","direct unarmed assault permits guarded defense")
		actor.set_meta("civilian_defence_style","slap")
		reaction.attack_age=.99;reaction._physics_process(.02)
		check(actor.get_meta("combat_action","")=="slap" and reaction.attack_started,"defensive slap has its own animation")
		check(not reaction.attack_delivered,"slap cannot damage before contact phase")
		var motion:Node=actor.get_node("CombatMotion")
		motion.set_process(false);motion._process(.28)
		check(actor.animation_tree.tree_root.get_node("combat_pose").max_space>=6,"slap tree position is reachable")
		await capture(camera,actor.global_position,"DefensiveSlap")
		reaction._physics_process(.29)
		check(not reaction.attack_delivered,"slap does not damage without physical contact")
		var policy=preload("res://combat/damage_policy.gd")
		var vitality:Node=actor.get_node("Vitality")
		var health_before:float=vitality.health
		check(policy.apply(vitality,1.0,viewer,"punch") and vitality.health<health_before,"Arjun can strike an ordinary civilian")
		actor.set_meta("mission_active",true)
		check(not policy.apply(vitality,1.0,viewer,"weapon"),"mission civilian remains protected")
		actor.set_meta("mission_active",false)
		reaction.witness(viewer,true,true);check(reaction.state=="startle","weapon escalates defender fear")
		reaction.finish();reaction.cooldown=0
		reaction.impact(1.0,viewer);check(reaction.state=="","ordinary collision does not knock down")
		reaction.impact(6.0,viewer);check(reaction.state=="fall","hard collision falls")
		for step in 100:actor.get_node("CombatMotion")._process(.04);reaction._physics_process(.04)
		check(reaction.state in ["rise",""],"nonlethal collision recovers")
		reaction.finish()
		actor.set_meta("world_role","student")
		var lesson=load("res://story/college_activity.gd").new();lesson.person=actor;actor.add_child(lesson);lesson.set_process(false)
		for role in ["student","lecturer","printer"]:
			actor.set_meta("world_role",role)
			for at in [1.0,19.0,32.0,39.0]:lesson.elapsed=at;lesson.tick(.03)
			await capture(camera,actor.global_position,role)
		actor.set_meta("civilian_reacting",true);lesson.tick(.03)
		var book_at: Vector3=lesson.book.global_position
		actor.position.x+=2;lesson.tick(.03)
		check(lesson.book.top_level and lesson.book.global_position.distance_to(book_at)<.001,"study materials remain at seat during interruption")
		actor.position.x-=2;actor.set_meta("civilian_reacting",false);lesson.tick(.03)
		check(not lesson.book.top_level and not lesson.pen.top_level,"study materials resume normal ownership")
		var save=load("res://world/suryagarh/settlements/activity_save.gd");var saved: Dictionary=save.collect(world);save.restore(world,JSON.parse_string(JSON.stringify(saved)))
		check(not saved.is_empty(),"new and old save integration")
		var gestures=load("res://world/suryagarh/city_street_journey.gd").new()
		gestures.actor=actor;gestures.social_time=2.0
		actor.set_meta("street_action","talking");actor.set_meta("social_warmth",.7)
		actor._set_animation(&"idle",.1);gestures.apply_conversation_gesture()
		check(actor.get_meta("hand_contact_l",1.0)<.03 and actor.get_meta("hand_contact_r",1.0)<.03,"conversation gestures use both hands")
		gestures.free()
		var face_model=load("res://characters/npcs/indian_body_candidates/female_06.glb").instantiate();face_model.position.x=-2.0;world.add_child(face_model)
		var face=load("res://story/dialogue_expression.gd").new();face.configure(face_model);face.apply(0.0,0.0,0.0,0.0,0.0,.7)
		check(not face.entries.is_empty() and face.entries[0].node.get_blend_shape_value(5)>.6,"warm adult expression has a smile")
		if DisplayServer.get_name()!="headless":
			camera.global_position=face_model.global_position+Vector3(0,1.45,1.1)
			camera.look_at(face_model.global_position+Vector3.UP*1.43);camera.fov=35
			await process_frame;RenderingServer.force_draw()
			root.get_texture().get_image().save_png(OS.get_environment("TLM_ACTIVITY_REVIEW")+"/WarmSmile.png")
		face_model.queue_free()
		actor.travel_speed=2.8;actor._set_animation(&"walk",.3)
		var moving_leg:Quaternion=actor._skeleton.get_bone_pose_rotation(actor._skeleton.find_bone("thigh_l"))
		motion.play("hit");motion.set_process(false);motion._process(.3)
		check(moving_leg.angle_to(actor._skeleton.get_bone_pose_rotation(actor._skeleton.find_bone("thigh_l")))<.001,"running body hit preserves the leg gait")
		motion._process(.5)
		var contact_world:=Node3D.new();contact_world.name="CombatEncounters";world.add_child(contact_world)
		contact_world.set_script(load("res://world/suryagarh/combat_encounters.gd"))
		contact_world.set_process(false);contact_world.set_physics_process(false)
		var defender=load("res://characters/npcs/households/household_npc_actor.gd").new()
		defender.name="FemaleDefender";defender.movement_profile=&"female";defender.movement_enabled=false
		defender.position=Vector3(0,0,.75);defender.set_meta("world_role","cart_maker")
		defender.add_child(load("res://characters/npcs/indian_body_candidates/female_06.glb").instantiate());world.add_child(defender);defender.set_process(false)
		await process_frame
		actor._set_animation(&"idle",0.0);actor.body_collider.force_update_transform()
		var guard:Node=defender.get_node("CivilianReaction");guard.set_physics_process(false)
		var defence_motion:Node=defender.get_node("CombatMotion");defence_motion.set_process(false)
		var before_slap:float=vitality.health
		guard.witness(actor,false,true);guard.set_physics_process(false)
		for step in 100:
			guard._physics_process(1.0/60.0);defence_motion.set_process(false);defence_motion._process(1.0/60.0)
			vitality._physics_process(0.0)
			if step%3==0:await physics_frame
		print("SLAP_CONTACT ",JSON.stringify({"health_before":before_slap,"health_after":vitality.health,"hand":str(defender._skeleton.to_global(defender._skeleton.get_bone_global_pose(defender._skeleton.find_bone("hand_r")).origin)),"target_head":str(vitality.head_shape.global_position),"attack_delivered":guard.attack_delivered}))
		check(is_equal_approx(vitality.health,before_slap-5.0) and actor.get_meta("last_attacker",null)==defender,"female defensive slap contacts the actual receiver exactly once")
		defender.queue_free();contact_world.queue_free()
		check(policy.apply(vitality,1000.0,viewer,"weapon") and vitality.dead,"lethal civilian hit starts death")
		motion._process(.5);await capture(camera,actor.global_position,"DeathFall")
		motion._process(.6)
		check(actor.get_meta("dead",false) and motion.state=="down","death settles into grounded down animation")
		check(not actor.movement_enabled,"dead civilian stops travelling")
	# Actual production college builder and its existing residents, not stand-ins.
	var college=load("res://world/suryagarh/settlements/story_community.gd").new();world.add_child(college)
	while college.residents.size()<8:college._process(1.0);await process_frame
	college.set_process(false)
	var count:=0
	for person in college.residents:
		if person.get_parent()!=college.college:continue
		var lesson: Node=person.get_node("CollegeActivity");lesson.set_process(false)
		var reached: Dictionary={};var worst:=0.0
		for step in 1260:
			lesson.tick(1.0/30.0);reached[person.get_meta("college_action","")]=true
			worst=maxf(worst,maxf(person.get_meta("hand_contact_l",0.0),person.get_meta("hand_contact_r",0.0)))
		check(reached.has("teach") if person.get_meta("world_role")=="lecturer" else reached.has("read") and reached.has("write") and reached.has("talk") and reached.has("listen"),"independent academic phases "+str(person.name))
		check(worst<.03,"college palm contact "+str(worst))
		if "--playback" in OS.get_cmdline_user_args() and DisplayServer.get_name()!="headless" and (count==0 or person.get_meta("world_role")=="lecturer"):
			lesson.set_process(true)
			await playback(camera,viewer,person,{},44.0 if count==0 else 4.0)
			lesson.set_process(false)
		await capture(camera,person.global_position,"College"+str(count));count+=1
	check(count==4,"four existing college residents have real activities")
	world.queue_free();await process_frame;await process_frame
	print("NPC ACTIVITIES ",JSON.stringify({"passed":issues.is_empty(),"checks":checks,"issues":issues,"village":actual}))
	quit(0 if issues.is_empty() else 1)

func playback(camera: Camera3D, viewer: Node3D, actor: Node3D, record: Dictionary, duration: float) -> void:
	var began:=Time.get_ticks_msec();var frames:=0;var worst:=0.0;var seat:=0.0
	var before: float=record.get("elapsed",0.0)
	while float(Time.get_ticks_msec()-began)/1000.0<duration:
		viewer.global_position=actor.global_position+Vector3(0,0,3)
		camera.global_position=actor.global_position+Vector3(2.5,1.7,3.0);camera.look_at(actor.global_position+Vector3.UP*.8);camera.fov=48
		await process_frame;frames+=1
		worst=maxf(worst,maxf(actor.get_meta("hand_contact_l",0.0),actor.get_meta("hand_contact_r",0.0)))
		if actor.activity_age>.8:seat=maxf(seat,actor.get_meta("seat_error",0.0))
	check(worst<.03,"ordinary-time moving palm contact "+str(actor.name)+" "+str(worst))
	if not record.is_empty():
		var elapsed: float=record.elapsed-before
		check(absf(elapsed-duration)<maxf(.5,duration*.15),"ordinary-time work clock "+str(actor.name))
	print("ACTIVITY_PLAYBACK ",JSON.stringify({"actor":str(actor.name),"wall_seconds":float(Time.get_ticks_msec()-began)/1000.0,"rendered_frames":frames,"hand_m":worst,"seat_m":seat}))

func capture(camera: Camera3D, at: Vector3, label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	camera.global_position=at+Vector3(2.7,1.8,3.2);camera.look_at(at+Vector3.UP*.85);camera.fov=48
	for warm in 4:await process_frame
	RenderingServer.force_draw()
	var directory:=OS.get_environment("TLM_ACTIVITY_REVIEW")
	if not directory.is_empty():root.get_texture().get_image().save_png(directory+"/"+label+".png")
	if label in ["CartMaker", "Milkman", "Potter"] and not directory.is_empty():
		camera.global_position=at+Vector3(1.05,1.45,1.35)
		camera.look_at(at+Vector3.UP*(1.25 if label=="Milkman" else .95))
		camera.fov=40
		for warm in 4:await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(directory+"/"+label+"_close.png")
