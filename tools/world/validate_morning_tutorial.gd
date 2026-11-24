extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func press(action: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event
func quiet_unrelated(node: Node, player: Node, coach: Node) -> void:
	if node == player or node == coach: return
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children(): quiet_unrelated(child,player,coach)
func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i(1280,720)
	var world: Node = load(root.get_node("SaveManager").WORLD).instantiate()
	root.add_child(world)
	current_scene = world
	for i in 12: await process_frame
	var player: Node = world.get_node("Player")
	while world.get_node_or_null("LiveCarts/VillageStationCoach")==null:await process_frame
	var coach: Node3D = world.get_node("LiveCarts/VillageStationCoach")
	quiet_unrelated(world,player,coach)
	var hud: Control = player.get_node("UI/HUDRoot")
	var tutorial: Control = hud.get_node("MorningTutorial")
	var map: Control = player.get_node("UI/WorldMap")
	player.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	tutorial.set_process(false)
	var opening: Node = world.get_node_or_null("OpeningSequence")
	if opening == null:
		opening = preload("res://story/opening_sequence.gd").new()
		opening.name = "OpeningSequence"
		world.add_child(opening)
		opening.start(world)
	# The separate opening validator covers the cinematic timeline. Release its
	# ownership here so this focused check measures onboarding and real boarding.
	opening.morning()
	player.global_position = opening.home.to_global(Vector3(0,.94,8.2))
	opening._release()
	opening.set_process(false)
	tutorial.begin()
	check(not map.minimap.visible and not hud.get_node("SurvivalHUD").visible,"Movement starts with HUD hidden")
	tutorial._input(press("move_left"))
	check(tutorial.step == 0,"Wrong direction cannot complete forward lesson")
	tutorial._input(press("move_forward"))
	check(tutorial.step == 1,"Forward lesson advances")
	tutorial._input(press("move_right"))
	check(tutorial.step == 2 and map.minimap.visible,"Any lateral/back direction reveals map")
	check(map.minimap.position.is_equal_approx(Vector2(45,hud.size.y-200)),"Map anchors within left survival cluster")
	check(tutorial.prompt.position.is_equal_approx(Vector2(24,32)),"Only instructions at top left")
	check(not tutorial.has_method("_draw"),"Tutorial draws no highlight boxes")
	tutorial._input(press("move_forward"))
	check(tutorial.responded,"Movement acknowledges map introduction without opening it")
	world.get_node("GameMenu").open()
	tutorial._process(20.0)
	check(tutorial.step == 2 and tutorial.responded and tutorial.age == 0.0,"Paused map acknowledges without consuming reading time")
	world.get_node("GameMenu").close()
	tutorial._process(1.0)
	check(tutorial.step == 3 and not player.get_meta("tutorial_reading"),"Map explanation advances on bounded timeline")
	tutorial.begin()
	tutorial._process(9.99)
	check(tutorial.step == 9,"No-input introduction remains below ten-second deadline")
	tutorial._process(.01)
	check(tutorial.step == 10 and not tutorial.skip_hint.visible,"Entire UI introduction ends at ten seconds")
	tutorial.begin()
	var skip := InputEventKey.new()
	skip.physical_keycode=KEY_TAB;skip.pressed=true
	tutorial._input(skip)
	check(tutorial.step == 10 and hud.tutorial_reveal == 10,"Tab skips directly to coach guidance and reveals HUD")
	tutorial.restore_step(3)
	var before: Vector3=player.global_position
	Input.action_press("move_forward")
	for frame in 12:player._physics_process(1.0/60);await physics_frame
	Input.action_release("move_forward")
	check(player.global_position.distance_to(before)>.15,"Character moves while HUD explanation is active")
	for stage in range(3,10):
		check(tutorial.step == stage,"Ordered explanation")
		if stage <= 6:
			var rings := hud.get_node("SurvivalHUD").get_children()
			for i in 4: check(rings[i].visible == (i <= stage-3),"Only introduced diamonds visible")
		tutorial._process(1.0)
	check(tutorial.step == 10 and not player.get_meta("tutorial_reading"),"Reading unlocks for coach route")
	check(tutorial.coach==coach and map.waypoint.is_finite(),"Authored station coach and waypoint")
	var horse: Node3D = world.get_node("VillageHorse")
	player.global_position=horse.global_position+Vector3(1,.9,0)
	check(not horse.board(player),"Opening horse boarding is blocked")
	player.global_position=coach.to_global(Vector3(2,.9,2.2))
	check(coach.board_at(player,"RearPassengerRight","passenger"),"Actual station coach boards player")
	for frame in 160:
		await physics_frame
		if coach.boarding.transition.is_empty():break
	check(coach.boarding.transition.is_empty() and coach.rider==player,"Station coach seat transition completes")
	var travel: Node=coach.boarding.travel
	check(travel.destinations()==["Police Station"],"Only police station offered")
	check(not travel.request_trip("Town Hall"),"Other destinations rejected by request path")
	if player.inventory.get_item_count("rupees")<2:player.inventory.add_item("rupees",2)
	var money: int=player.inventory.get_item_count("rupees")
	check(travel.request_trip("Police Station"),"Station fare starts opening journey")
	check(player.inventory.get_item_count("rupees")==money-2,"Opening fare charged once")
	var story: Node=world.get_node("DevStory")
	check(story.active and story.kind=="opening_coach","Opening coach cinematic owns travel")
	if OS.get_environment("TLM_OPENING_COACH_NATURAL") == "1":
		story.set_process(true)
		var peak_door := 0.0
		var pull_away_start := Vector3.INF
		var deadline := Time.get_ticks_msec() + 60_000
		while story.active and Time.get_ticks_msec() < deadline:
			await process_frame
			if story.cue == "horse_dismount":
				for door: Node3D in coach.boarding_doors.values():
					peak_door = maxf(peak_door, absf(door.rotation.y))
			if story.cue == "coach_pull_away" and not pull_away_start.is_finite():
				pull_away_start = coach.global_position
				print("COACH departure start=",story.start_position," goal=",story.finish_position," rider=",coach.rider," clear=",coach.boarding._clearance_at(coach.global_position))
				if story.start_position == story.finish_position:
					for shape: CollisionShape3D in coach.boarding.clearance_shapes:
						var query := PhysicsShapeQueryParameters3D.new()
						query.shape = shape.shape
						query.transform = shape.global_transform
						var exclusions: Array[RID] = coach.boarding._vehicle_exclusions()
						if shape.get_meta("wheel_contact",false):
							exclusions.append_array(coach.boarding.wheel_terrain_cache.get("rids",[]))
						query.exclude = exclusions
						query.collision_mask = 1
						for hit in coach.get_world_3d().direct_space_state.intersect_shape(query):
							print("COACH clearance obstruction ",shape.position," ",hit.collider.get_path())

		story.set_process(false)
		check(peak_door > .4,"Arrival door swings open during dismount")
		for door: Node3D in coach.boarding_doors.values():
			check(absf(door.rotation.y) < .05,"Arrival door closes before coach leaves")
		check(pull_away_start.is_finite() and coach.global_position.distance_to(pull_away_start) > 2.0,"Empty coach pulls away after dismount")
	else:
		story.skip_cinematic()
	var station_at: Vector3=world.get_node("DevInquiry").station.to_local(player.global_position)
	check(not story.active and story.state=="awaiting_inquiry" and station_at.z>22 and station_at.z<42,"Arrival leaves player outside station gate before inquiry")
	check(tutorial.step==11 and not player.get_meta("morning_tutorial_active"),"Coach arrival completes tutorial")
	check(not player.has_meta("mounted_vehicle") and coach.rider==null,"Arrival releases coach and player")
	tutorial.restore_step(5)
	check(tutorial.step == 5 and not player.get_meta("tutorial_reading"),"Saved intermediate lesson restores")
	if DisplayServer.get_name() != "headless" and OS.get_environment("TLM_TUTORIAL_OUTPUT") != "" and OS.get_environment("TLM_STATION_ALARM_REVIEW")!="1":
		for value in [0,2,5,10]:
			tutorial.restore_step(value)
			for frame in 3: await process_frame
			check(not world.get_node("DevInquiry").objective.visible,"Story copy stays hidden during onboarding")
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("TLM_TUTORIAL_OUTPUT")+"/tutorial_%d.png" % value)
	if OS.get_environment("TLM_TUTORIAL_OUTPUT") != "" and OS.get_environment("TLM_STATION_ALARM_REVIEW")!="1":
		print("TUTORIAL REVIEW READY")
		var deadline := Time.get_ticks_msec()+45000
		while Time.get_ticks_msec()<deadline and not FileAccess.file_exists(OS.get_environment("TLM_TUTORIAL_OUTPUT")+"/review_done"):
			await process_frame
	tutorial.restore_step(11)
	check(hud.tutorial_reveal == 99 and not tutorial.visible,"Completed/legacy saves retain full HUD")
	# Actual retained MPFB station personnel, real vitality hooks and capsule movement.
	var encounters: Node3D=world.get_node("CombatEncounters")
	var station: Node3D=world.get_node("Settlement/DistrictPolice")
	var guard: Node3D=world.get_node("DevInquiry").guards[0]
	var victim: Node3D=station.get_node("ThanaStaff/Burkundaz")
	var prior_guard_duty: String=guard.duty_state
	var prior_guard_detainee: Node=guard.detainee
	player.set_meta("story_cinematic",false)
	player.set_meta("detention_action","")
	var anchor: Vector3=encounters.ground(station.to_global(Vector3(-3,0,25)))
	guard.global_position=anchor;guard.global_rotation.y=PI
	player.global_position=anchor+Vector3(0,.9,5)
	victim.global_position=anchor+Vector3(1,0,5)
	for frame in 3:await physics_frame
	var score: int=encounters.crime_score
	victim.get_node("Vitality").receive_hit(5,player,"kick")
	check(encounters.crime_score>score,"Actual kick raises wanted evidence")
	encounters.recruit_visible_police()
	check(guard.get_meta("police_engaged",false),"Actual rear-facing redcoat reacts to nearby assault")
	print("WANTED RESPONSE active_officers=",encounters.patrols.size())
	check(encounters.patrols.size()>1,"Wanted case activates multiple available world responders")
	var defence: Node=guard.get_node("SelfDefence")
	check(defence.face!=null and not defence.face.entries.is_empty(),"Actual station guard resolves late-created shared facial owner")
	# Isolate this responder so an officer already beside Arjun cannot arrest him first.
	for index in range(encounters.patrols.size()-1,-1,-1):
		if encounters.patrols[index].actor!=guard: encounters.patrols.remove_at(index)
	encounters.awareness_timer=1000.0
	encounters.escort.clear()
	player.set_meta("detention_action","")
	var start: Vector3=guard.global_position
	for frame in 180:
		encounters._tick(1.0/60.0)
		await physics_frame
	print("STATION RESPONSE travelled=",guard.global_position.distance_to(start)," wanted=",encounters.wanted_level)
	check(guard.global_position.distance_to(start)>.5,"Actual redcoat physically pursues with production capsule movement")
	guard.set_process(true)
	guard.get_node("CombatMotion").set_process(true)
	player.set_physics_process(true)
	var prior_health: float=player.health
	var fight_captures: Dictionary = {}
	var faced_attacker := false
	var review_camera: Camera3D
	if OS.get_environment("TLM_TUTORIAL_OUTPUT") != "" and OS.get_environment("TLM_STATION_ALARM_REVIEW")!="1":
		review_camera=Camera3D.new();world.add_child(review_camera)
		review_camera.global_position=guard.global_position+Vector3(3,1.8,2)
		review_camera.look_at((guard.global_position+player.global_position)*.5+Vector3.UP*.7)
		review_camera.make_current()
	for frame in 300:
		encounters._tick(1.0/60.0)
		await physics_frame
		if player.health < prior_health:
			var facing_attacker: Vector3=guard.global_position-player.global_position;facing_attacker.y=0
			if facing_attacker.length_squared()>.01 and player.get_node("VisualRoot").global_basis.z.dot(facing_attacker.normalized())>.85:faced_attacker=true
		if is_instance_valid(review_camera):
			var progress: float=guard.strike_progress
			var phase := "windup" if progress>.16 and progress<.28 else "contact" if progress>.43 and progress<.55 else "recovery" if progress>.70 and progress<.82 else ""
			if phase!="" and not fight_captures.has(phase):
				var midpoint: Vector3=(guard.global_position+player.global_position)*.5
				var toward: Vector3=player.global_position-guard.global_position;toward.y=0
				var side: Vector3=Vector3.UP.cross(toward.normalized())
				review_camera.global_position=midpoint+side*2.3+Vector3.UP*1.35
				review_camera.look_at(midpoint+Vector3.UP*.95)
				review_camera.make_current()
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(OS.get_environment("TLM_TUTORIAL_OUTPUT")+"/guard_fight_"+phase+".png")
				fight_captures[phase]=true
	check(player.health<prior_health,"Actual pursuing guard lands a close-range combat hit")
	check(faced_attacker,"Standing Arjun recovers facing his melee attacker")
	print("STATION RESPONSE close_health=",player.health," from=",prior_health)
	if not fight_captures.is_empty():
		print("GUARD FIGHT REVIEW READY")
		var fight_deadline := Time.get_ticks_msec()+45000
		while Time.get_ticks_msec()<fight_deadline and not FileAccess.file_exists(OS.get_environment("TLM_TUTORIAL_OUTPUT")+"/fight_done"):
			await process_frame
	score=encounters.crime_score
	var guard_after_fight := guard.global_transform
	var alarm: Node = station.get_node("ThanaAlarmBell")
	check(alarm.ringing==null,"Nonlethal station assault does not sound murder alarm")
	player.set_physics_process(false)
	player.global_position=station.to_global(Vector3(0,.9,22.65))
	victim.global_position=station.to_global(Vector3(.8,0,22.65))
	guard.global_position=station.to_global(Vector3(-.8,0,22.65))
	guard.global_rotation.y=station.global_rotation.y+PI*.5
	for frame in 3:await physics_frame
	var prior_camera := root.get_camera_3d()
	victim.get_node("Vitality").receive_hit(1000,player,"weapon")
	check(victim.get_meta("dead",false) and encounters.crime_score>=mini(25,score+10),"Actual police murder escalates wanted case")
	check(alarm.ringing!=null and alarm.ringing.is_running(),"Witnessed police killing rings the station bell")
	check(story.caption.visible and story.bars[0].visible and story.station_alert_remaining>0.0,"Witness alert uses subtitle and letterbox")
	check(root.get_camera_3d()==prior_camera and not player.get_meta("story_cinematic",false),"Alarm leaves gameplay camera and control ownership intact")
	var signaling: Node3D
	for candidate: Node in get_nodes_in_group("combat_actors"):
		if int(candidate.get_meta("station_alarm_gesture_until",0))>Time.get_ticks_msec():
			signaling=candidate
			break
	check(is_instance_valid(signaling),"Identifying witness receives alarm gesture")
	if is_instance_valid(signaling) and "station_alarm_pose" in signaling:
		await create_timer(.25).timeout
		signaling._process(.25)
		check(signaling.station_alarm_pose,"Witness raises a signaling hand during alert")
		var face: RefCounted = signaling.station_alarm_face
		var expression_visible := false
		if face != null:
			for entry: Dictionary in face.entries:
				var mesh: MeshInstance3D = entry.node
				var concern := mesh.find_blend_shape_by_name("dialogue_concern")
				if concern >= 0 and mesh.get_blend_shape_value(concern) > 0.05:
					expression_visible = true
					break
		check(expression_visible,"Witness applies the alarm expression to the existing MPFB face")
		print("STATION RESPONSE witness=",signaling.get_path()," position=",signaling.global_position)
		if DisplayServer.get_name()!="headless" and OS.get_environment("TLM_TUTORIAL_OUTPUT")!="":
			var alarm_camera:=Camera3D.new()
			world.add_child(alarm_camera)
			alarm_camera.global_position=signaling.to_global(Vector3(-1.25,1.72,2.6))
			alarm_camera.look_at(signaling.global_position+Vector3.UP*1.40)
			alarm_camera.make_current()
			await process_frame
			story._process(0.0)
			check(story.caption.is_visible_in_tree() and not story.caption.text.is_empty(),"Alarm caption remains visible with witness review camera")
			print("STATION RESPONSE caption rect=",story.caption.get_global_rect()," modulation=",story.caption.modulate," text=",story.caption.text)
			RenderingServer.force_draw(false)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("TLM_TUTORIAL_OUTPUT").path_join("station_witness_alarm.png"))
			prior_camera.make_current()
			alarm_camera.queue_free()
	if is_instance_valid(signaling) and "station_alarm_face" in signaling:
		signaling.remove_meta("station_alarm_gesture_until")
		signaling._process(0.0)
		check(signaling.station_alarm_face == null,"Witness face releases when the alert expires")
	story._process(3.0)
	check(not story.caption.visible and not story.bars[0].visible,"Alarm subtitle and bars clear")
	guard.global_transform=guard_after_fight
	player.set_physics_process(true)
	encounters.complete_custody(player)
	player.global_position=anchor+Vector3(20,.9,5)
	for frame in 600:
		encounters._tick(1.0/60.0)
		await physics_frame
		if encounters.patrols.is_empty(): break
	check(encounters.patrols.is_empty() and guard.global_position.distance_to(start)<.2,"Actual guard physically returns to prior post after case clears")
	check(not guard.has_meta("pursuit_fight_restore") and guard.duty_state==prior_guard_duty and guard.detainee==prior_guard_detainee,"Pursuit releases fight target and restores previous guard duty")
	if DisplayServer.get_name()!="headless" and OS.get_environment("TLM_STATION_ALARM_REVIEW")=="1":
		print("STATION ALARM REVIEW READY")
		var review_deadline:=Time.get_ticks_msec()+45000
		while Time.get_ticks_msec()<review_deadline and not FileAccess.file_exists(OS.get_environment("TLM_TUTORIAL_OUTPUT").path_join("alarm_done")):
			await process_frame
	print("MORNING TUTORIAL: ","PASS" if failures == 0 else "FAIL", " | movement, staged HUD, paused Escape map, timing, coach, restore")
	preload("res://tools/test_audio_cleanup.gd").stop(root)
	await preload("res://tools/test_audio_cleanup.gd").settle(self)
	# Keep world/material ownership intact until the standard audio-draining quit.
	await preload("res://tools/test_audio_cleanup.gd").finish(self,1 if failures else 0)
