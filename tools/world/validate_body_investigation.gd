extends "res://tools/world/validate_crime_perception.gd"
class SprintState extends Node:
	var is_sprinting := false
func run() -> void:
	var world:=Node3D.new();root.add_child(world);current_scene=world
	var clock: Node=load("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock)
	var player:=TestPlayer.new();player.name="Player";player.position=Vector3(30,0,30);world.add_child(player)
	var stance:=Stance.new();stance.name="StealthStance";player.add_child(stance)
	var floor:=StaticBody3D.new();world.add_child(floor)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(50,1,50);shape.shape=box;shape.position.y=-.5;floor.add_child(shape)
	var mesh:=MeshInstance3D.new();mesh.mesh=BoxMesh.new();mesh.scale=Vector3(50,.1,50);floor.add_child(mesh)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-30,0);world.add_child(light)
	var crime: Node3D=load("res://tools/world/police_movement_fixture.gd").new();world.add_child(crime);crime.player=player
	var officer: Node3D=load("res://characters/npcs/households/household_npc_actor.gd").new()
	officer.movement_enabled=false;officer.position=Vector3(0,0,-4);officer.set_meta("combat_faction","police")
	officer.add_child(load("res://characters/npcs/thana/burkundaz_motion.glb").instantiate());world.add_child(officer)
	var body: Node3D=load("res://characters/npcs/households/household_npc_actor.gd").new()
	body.movement_enabled=false;body.add_child(load("res://characters/npcs/british/private_man.glb").instantiate());world.add_child(body)
	await sync()
	body.get_node("Vitality").receive_hit(100.0,null,"weapon")
	var wall:=StaticBody3D.new();world.add_child(wall)
	var wall_shape:=CollisionShape3D.new();var wall_box:=BoxShape3D.new();wall_box.size=Vector3(2,2,.4);wall_shape.shape=wall_box;wall_shape.position=Vector3(0,1,-2);wall.add_child(wall_shape)
	await sync()
	var crossed_wall:=false
	var captured:=false
	var origin: Vector3=officer.position
	crime.queue_body_scene(Vector3.ZERO)
	var inspection=crime.get_children().filter(func(n):return n.get_script()==load("res://combat/body_investigation.gd"))[0]
	var arrived:=false;var moved:=false;var posed:=false
	var head: int=officer._bones.head
	for frame in 1600:
		await physics_frame
		moved=moved or officer.position.distance_to(origin)>.5
		if absf(officer.position.x)<1.1 and absf(officer.position.z+2)<.24:crossed_wall=true
		if is_instance_valid(inspection) and inspection.phase=="inspect":
			arrived=true
			posed=posed or officer._skeleton.get_bone_pose_rotation(head).angle_to(officer._base_rotations.head)>.15
			if not captured and inspection.inspect_age>2 and OS.get_environment("TLM_TUTORIAL_OUTPUT")!="":
				var camera:=Camera3D.new();world.add_child(camera);camera.position=Vector3(2.3,1.7,-2.5);camera.look_at(Vector3(0,.6,-.4));camera.make_current()
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(OS.get_environment("TLM_TUTORIAL_OUTPUT")+"/body_inspect.png")
				captured=true
		if not is_instance_valid(inspection):break
	check(moved and arrived,"real officer physically approaches unidentified crime scene")
	check(not crossed_wall,"anonymous alley report routes officer around solid obstruction")
	check(posed,"inspection visibly deforms real head rig")
	check(crime.wanted_level==0 and crime.evidence.is_empty(),"body inspection never identifies absent killer")
	check(crime.unidentified_scenes[0].inspected,"scene retains completed inspection")
	check(officer.position.distance_to(origin)<.2 and not officer.get_meta("inspecting_body",false),"officer returns to previous post and releases pose")
	var saved: Dictionary=crime.export_crime_state();crime.restore_crime_state(saved)
	check(crime.unidentified_scenes.size()==1 and crime.unidentified_scenes[0].inspected and crime.wanted_level==0,"unidentified report persists without wanted stars")
	crime.queue_body_scene(Vector3(4,0,0))
	var pending: Dictionary=crime.export_crime_state()
	crime.restore_crime_state(pending)
	check(crime.unidentified_scenes.size()==2 and not crime.unidentified_scenes[1].inspected and crime.wanted_level==0,"pending unidentified scene survives restore without identifying killer")
	for child in crime.get_children():
		if child.get_script()!=load("res://combat/body_investigation.gd") or child.is_queued_for_deletion():continue
		child._process(1.0)
		if not is_instance_valid(child.officer):continue
		officer.set_meta("police_engaged",true)
		child._process(.2)
		check(child.phase=="discover" and not officer.get_meta("inspecting_body",false),"wanted pursuit preempts inspection without discarding unidentified scene")
		officer.set_meta("police_engaged",false);officer.set_meta("external_combat_motion",false)
		child._process(1.0)
		check(is_instance_valid(child.officer),"unresolved inspection resumes when an officer is free")
		child.finish()
	# A report can dispatch an officer beyond the previous 35 m search radius.
	officer.position=Vector3(0,0,-45)
	officer.set_meta("external_combat_motion",false)
	crime.queue_body_scene(Vector3.ZERO,null,true)
	var distant_scene: Node
	var distant_record: Dictionary=crime.unidentified_scenes.back()
	for child in crime.get_children():
		if child.get_script()==load("res://combat/body_investigation.gd") and child.record==distant_record:distant_scene=child
	distant_scene.set_process(false)
	distant_scene._process(1.0)
	check(distant_scene.officer==officer,"anonymous scene dispatches a free officer from 45 metres")
	distant_record.inspected=true
	distant_scene.finish()
	await process_frame

	# Actual fatal damage reports no identity when nobody can see the shooter.
	crime.add_to_group("police_crime_observers")
	crime.crime_score=0;crime.wanted=false;crime.wanted_level=0;crime.evidence.clear()
	officer.position=Vector3(0,0,-4);officer.rotation.y=0
	officer.set_meta("external_combat_motion",false)
	var helper: Node3D=load("res://characters/npcs/households/household_npc_actor.gd").new()
	helper.name="SecondOfficer";helper.movement_enabled=false;helper.position=Vector3(3,0,-4);helper.set_meta("combat_faction","police");helper.set_meta("external_combat_motion",true)
	helper.add_child(load("res://characters/npcs/thana/burkundaz_motion.glb").instantiate());world.add_child(helper)
	crime.patrols.append({"actor":helper, "state":"patrol", "mount":null})
	var policy: Node = load("res://combat/body_investigation.gd").new()
	policy.encounters=crime
	check(policy.available_officer(helper),"available foot patrol can inspect a scene")
	helper.set_meta("station_records_duty",true)
	check(not policy.available_officer(helper),"station records duty is not interrupted")
	helper.set_meta("station_records_duty",false)
	helper.set_meta("mission_active",true)
	check(not policy.available_officer(helper),"mission-owned officer is not interrupted")
	helper.set_meta("mission_active",false)
	policy.free()
	var slain: Node3D=load("res://characters/npcs/households/household_npc_actor.gd").new()
	slain.name="UnseenVictim";slain.movement_enabled=false;slain.set_meta("combat_faction","police")
	slain.add_child(load("res://characters/npcs/thana/burkundaz_motion.glb").instantiate());world.add_child(slain)
	var sprint:=SprintState.new();sprint.name="SurvivalComponent";player.add_child(sprint)
	player.position=Vector3(0,8,40)
	await sync()
	slain.get_node("Vitality").health=55.0
	var exclusions: Array[RID] = [player.get_rid()]
	var shot: Dictionary = load("res://combat/ballistic_trace.gd").shoot(world.get_world_3d().direct_space_state, self, player.global_position+Vector3.UP*1.4, slain.global_position+Vector3.UP*.8, 60.0, exclusions, player)
	check(not shot.is_empty() and slain.get_meta("dead",false) and crime.wanted_level==0 and crime.evidence.is_empty(),"unwitnessed uphill ballistic police shooting creates no wanted identity")
	var anonymous: Dictionary=crime.unidentified_scenes.back()
	check(anonymous.get("anonymous",false),"fatal shooting creates an anonymous investigation")
	var scene: Node
	for child in crime.get_children():
		if child.get_script()==load("res://combat/body_investigation.gd") and child.record==anonymous:scene=child
	var gathered:=false
	for frame in 1000:
		await physics_frame
		if is_instance_valid(scene) and not scene.supporters.is_empty() and scene.supporters[0].actor.global_position.distance_to(Vector3.ZERO)<3.5:gathered=true
		if is_instance_valid(scene) and scene.phase=="inspect" and scene.inspect_age>.3:break
	check(is_instance_valid(scene) and scene.phase=="inspect" and gathered,"two officers including an ordinary patrol physically respond")
	player.global_position=officer.global_position+officer.global_basis.z*2.0
	for frame in 120:
		await physics_frame
		if is_instance_valid(scene) and scene.phase=="question":break
	check(is_instance_valid(scene) and scene.phase=="question" and crime.wanted_level==0,"visible passerby is questioned without identifying the shooter")
	if is_instance_valid(scene) and scene.phase=="question":
		scene.set_process(false)
		var competing: Node = load("res://combat/body_investigation.gd").new()
		competing.encounters=crime
		competing.record={"location":[0,0,0]}
		crime.add_child(competing)
		competing.officer=helper
		check(not competing.can_question(player),"one officer owns the conversation at a time")
		competing.queue_free()
		scene.tick_question(player,4.6)
		check("uncle" in scene.dialogue_label.text,"Arjun gives the peaceful answer")
		scene.tick_question(player,12.0)
		check(scene.phase=="return" and anonymous.get("question_resolved",false) and crime.wanted_level==0 and not player.has_meta("police_question_owner"),"completed conversation releases Arjun without a star")
		scene.set_process(true)
		for frame in 1500:
			await physics_frame
			if not is_instance_valid(scene):break
		check(not is_instance_valid(scene) and officer.global_position.distance_to(Vector3(0,0,-4))<.25 and helper.global_position.distance_to(Vector3(3,0,-4))<.25 and not officer.get_meta("inspecting_body",false) and not helper.get_meta("inspecting_body",false),"both officers physically return to their previous duties")
		if is_instance_valid(scene):scene.finish()
	await process_frame
	wall.position.x=100
	await sync()
	officer.position=Vector3(0,0,-2.5);officer.rotation.y=0
	player.position=Vector3(0,0,40)
	crime.queue_body_scene(Vector3.ZERO,null,true)
	var fleeing: Node
	var fresh: Dictionary=crime.unidentified_scenes.back()
	for child in crime.get_children():
		if child.get_script()==load("res://combat/body_investigation.gd") and child.record==fresh:fleeing=child
	fleeing.set_process(false);fleeing._process(1.0)
	if is_instance_valid(fleeing.officer):
		player.global_position=fleeing.officer.global_position+fleeing.officer.global_basis.z*2.0
		fleeing._process(.2)
	check(fleeing.phase=="question","second anonymous scene can question a passerby")
	if fleeing.phase=="question":
		sprint.is_sprinting=true
		player.global_position=fleeing.officer.global_position+fleeing.officer.global_basis.z*5.0
		fleeing._process(.2)
		check(crime.wanted_level==1 and crime.evidence.back().kind=="fled_questioning" and crime.response_pending,"visible flight raises one star and dispatches police")
		sprint.is_sprinting=false
	var saved_suspect: Dictionary=crime.export_crime_state()
	crime.restore_crime_state(saved_suspect)
	check(crime.wanted_level==1 and crime.evidence.back().kind=="fled_questioning","flight suspicion survives save/restore")
	crime.crime_score=0;crime.wanted=false;crime.wanted_level=0;crime.response_pending=false;crime.evidence.clear()
	for child in crime.get_children():
		if child.get_script()==load("res://combat/body_investigation.gd") and not child.is_queued_for_deletion():child.finish()
	crime.patrols.clear()
	officer.position=Vector3(0,0,-2.5);officer.rotation.y=0
	officer.set_meta("external_combat_motion",false)
	player.position=Vector3(0,0,40)
	crime.queue_body_scene(Vector3.ZERO,null,true)
	var approach: Node
	var approach_record: Dictionary=crime.unidentified_scenes.back()
	for child in crime.get_children():
		if child.get_script()==load("res://combat/body_investigation.gd") and child.record==approach_record:approach=child
	approach.set_process(false);approach._process(1.0)
	if is_instance_valid(approach.officer):
		player.global_position=approach.officer.global_position+approach.officer.global_basis.z*5.0
		approach._process(.2)
	check(approach.phase=="question_approach" and "stop" in approach.dialogue_label.text,"officer calls out before approaching the passerby")
	if approach.phase=="question_approach":
		sprint.is_sprinting=true
		player.global_position=approach.officer.global_position+approach.officer.global_basis.z*8.0
		approach._process(.2)
		check(crime.wanted_level==1 and crime.evidence.back().kind=="fled_questioning","visible flight after the stop request raises one star")
		sprint.is_sprinting=false
	if captured:
		print("BODY REVIEW READY")
		var deadline:=Time.get_ticks_msec()+30000
		while Time.get_ticks_msec()<deadline and not FileAccess.file_exists(OS.get_environment("TLM_TUTORIAL_OUTPUT")+"/body_done"):await process_frame
	print("BODY INVESTIGATION ","PASS" if failures.is_empty() else "FAIL",failures)
	await preload("res://tools/test_audio_cleanup.gd").finish(self,0 if failures.is_empty() else 1)
