extends SceneTree
var failures: Array[String] = []
var rendered_phases: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value: failures.append(message); push_error(message)
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var clock := preload("res://world/suryagarh/systems/game_time_system.gd").new()
	clock.name = "GameTimeSystem"
	world.add_child(clock)
	clock.set_process(false)
	clock.advance_hours(11)
	var initial_day: int = clock.current_day
	var station = load("res://world/suryagarh/settlements/civic_building.gd").new()
	station.name = "DistrictPolice"
	station.police = true
	var settlement := Node3D.new()
	settlement.name = "Settlement"
	world.add_child(settlement)
	settlement.add_child(station)
	var player = load("res://player/player.tscn").instantiate()
	world.add_child(player)
	player.global_position = station.to_global(Vector3(9.5,.9,9))
	player.global_basis = station.global_basis
	for frame in 15: await physics_frame
	player.set_physics_process(false)
	var review_camera: Camera3D
	if DisplayServer.get_name() != "headless":
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1280,720)
		root.content_scale_size = root.size
		player.get_node("UI").hide()
		var light := DirectionalLight3D.new()
		world.add_child(light)
		light.rotation_degrees = Vector3(-50,-25,0)
		light.light_energy = 2.0
		review_camera = Camera3D.new()
		world.add_child(review_camera)
		review_camera.make_current()
	var coordinator = station.get_node("ThanaStaff/ArrestCoordinator")
	coordinator.set_physics_process(false)
	coordinator.custody_seconds = 2.0
	player.inventory.add_item("talwar",1)
	var visual = player.get_node("VisualRoot/CharacterVisual")
	visual.equipment.select_weapon(0)
	visual.equipment.stowed = false
	visual.equipment._refresh()
	player.health = 40.0
	var phases: Array[String] = []
	coordinator.phase_changed.connect(func(value: String): phases.append(value))
	check(coordinator.report_crime(player,"assault",player.global_position),"Witness did not start pursuit")
	var detention = player.get_node("DetentionComponent")
	var previous: Vector3 = player.global_position
	var resisted_escape := false
	var minimum_officer_gap := INF
	var contact_hits := 0
	var blocked_strike_checked := false
	var block_active := false
	var original_facing: Basis = player.get_node("VisualRoot").global_basis
	for frame in 1800:
		if coordinator.phase == "fight" and coordinator.fight_age >= .3 and not blocked_strike_checked:
			block_active = true
			player.set_meta("combat_blocking",true)
			var facing: Vector3 = coordinator.officer.global_position-player.global_position
			player.get_node("VisualRoot").global_rotation.y = atan2(facing.x,facing.z)
			player.survival.stamina = 100.0
		var stamina_before: float = player.survival.stamina
		var health_before: float = player.health
		coordinator._physics_process(.1)
		if player.health < health_before:
			contact_hits += 1
			if block_active:
				check(absf(health_before-player.health-1.6) < .01,"Police ignored frontal block damage reduction")
				check(absf(stamina_before-player.survival.stamina-5.0) < .01,"Police block did not charge stamina")
				blocked_strike_checked = true
				block_active = false
				player.remove_meta("combat_blocking")
				player.get_node("VisualRoot").global_basis = original_facing
			check(coordinator.officer.strike_contact_error < .10,"Police damage happened without fist contact")
		if coordinator.phase in ["fight","restraint"]:
			minimum_officer_gap = minf(minimum_officer_gap,Vector2(player.global_position.x-coordinator.officer.global_position.x,player.global_position.z-coordinator.officer.global_position.z).length())
		if coordinator.phase == "fight" and not resisted_escape:
			resisted_escape = true
			player.global_position += station.global_basis * Vector3(-3,0,0)
			previous = player.global_position
		detention._process(.1)
		if coordinator.phase == "booking":
			check(coordinator.clear_at(player.global_position-Vector3.UP*.9,.43),"Booking point intersects station furniture")
		if player.global_position.distance_to(previous) > 1.0:
			check(coordinator.transfer.curtain.color.a >= .999,"Transfer happened before full black")
		previous = player.global_position
		await process_frame
		if review_camera != null:
			review_camera.global_position = player.global_position + Vector3(-2.1,1.0,2.4)
			review_camera.look_at(player.global_position)
			var phase: String = coordinator.phase
			if phase in ["fight","restraint","booking","custody","return","station_fade_in"] and coordinator.phase_age > (.5 if phase == "fight" else (1.5 if phase == "custody" else .3)) and not rendered_phases.has(phase):
				rendered_phases[phase] = true
				if phase == "fight":
					review_camera.global_position = coordinator.officer.global_position + Vector3(2.3,1.2,0.6)
					review_camera.look_at(player.global_position.lerp(coordinator.officer.global_position,0.5)+Vector3.UP*.4)
					coordinator.officer._process(1.0/60.0)
				var output := OS.get_environment("TLM_TEST_OUTPUT")
				if not output.is_empty():
					await process_frame
					await process_frame
					RenderingServer.force_draw(false)
					root.get_texture().get_image().save_png(output.path_join("police_"+phase+".png"))
		if coordinator.phase == "idle": break
	for required in ["approach","fight","restraint","station_fade_out","station_fade_in","booking","jail_fade_out","jail_fade_in","custody","custody_fade_out","time_passage","release_fade_in","return","idle"]:
		check(required in phases,"Missing phase: " + required)
	check(blocked_strike_checked,"Police never exercised the player block rules")
	check(contact_hits > 0,"Police never landed a contact-validated strike")
	check(resisted_escape and phases.count("approach") >= 2,"Backing away did not resume pursuit")
	check(minimum_officer_gap > .70,"Pursuing officer overlapped the suspect")
	check(clock.current_day == initial_day+3,"Sentence did not advance three days")
	check(clock.current_hour == 6 and clock.current_minute == 0,"Release was not at 6 AM")
	check(player.health >= 20 and player.health < 40,"Police fight lacked nonlethal damage")
	check(not coordinator.gate.locked,"Release left cell locked")
	check(coordinator.clear_at(player.global_position-Vector3.UP*.9,.43),"Release porch lacks safe standing clearance")
	check(not coordinator.transfer.layer.visible,"Release left the fade visible")
	check(detention.mode.is_empty(),"Release left player controls detained")
	check(station.to_local(player.global_position).distance_to(Vector3(0,.9,20)) < .1,"Release position is not on the station porch")
	var released_position: Vector3 = player.global_position
	Input.action_press("move_forward")
	for frame in 18:
		await physics_frame
		player._physics_process(1.0/60.0)
	Input.action_release("move_forward")
	check(player.global_position.distance_to(released_position) > .25,"Released player could not walk with actual controller input")
	player.velocity = Vector3.ZERO
	# Unsupported arrest UI waits without cancelling the witnessed incident.
	player.global_position = station.to_global(Vector3(9.5,.9,9))
	player.health = 80.0
	visual.equipment.stowed = true
	visual.equipment._refresh()
	coordinator.cooldown = 0.0
	for person in station.get_node("ThanaStaff").get_children():
		if person.get_meta("thana_role","") in ["daroga","burkundaz"]: person.set_meta("knocked_out",true)
	check(not coordinator.report_crime(player,"theft",player.global_position),"Incapacitated police witnessed an arrest")
	for person in station.get_node("ThanaStaff").get_children():
		if person.get_meta("thana_role","") in ["daroga","burkundaz"]: person.set_meta("knocked_out",false)
	player.set_meta("weapon_wheel_open",true)
	check(coordinator.report_crime(player,"theft",player.global_position),"Second witnessed incident failed")
	for frame in 400:
		coordinator._physics_process(.1)
		await process_frame
	check(coordinator.phase == "approach" and detention.mode.is_empty(),"Open wheel cancelled incident or forced detention")
	player.remove_meta("weapon_wheel_open")
	for frame in 20:
		coordinator._physics_process(.1)
		detention._process(.1)
		await process_frame
		if coordinator.phase == "restraint": break
	check(coordinator.phase == "restraint","Closing wheel did not allow arrest")
	# Abort must also remove a partially visible screen and restore custody controls.
	coordinator.transfer.start()
	coordinator.transfer.opacity(.5)
	coordinator.officer.set_meta("knocked_out",true)
	coordinator._physics_process(.1)
	check(coordinator.phase == "idle","Officer incapacitation did not abort transfer")
	for frame in 20: detention._process(.1)
	check(detention.mode.is_empty(),"Aborted transfer retained player controls")
	check(not coordinator.transfer.layer.visible,"Abort left screen covered")
	coordinator.officer.set_meta("knocked_out",false)
	coordinator.cooldown = 0.0
	visual.equipment.stowed = false
	check(coordinator.report_crime(player,"assault",player.global_position),"Obstruction fixture could not start incident")
	coordinator.officer.duty_state = "fight"
	coordinator.fight_age = .4
	coordinator.strike_landed = false
	coordinator.set_phase("fight")
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(1.4,2.0,.08)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	world.add_child(wall)
	wall.global_position = player.global_position.lerp(coordinator.officer.global_position,.5)
	wall.global_position.y = station.global_position.y+1.0
	var between: Vector3 = player.global_position-coordinator.officer.global_position
	wall.rotation.y = atan2(between.x,between.z)
	await physics_frame
	var before_wall_health: float = player.health
	coordinator.officer.set_meta("combat_action","hit")
	coordinator._physics_process(.1)
	check(player.health == before_wall_health and coordinator.officer.strike_progress < 0.0,"Staggered officer still landed a punch")
	coordinator.officer.set_meta("combat_action","")
	coordinator.fight_age = .4
	coordinator._physics_process(.1)
	check(player.health == before_wall_health,"Police struck through an intervening wall")
	check(coordinator.phase != "fight","Blocked strike did not abandon the punch")
	wall.free()
	coordinator.abort()
	# Production road-police logic and deferred crime identity share the custody loop.
	var road_logic = load("res://tools/world/police_logic_fixture.gd").new()
	world.add_child(road_logic)
	var guard = station.get_node("ThanaStaff/Daroga")
	var other_guard = station.get_node("ThanaStaff/Burkundaz")
	coordinator.cooldown = 0.0
	guard.remove_meta("last_attacker")
	coordinator.report_assault(guard)
	road_logic.report_assault(guard,other_guard)
	check(coordinator.phase == "idle" and not road_logic.wanted,"Unknown or NPC attacker blamed Arjun")
	check(guard.get_node("Vitality").receive_hit(1.0,player,"punch"),"Real damage receiver did not accept player hit")
	guard.set_meta("last_attacker",other_guard)
	await process_frame
	check(road_logic.wanted,"Deferred assault lost the original attacker identity")
	var saves = root.get_node("SaveManager")
	check(saves.police_case_active(player),"Wanted player was saveable")
	var old_save_root: String = saves.save_root
	var temporary_output := OS.get_environment("TLM_TEST_OUTPUT")
	if not temporary_output.is_empty():
		saves.save_root = temporary_output.path_join("blocked_saves")
		check(not saves.save_game(world,1),"Wanted save escaped the guard")
		check(saves.last_error == "Cannot save during pursuit or custody","Blocked save lacked a useful explanation")
		check(not DirAccess.dir_exists_absolute(saves.save_root),"Blocked save created output")
		var menu = load("res://ui/game_menu.gd").new()
		world.add_child(menu)
		menu.overlay.show()
		menu.show_slots(true)
		for child in menu.column.get_children():
			if child is Button:
				child.pressed.emit()
				break
		var explanation_visible := false
		for label in menu.column.find_children("*","Label",true,false):
			if label.text == "Cannot save during pursuit or custody": explanation_visible = true
		check(explanation_visible,"Save menu hid the police-case explanation")
		if review_camera != null:
			await create_timer(.6).timeout
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png(temporary_output.path_join("police_save_blocked.png"))
		menu.free()
		saves.save_root = old_save_root
	coordinator.abort()
	for frame in 20: detention._process(.1)
	check(detention.begin_detention("arrest"),"Road capture could not hold player")
	var marker := Label3D.new()
	other_guard.add_child(marker)
	road_logic.patrols.append({"actor":other_guard,"points":PackedVector3Array([other_guard.global_position]),"index":0,"step":1,"state":"pursue","sense":0.0,"attack_age":0.5,"hit":false,"marker":marker,"seen":true})
	var custody_health: float = player.health
	road_logic.aggressor = guard
	road_logic.peasant = other_guard
	road_logic.encounter_state = "fixture"
	road_logic._tick(.1)
	check(player.health == custody_health and other_guard.travel_speed == 0.0,"Other patrol attacked a detained player")
	road_logic.escort = {"actor":guard,"state":"capture","age":2.8,"route":PackedVector3Array(),"index":0}
	road_logic.update_capture(.1)
	check(road_logic.escort.is_empty() and coordinator.phase == "station_fade_out","Road arrest bypassed cinematic station transfer")
	check(saves.police_case_active(player),"Custody player was saveable")
	for frame in 1500:
		coordinator._physics_process(.1)
		detention._process(.1)
		await process_frame
		if coordinator.phase == "idle": break
	check(coordinator.phase == "idle","Road-arrest custody did not finish")
	check(not road_logic.wanted and road_logic.patrols[0].state == "patrol","Sentence completion retained pursuit")
	check(not saves.police_case_active(player),"Released player remained save-blocked")
	check(not guard.get_meta("dead",false),"Custody lost the external officer")
	# Escape breaks restraint, not the outstanding case. Only adjudicated custody clears it.
	check(detention.begin_detention("arrest"),"Escape fixture could not begin restraint")
	road_logic.wanted = true
	road_logic.escape_press = 4
	road_logic.escort = {"actor":guard,"state":"capture","age":0.0,"route":PackedVector3Array(),"index":0}
	road_logic.update_capture(.1)
	for frame in 20: detention._process(.1)
	check(road_logic.escort.is_empty() and road_logic.wanted,"Breaking restraint incorrectly pardoned the case")
	check(saves.police_case_active(player),"Escape enabled saving while wanted")
	road_logic.complete_custody(other_guard)
	check(road_logic.wanted,"Another actor cleared Arjun's case")
	road_logic.complete_custody(player)
	# A removed officer or unavailable station cannot strand the player in restraint.
	for missing_dependency in ["officer","station"]:
		check(detention.begin_detention("arrest"),"Interrupted capture could not start")
		road_logic.wanted = true
		road_logic.escort = {"actor":null if missing_dependency == "officer" else guard,"state":"capture","age":0.0}
		if missing_dependency == "station": road_logic.station = null
		road_logic._process(.1)
		road_logic.update_capture(.1)
		for frame in 20: detention._process(.1)
		check(road_logic.escort.is_empty() and player.get_meta("detention_action","") == "","Missing " + missing_dependency + " stranded the player")
		check(road_logic.wanted,"Missing dependency pardoned the case")
		road_logic.station = station
		road_logic.complete_custody(player)
	road_logic.patrols.append({"actor":null,"marker":road_logic.patrols[0].marker,"state":"patrol","seen":false,"attack_age":0.0,"hit":false})
	road_logic.report_crime(player,"theft",player.global_position)
	road_logic._tick(.1)
	road_logic.complete_custody(player)
	road_logic.patrols.pop_back()
	# The road observer needs a live, unobstructed witness for theft.
	other_guard.global_position = player.global_position + Vector3(0,-.9,-1.2)
	other_guard.global_rotation.y = 0.0
	other_guard.body_collider.force_update_transform()
	await physics_frame
	other_guard.set_meta("knocked_out",true)
	road_logic.report_crime(player,"theft",player.global_position)
	check(not road_logic.wanted,"Incapacitated patrol witnessed theft")
	other_guard.set_meta("knocked_out",false)
	road_logic.report_crime(player,"theft",player.global_position+Vector3(100,0,0))
	check(not road_logic.wanted,"Distant fabricated theft was accepted")
	road_logic.report_crime(player,"theft",player.global_position)
	check(road_logic.wanted,"Live road-patrol theft witness failed")
	road_logic.aggressor = null
	road_logic.ground_exclusions.assign([player.get_rid(),guard.body_collider.get_rid(),other_guard.body_collider.get_rid()])
	road_logic.patrols[0].sense = 0.0
	road_logic._tick(.1)
	check(road_logic.patrols[0].state == "pursue","Road police stopped when the rescue actor was absent")
	road_logic.complete_custody(player)

	check(detention.begin_detention("arrest"),"Paused-transfer fixture could not begin detention")
	coordinator.transfer.start()
	coordinator.transfer.opacity(1.0)
	var pause_menu = load("res://ui/game_menu.gd").new()
	world.add_child(pause_menu)
	pause_menu.open()
	check(paused and pause_menu.layer > coordinator.transfer.layer.layer,"Opaque custody fade covered the pause menu")
	check(pause_menu.page == "main","Custody pause did not expose game controls")
	if review_camera != null:
		await create_timer(.6).timeout
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(temporary_output.path_join("police_pause_during_fade.png"))
	pause_menu.close()
	check(not paused and pause_menu.layer == pause_menu.previous_layer,"Closing custody pause did not restore pause/layer state")
	pause_menu.free()
	coordinator.abort()
	for frame in 20: detention._process(.1)
	if not temporary_output.is_empty():
		saves.save_root = temporary_output.path_join("released_saves")
		check(saves.save_game(world,1),"Released player could not create a normal save")
		var released_save: Dictionary = saves.read_slot(1)
		check(not released_save.is_empty(),"Released save did not read back")
		check(is_equal_approx(float(released_save.get("game_minutes",-1)),clock.total_game_minutes),"Released save lost the advanced morning clock")
		saves.save_root = old_save_root
	print("POLICE CUSTODY: ","PASS" if failures.is_empty() else "FAIL", " phases=",phases)
	world.free()
	quit(0 if failures.is_empty() else 1)
