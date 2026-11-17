extends "res://tools/world/validate_npc_activities_world.gd"
## Actual populated world, terrain, player, weapon and existing police owner.
func run() -> void:
	check(OS.get_user_data_dir()==OS.get_environment("TLM_EXPECT_USER_DATA"),"isolated crime save")
	var saves: Node=root.get_node("SaveManager")
	saves.save_root=OS.get_environment("TLM_ACTIVITY_REVIEW")
	saves.options.graphics_quality=1
	saves.options.fullscreen=false
	saves.options.vsync=false
	saves.apply_options()
	var loaded := "--load" in OS.get_cmdline_user_args()
	var world: Node3D=await ready_world(saves,loaded)
	var crime: Node3D=world.get_node("CombatEncounters")
	var player: CharacterBody3D=world.get_node("Player")
	if loaded:
		var found := false
		for record in crime.unidentified_scenes:
			if record.get("question_resolved",false) and record.get("inspected",false):found=true
		check(found and crime.wanted_level==0,"anonymous questioning and no stars survive fresh Continue")
		print("UNSEEN_CRIME ",JSON.stringify({"passed":issues.is_empty(),"checks":checks,"issues":issues,"fresh_continue":true}))
		saves.quit_game(0 if issues.is_empty() else 1)
		return
	player.set_physics_process(false)
	var site := choose_site(world, player)
	check(site.has("scene"),"found a clear elevated firing position in actual terrain")
	if not site.has("scene"):
		print("UNSEEN_CRIME ",JSON.stringify({"passed":false,"checks":checks,"issues":issues}))
		saves.quit_game(1)
		return
	var location: Vector3=site.scene
	var shooter: Vector3=site.shooter
	var actors: Array[Node3D]=[]
	for index in 3:
		var actor: Node3D=load("res://characters/npcs/thana/thana_officer.gd").new()
		actor.name=["CrimeVictim","SceneOfficer","SceneSupport"][index]
		actor.movement_enabled=false
		actor.set_meta("combat_faction","police")
		actor.add_child(load("res://characters/npcs/thana/burkundaz_motion.glb").instantiate())
		world.add_child(actor)
		var point:=location+Vector3(float(index)*2.0,0,0)
		point.y=world.layout.height(point.x,point.z)
		actor.global_position=point
		actor.rotation.y=PI
		actors.append(actor)
	for frame in 4:await physics_frame
	actors[0].get_node("Vitality").health=55.0
	player.global_position=shooter
	player.velocity=Vector3.ZERO
	player.inventory.add_item("enfield",1)
	var visual: Node3D=player.get_node("VisualRoot/CharacterVisual")
	var equipment: Node=visual.equipment
	equipment.select_weapon(1)
	equipment.stowed=false
	equipment._refresh()
	var rifle: Node=player.get_node("RifleCombat")
	rifle.set_process(false)
	var camera: Camera3D=rifle.camera
	camera.top_level=true
	for frame in 4:await physics_frame
	camera.global_position=player.global_position+Vector3.UP*1.4
	camera.look_at(actors[0].global_position+Vector3.UP*.8)
	var previous_count: int=crime.unidentified_scenes.size()
	player.set_physics_process(true)
	rifle.aiming=true
	rifle.rounds=1
	rifle.fire()
	player.set_physics_process(false)
	check(rifle.shots_fired==1 and actors[0].get_node("Vitality").dead,"real Enfield kills officer from higher terrain")
	check(crime.wanted_level==0 and crime.unidentified_scenes.size()==previous_count+1 and crime.unidentified_scenes.back().get("anonymous",false),"unwitnessed shot creates an anonymous scene without a star")
	if crime.unidentified_scenes.size()!=previous_count+1:
		print("UNSEEN_CRIME ",JSON.stringify({"passed":false,"checks":checks,"issues":issues,"site":str(site)}))
		saves.quit_game(1)
		return
	var record: Dictionary=crime.unidentified_scenes.back()
	var scene: Node
	for child in crime.get_children():
		if child.get_script()==load("res://combat/body_investigation.gd") and child.record==record:scene=child
	var deadline:=Time.get_ticks_msec()+90000
	while is_instance_valid(scene) and scene.phase!="inspect" and Time.get_ticks_msec()<deadline:
		await physics_frame
	check(is_instance_valid(scene) and scene.phase=="inspect","officer reaches the body in the real world")
	if not is_instance_valid(scene) or scene.phase!="inspect":
		print("UNSEEN_CRIME ",JSON.stringify({"passed":false,"checks":checks,"issues":issues,"site":str(site)}))
		saves.quit_game(1)
		return
	var responder: Node3D=scene.officer
	var visitor_at:=responder.global_position+responder.global_basis.z*4.0
	visitor_at.y=world.layout.height(visitor_at.x,visitor_at.z)+1.1
	scene.set_process(false)
	player.global_position=visitor_at
	player.velocity=Vector3.ZERO
	camera.top_level=false
	camera.position=Vector3.ZERO
	camera.rotation=Vector3.ZERO
	player.camera_pivot.global_rotation.y=responder.global_rotation.y
	player.set_physics_process(true)
	for frame in 25:await physics_frame
	scene.set_process(true)
	Input.action_press("move_forward")
	deadline=Time.get_ticks_msec()+30000
	while is_instance_valid(scene) and scene.phase!="question" and Time.get_ticks_msec()<deadline:
		await physics_frame
	Input.action_release("move_forward")
	player.set_physics_process(false)
	if is_instance_valid(scene) and scene.phase!="question":
		print("UNSEEN_CRIME ",JSON.stringify({"phase":scene.phase,"player":str(player.global_position),"officer":str(responder.global_position),"wanted":crime.wanted_level,"visible":crime.visible_to(responder),"start":str(visitor_at),"scene_position":str(location),"player_velocity":str(player.velocity),"story":player.get_meta("story_cinematic",false),"detention":player.get_meta("detention_action",""),"approach_age":scene.approach_age}))
	check(is_instance_valid(scene) and scene.phase=="question" and crime.wanted_level==0,"walking passerby enters questioning without a star")
	if is_instance_valid(scene) and scene.phase=="question":
		scene.set_process(false)
		if DisplayServer.get_name()!="headless":
			for frame in 4:await process_frame
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png(OS.get_environment("TLM_ACTIVITY_REVIEW").path_join("WorldQuestion.png"))
		scene.tick_question(player,17.0)
		check(scene.phase=="return" and record.get("question_resolved",false) and crime.wanted_level==0,"calm conversation releases player without a star")
	check(saves.save_game(world,1),"save after the anonymous conversation")
	if is_instance_valid(scene):scene.finish()
	await process_frame
	player.global_position=shooter+Vector3.UP*1.1
	player.velocity=Vector3.ZERO
	crime.queue_body_scene(location,null,true)
	var flight_record: Dictionary=crime.unidentified_scenes.back()
	var flight_scene: Node
	for child in crime.get_children():
		if child.get_script()==load("res://combat/body_investigation.gd") and child.record==flight_record:flight_scene=child
	deadline=Time.get_ticks_msec()+60000
	while is_instance_valid(flight_scene) and flight_scene.phase!="inspect" and Time.get_ticks_msec()<deadline:
		await physics_frame
	check(is_instance_valid(flight_scene) and flight_scene.phase=="inspect","a second anonymous scene assembles officers")
	if is_instance_valid(flight_scene) and flight_scene.phase=="inspect":
		var flight_officer: Node3D=flight_scene.officer
		visitor_at=flight_officer.global_position+flight_officer.global_basis.z*2.0
		visitor_at.y=world.layout.height(visitor_at.x,visitor_at.z)+1.1
		flight_scene.set_process(false)
		player.global_position=visitor_at
		player.velocity=Vector3.ZERO
		player.camera_pivot.global_rotation.y=flight_officer.global_rotation.y
		player.set_physics_process(true)
		for frame in 25:await physics_frame
		flight_scene.set_process(true)
		deadline=Time.get_ticks_msec()+15000
		while is_instance_valid(flight_scene) and flight_scene.phase!="question" and Time.get_ticks_msec()<deadline:
			await physics_frame
		check(is_instance_valid(flight_scene) and flight_scene.phase=="question","real player is stopped for the second questioning")
		if is_instance_valid(flight_scene) and flight_scene.phase=="question":
			Input.action_press("move_backward")
			Input.action_press("sprint")
			deadline=Time.get_ticks_msec()+10000
			while crime.wanted_level==0 and Time.get_ticks_msec()<deadline:
				await physics_frame
			Input.action_release("move_backward")
			Input.action_release("sprint")
			player.set_physics_process(false)
			check(crime.wanted_level==1 and crime.evidence.back().kind=="fled_questioning","normal sprint input triggers a one-star police report in the populated world")
			for frame in 15:await physics_frame
			var sent:=false
			for patrol in crime.patrols:
				if patrol.get("state","")=="pursue":sent=true
			check(sent,"one-star report alerts available police patrols")
	if crime.wanted_level==1:
		var saved_crime: Dictionary=crime.export_crime_state()
		crime.restore_crime_state(saved_crime)
		check(crime.wanted_level==1 and crime.evidence.back().kind=="fled_questioning","flight suspicion survives crime-state round trip")
		check(not saves.save_game(world,2) and saves.last_error=="Cannot save during pursuit or custody","existing pursuit save restriction remains in effect")
	print("UNSEEN_CRIME ",JSON.stringify({"passed":issues.is_empty(),"checks":checks,"issues":issues,"scene":str(location),"shooter":str(shooter)}))
	saves.quit_game(0 if issues.is_empty() else 1)

func choose_site(world: Node3D, player: CharacterBody3D) -> Dictionary:
	var witnesses := get_nodes_in_group("combat_actors")
	var space := world.get_world_3d().direct_space_state
	for x in range(-800,801,80):
		for z in range(-760,721,80):
			var low:=Vector3(float(x),world.layout.height(x,z),float(z))
			var high:=Vector3(float(x),world.layout.height(x,z+40),float(z+40))
			if low.y < 2.0 or high.y-low.y < 2.0 or high.y-low.y > 16.0:continue
			var crowded:=false
			for witness in witnesses:
				if witness is Node3D and witness.global_position.distance_to(low)<45.0:
					crowded=true
					break
			if crowded:continue
			var ray:=PhysicsRayQueryParameters3D.create(high+Vector3.UP*1.4,low+Vector3.UP*.8,1)
			ray.exclude=[player.get_rid()]
			if space.intersect_ray(ray).is_empty():
				return {"scene":low,"shooter":high}
	return {}
