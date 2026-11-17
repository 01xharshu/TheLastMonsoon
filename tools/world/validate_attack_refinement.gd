extends "res://tools/characters/validate_combat_rescue.gd"
const Aim=preload("res://combat/attack_aim.gd")
func run() -> void:
	root.size=Vector2i(1280,720)
	world=Node3D.new();root.add_child(world);current_scene=world
	var clock:=preload("res://world/suryagarh/systems/game_time_system.gd").new();clock.name="GameTimeSystem";world.add_child(clock)
	var floor:=StaticBody3D.new();world.add_child(floor)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(30,.2,50);shape.shape=box;shape.position.y=-.1;floor.add_child(shape)
	var ground_mesh:=MeshInstance3D.new();ground_mesh.mesh=BoxMesh.new();ground_mesh.mesh.size=box.size;ground_mesh.position.y=-.1;floor.add_child(ground_mesh)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-25,0);world.add_child(light)
	var ambience:=WorldEnvironment.new();var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color(.25,.3,.35);env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color.WHITE;env.ambient_light_energy=.7;ambience.environment=env;world.add_child(ambience)
	player=load("res://player/player.tscn").instantiate();world.add_child(player);player.position=Vector3(0,.9,0)
	visual=player.get_node("VisualRoot/CharacterVisual")
	var awareness: Node=load("res://world/suryagarh/civilian_awareness.gd").new();world.add_child(awareness);awareness.set_process(false);awareness.set_physics_process(false)
	british=make_actor("Enemy","res://characters/npcs/british/private_man.glb",Vector3(0,0,1),"british")
	for frame in 8:await physics_frame
	# Base military roster actors do not inherit household hand helpers.
	# Their self-defence must still pose both hands without script errors.
	var base_soldier := preload("res://characters/npcs/british/british_npc_actor.gd").new()
	base_soldier.name="BaseSoldier";base_soldier.position=Vector3(3,0,0)
	base_soldier.movement_enabled=false;base_soldier.foot_plant_enabled=false
	base_soldier.add_child(load("res://characters/npcs/british/private_man.glb").instantiate())
	world.add_child(base_soldier)
	for frame in 3:await physics_frame
	var base_defence: Node=base_soldier.get_node("SelfDefence")
	base_defence.guarding=true
	base_defence._process(.016)
	check(base_soldier.has_meta("hand_contact_l") and base_soldier.has_meta("hand_contact_r"),"base military rig raises both hands during defence")
	base_defence.finish(true);base_soldier.queue_free()
	if OS.get_environment("TLM_ATTACK_REVIEW") != "":
		camera=Camera3D.new();world.add_child(camera);camera.make_current();player.get_node("UI").hide()
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	player.set_process_input(false);player.set_process_unhandled_input(false)
	var family_kit: Node=load("res://player/chacha_kit.gd").new();family_kit.name="ChachaKit";player.add_child(family_kit)
	# Check the real shared NPC strike has a loaded shoulder and transfers
	# through the pelvis/knees, rather than moving only the punching arm.
	var strike_clip: Animation=british.animation_player.get_animation("combat/strike")
	for bone in ["pelvis","spine_01","calf_l"]:
		var path:=NodePath(str(british.get_path_to(british._skeleton))+":"+bone)
		var track:=strike_clip.find_track(path,Animation.TYPE_ROTATION_3D)
		check(track>=0 and strike_clip.rotation_track_interpolate(track,.08).angle_to(strike_clip.rotation_track_interpolate(track,.44))>.025,"strike transfers body weight through "+bone)
	var vitality: Node=british.get_node("Vitality")
	vitality.health=1000.0
	var aim_camera: Camera3D=player.get_node("CameraPivot/SpringArm3D/Camera3D")
	player.get_node("CameraPivot").rotation=Vector3(0,PI,0)
	aim_camera.look_at(Vector3(0,1.2,1))
	# Low arc reaches the actual selected point at varied ranges/elevations.
	for destination in [Vector3(0,1.2,12),Vector3(0,4,35),Vector3(5,-2,45)]:
		var origin:=Vector3(0,1.4,0)
		var direction:=Aim.launch_direction(origin,destination,52,9.8)
		var horizontal:=Vector2(destination.x-origin.x,destination.z-origin.z).length()
		var time:=horizontal/(Vector2(direction.x,direction.z).length()*52.0)
		var impact:=origin+direction*52*time+Vector3.DOWN*4.9*time*time
		check(impact.distance_to(destination)<.002,"ballistic aim reaches selected elevated/lowered point "+str(destination))
	# Different incoming sides and weapon profiles deform the same retained rig.
	var rotations: Array[Quaternion]=[]
	for direction in [Vector3.RIGHT,Vector3.LEFT]:
		Policy.apply(british.get_node("BodyCollider"),12,player,"punch",Vector3(0,1.2,1),direction)
		await _physics_ticks(10)
		rotations.append(british._skeleton.get_bone_pose_rotation(british._skeleton.find_bone("spine_02")))
	check(rotations[0].angle_to(rotations[1])>.03,"opposite impact directions produce different torso reactions")
	for kind in ["sword","spear","arrow"]:
		check(Policy.apply(british.get_node("BodyCollider"),12,player,kind,Vector3(0,1.2,1),Vector3.FORWARD),kind+" supplies actual hit context")
		check(british.get_meta("impact_context").kind==kind and british.get_node("CombatMotion").state=="hit",kind+" triggers animated victim reaction")
		await _physics_ticks(10)
		await attack_snap("victim_"+kind,british.position)
		await _physics_ticks(35)
	vitality.receive_hit(1,player,"punch")
	check(not british.has_meta("impact_context"),"legacy direct hits cannot reuse stale arrow impact")
	await _physics_ticks(45)
	# Actual spear contact, once per thrust, with full camera pitch retained.
	player.inventory.add_item("spear",1)
	var spear: Node=player.get_node("ChachaKit");spear.equip("spear")
	var before: float=vitality.health
	check(spear.strike(),"actual spear thrust starts")
	await _physics_ticks(12)
	print("SPEAR SUPPORT metres=",spear.support_error)
	check(spear.support_error<.05,"spear leading hand meets shaft during thrust")
	await attack_snap("spear_thrust",player.position-Vector3.UP*.9)
	await _physics_ticks(28)
	print("SPEAR REFINEMENT health=",vitality.health," before=",before," landed=",spear.landed)
	check(vitality.health==before-28,"spear shaft/tip contact damages actual MPFB receiver once")
	# Live bow camera targeting, real arrow flight and rig-following embed.
	spear.active=false;spear.spear.hide()
	player.inventory.add_item("bow",1);player.inventory.add_item("arrow",4)
	visual.equipment.selected=2;visual.equipment.stowed=false;visual.equipment._refresh()
	british.position=Vector3(0,0,8);vitality.health=1000
	await _physics_ticks(45)
	aim_camera.look_at(british.global_position+Vector3.UP*1.2)
	Input.action_press("aim")
	await _physics_ticks(65)
	var bow: Node=player.get_node("BowCombat")
	check(bow.aiming and bow.draw_fraction>.95,"holding aim draws actual bow")
	var contact_errors: Dictionary=visual.equipment.held_contact_errors()
	check(contact_errors.bow_palm_m<.06 and contact_errors.bow_nock_m<.06,"drawn bow palms meet grip and nock")
	await attack_snap("bow_draw",player.position-Vector3.UP*.9)
	check(bow.fire(),"fully drawn bow releases carried arrow")
	Input.action_release("aim")
	await _physics_ticks(35)
	check(vitality.health==965,"camera-aimed ballistic arrow hits actual animated enemy once")
	check(not british._skeleton.find_children("ArrowImpactAttachment*","BoneAttachment3D",true,false).is_empty(),"embedded arrow follows victim skeleton instead of floating in world")
	var attachments: Array[Node]=british._skeleton.find_children("ArrowImpactAttachment*","BoneAttachment3D",true,false)
	if not attachments.is_empty():
		var attachment: BoneAttachment3D=attachments[0]
		var embedded: Node3D=attachment.get_child(0)
		var prior_local: Transform3D=embedded.transform
		var prior_world: Vector3=embedded.global_position
		british.set_process(false);british.get_node("CombatMotion").set_process(false);british.animation_tree.active=false
		var joint: int=british._skeleton.find_bone(attachment.bone_name)
		british._skeleton.set_bone_pose_rotation(joint,british._skeleton.get_bone_pose_rotation(joint)*Quaternion(Vector3.RIGHT,.3))
		british._skeleton.force_update_all_bone_transforms()
		await physics_frame
		check(embedded.transform.is_equal_approx(prior_local) and embedded.global_position.distance_to(prior_world)>.001,"embedded arrow moves with struck bone without sliding")
	await attack_snap("arrow_impact",british.position)
	var barrier:=StaticBody3D.new();world.add_child(barrier)
	var barrier_shape:=CollisionShape3D.new();var barrier_box:=BoxShape3D.new();barrier_box.size=Vector3(1,3,.1);barrier_shape.shape=barrier_box;barrier.position=Vector3(3,1,2);barrier.add_child(barrier_shape)
	await _physics_ticks(2)
	var blocked_arrow: Node3D=load("res://environment/weapons/period_arrow/arrow_projectile.gd").new();world.add_child(blocked_arrow)
	blocked_arrow.launch(Vector3(3,1,3),Vector3.BACK,player,Vector3(3,1,1))
	check(not blocked_arrow.active and blocked_arrow.hit_count==1 and blocked_arrow.global_position.z<2.1,"nock-to-tip obstruction stops arrow before it can spawn through a wall")
	# The live opponent must identify, face, guard, counter and visibly emote.
	var defence: Node=british.get_node("SelfDefence")
	defence.finish();british.set_meta("external_combat_motion",false)
	british.set_process(true);british.animation_tree.active=true
	british.get_node("CombatMotion")._process(1.0)
	british.position=Vector3(0,0,.85);british.rotation.y=0
	player.position=Vector3(0,.9,0);visual.equipment.stowed=true;visual.equipment._refresh()
	vitality.receive_hit(1,player,"punch")
	await _physics_ticks(70)
	var facing: Vector3=player.position-british.position;facing.y=0
	check(british.global_basis.z.dot(facing.normalized())>.8,"struck opponent turns face-to-face toward Arjun")
	check(defence.face!=null and not defence.face.entries.is_empty(),"opponent uses real face expression geometry")
	if defence.face!=null and not defence.face.entries.is_empty():
		check(defence.face.entries[0].node.get_blend_shape_value(2)>.2,"anger/fear changes rendered facial expression weights")
	print("FACE CACHE build_usec=",defence.face_build_usec," cached_sources=",awareness.mesh_cache.size())
	await attack_snap("opponent_face_and_guard",british.position)
	var old_health: float=player.health
	await _physics_ticks(180)
	check(player.health<old_health,"provoked opponent counterattacks with actual fist contact")
	british.get_node("CombatMotion")._process(1.0);defence.counter_age=-1;defence.cooldown=10
	await _physics_ticks(3)
	before=vitality.health
	vitality.receive_hit(10,player,"punch")
	check(is_equal_approx(vitality.health,before-3),"frontal defensive guard reduces incoming unarmed damage")
	british.get_node("CombatMotion")._process(1.0)
	player.inventory.add_item("talwar",1);visual.equipment.selected=0;visual.equipment.stowed=false;visual.equipment._refresh()
	player.get_node("TalwarSlash").elapsed=0
	defence.cooldown=0;defence.counter_age=-1
	var old_position: Vector3=british.position
	defence._physics_process(.016)
	for frame in 12:defence._physics_process(.016)
	check(british.position.distance_to(old_position)>.15,"opponent takes supported preventive step against blade windup")
	player.get_node("TalwarSlash").elapsed=.68
	defence.finish()
	check(not british.get_meta("defending",false),"self-defence releases its movement/guard owner cleanly")
	# Awareness alone guards rather than attacking; patrol motion resumes physically.
	defence.alert(player,false);defence.cooldown=0
	old_health=player.health
	for frame in 45:await physics_frame
	check(not defence.provoked and player.health==old_health,"weapon awareness prepares defence without unprovoked attacks")
	await attack_snap("guard_pose",british.position)
	defence.finish(true)
	british._home=british.position;british._clock=0;british.movement_enabled=true
	defence.alert(player,false)
	defence._physics_process(.016)
	var interrupted: Vector3=british.position
	defence.step_away(Vector3(0,0,.25))
	defence.finish()
	for frame in 180:
		await physics_frame
		if not defence.active:break
	check(not defence.active and british.movement_enabled and british.position.distance_to(interrupted)<.12,"self-defence returns physically before resuming original patrol")
	defence.finish(true);british.movement_enabled=false
	british.position=Vector3(0,0,5);british.rotation.y=PI
	british.get_node("CombatMotion")._process(1.0)
	visual.equipment.selected=2;visual.equipment.stowed=false;visual.equipment._refresh()
	bow.aiming=true;defence.alert(player,true);defence.cooldown=0
	old_position=british.position
	defence._physics_process(.016)
	for frame in 12:defence._physics_process(.016)
	check(absf(british.position.x-old_position.x)>.15,"provoked opponent evades visible ranged aiming instead of standing idle")
	bow.aiming=false;defence.finish(true)
	british.movement_enabled=true;defence.alert(player,false);defence._physics_process(.016)
	check(british.get_meta("defence_previous_movement",false),"defence preserves movement state for police takeover")
	british.set_meta("external_combat_motion",true)
	defence._physics_process(.016)
	check(not british.get_meta("defending",false) and british.walk_direction==1.0,"external owner receives clean motion and gait handoff")
	british.set_meta("external_combat_motion",false);defence.finish(true)
	if OS.get_environment("TLM_ATTACK_REVIEW") != "":
		print("ATTACK REVIEW READY")
		var until := Time.get_ticks_msec()+120000
		while Time.get_ticks_msec()<until and not FileAccess.file_exists(OS.get_environment("TLM_ATTACK_REVIEW")+"/attack_done"):
			await process_frame
	print("ATTACK REFINEMENT ","PASS" if errors.is_empty() else "FAIL", " ",errors)
	await preload("res://tools/test_audio_cleanup.gd").finish(self,0 if errors.is_empty() else 1)

func attack_snap(label: String, focus: Vector3) -> void:
	if not is_instance_valid(camera):return
	camera.global_position=focus+Vector3(-2,1.7,2.5)
	if label=="opponent_face_and_guard":
		camera.global_position=focus+Vector3(.55,1.65,-1.2)
		camera.look_at(focus+Vector3.UP*1.35)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("TLM_ATTACK_REVIEW")+"/"+label+".png")
		return
	camera.look_at(focus+Vector3.UP*.9)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("TLM_ATTACK_REVIEW")+"/"+label+".png")
