extends SceneTree
var errors: Array[String]=[]
var world: Node3D
var player: CharacterBody3D
var encounters: Node3D
var station: Node3D
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:errors.append(label)
func review(_label: String) -> void:
	pass
func wait_ticks(count: int) -> void:
	for i in count:await physics_frame
func run() -> void:
	world=load("res://world/suryagarh/suryagarh_world.tscn").instantiate();root.add_child(world);current_scene=world
	player=world.get_node("Player");station=world.get_node("Settlement/DistrictPolice")
	await wait_ticks(12)
	encounters=world.get_node("CombatEncounters")
	check(encounters.patrols.size()==3,"three independent road patrols integrated")
	var starts: Array[Vector3]=[]
	for patrol in encounters.patrols:starts.append(patrol.actor.global_position)
	encounters.profile_enabled=true
	await wait_ticks(90)
	encounters.profile_enabled=false
	for i in 3:check(encounters.patrols[i].actor.global_position.distance_to(starts[i])>.5,"patrol "+str(i)+" moves on surveyed road")
	check(encounters.encounter_state=="waiting" and not encounters.wanted,"encounter waits for proximity")
	player.position=encounters.peasant.global_position+Vector3(-2,.9,0)
	await wait_ticks(10)
	check(encounters.encounter_state=="beating","approach triggers actual beating sequence")
	await review("approach triggers actual beating sequence")
	await wait_ticks(320)
	check(encounters.peasant.get_meta("knocked_out",false) and not encounters.peasant.get_node("Vitality").dead,"repeated British strikes cause living civilian fall")
	await review("repeated British strikes cause living civilian fall")
	check(not encounters.wanted,"AI abuse does not blame Arjun")
	encounters.aggressor.get_node("Vitality").receive_hit(12,player,"punch")
	await wait_ticks(6)
	check(encounters.wanted,"player intervention creates police response")
	check(encounters.encounter_state in ["rescued","recovering"],"intervention stops abuse")
	await review("intervention stops abuse")
	await wait_ticks(200)
	check(not encounters.peasant.get_meta("knocked_out",false),"rescued peasant recovers")
	var patrol: Dictionary=encounters.patrols[0]
	var officer: Node3D=patrol.actor
	encounters.set_physics_process(false)
	# Actual ray visibility, blocked visibility, and per-actor alert.
	player.global_position=officer.global_position+officer.global_basis.z*2+Vector3.UP*.9
	await wait_ticks(4)
	check(encounters.visible_to(officer),"police front sight detects Arjun")
	encounters.wanted=true;patrol.state="patrol";patrol.sense=0
	encounters._physics_process(.016)
	check(patrol.state=="pursue" and patrol.marker.visible,"visible wanted player alerts only this officer")
	await review("visible wanted player alerts only this officer")
	# Rear capture uses the real detention component and supports explicit escape.
	var anchor: Vector3=encounters.ground(Vector3(320,0,150))
	player.global_position=anchor+Vector3.UP*.9
	player.get_node("VisualRoot").global_rotation.y=0
	officer.global_position=anchor+Vector3(0,0,-.8)
	patrol.state="pursue";encounters.escort={}
	await wait_ticks(4)
	encounters._physics_process(.016)
	check(not encounters.escort.is_empty() and encounters.escort.state=="capture","police catch from behind")
	if not encounters.escort.is_empty():
		var press:=InputEventAction.new();press.action="jump";press.pressed=true
		for i in 4:encounters._unhandled_input(press)
		encounters.update_capture(.016)
		check(encounters.escort.is_empty(),"four separate escape inputs release rear capture")
		await wait_ticks(100)
		check(player.get_meta("detention_action","")=="","escape restores player controls")
	# The city road graph connects distant routes to the station approach.
	for at in [Vector3(345,12,252),Vector3(755,10,285),Vector3(500,8.5,470)]:
		var path: PackedVector3Array=encounters.road_path(at,anchor)
		check(path.size()>2 and path[-1].distance_to(station.to_global(Vector3(0,0,16.4)))<.01,"road escort path connects "+str(at))
	# Full continuous road approach -> station route -> cell -> release.
	player.global_position=anchor+Vector3.UP*.9
	player.get_node("VisualRoot").global_rotation.y=0
	officer.global_position=anchor+Vector3(0,0,-.8)
	patrol.state="pursue";encounters.wanted=true
	await wait_ticks(5)
	encounters._physics_process(.016)
	check(not encounters.escort.is_empty(),"second rear capture starts continuous escort")
	await review("second rear capture starts continuous escort")
	var coordinator:=station.get_node("ThanaStaff/ArrestCoordinator")
	coordinator.custody_seconds=1.0;coordinator.debug_contacts=true
	var phases: Array[String]=[]
	coordinator.phase_changed.connect(func(phase: String):phases.append(phase))
	var previous:=player.global_position
	var max_step:=0.0
	for i in 7200:
		await physics_frame
		encounters._physics_process(1.0/60.0)
		max_step=maxf(max_step,player.global_position.distance_to(previous))
		previous=player.global_position
		if i%600==0:
			for contact in player.get_slide_collision_count():print("CITY BLOCKER ",player.get_slide_collision(contact).get_collider().get_path())
			print("CITY ESCORT PROGRESS ",i," player ",station.to_local(player.global_position)," phase ",coordinator.phase," route index ",encounters.escort.get("index",-1))
		if "custody" in phases and coordinator.phase=="idle":break
		if encounters.escort.is_empty() and coordinator.phase=="idle" and i>240:break
	check("custody" in phases and "leave_cell" in phases and coordinator.phase=="idle","continuous road escort reaches jail and releases")
	check(max_step<.16,"city escort retains continuous collision-body movement")
	check(not coordinator.route_blocked,"escort officer clears porch and maintains pair")
	print("CITY ESCORT PHASES ",phases," max step ",max_step," final city state ",encounters.escort)
	var samples: Array[float]=encounters.cost_samples.duplicate();samples.sort()
	var local_p95: float=samples[int(float(samples.size()-1)*.95)] if not samples.is_empty() else 0
	var report={"local_tick_p95_us":local_p95,"profile_samples":samples.size(),"whole_game_performance_verified":false,"status":"PASS" if errors.is_empty() else "FAIL","errors":errors,"full_world":true,"continuous_city_escort_verified":"custody" in phases and coordinator.phase=="idle","max_city_escort_step_m":max_step}
	var suffix:="" if DisplayServer.get_name()=="headless" else "_metal"
	var file:=FileAccess.open("res://docs/characters/arjun/combat_world_validation%s.json"%suffix,FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("COMBAT WORLD ",report.status," ",errors)
	preload("res://tools/test_audio_cleanup.gd").stop(root)
	world.queue_free();await process_frame;await process_frame
	await preload("res://tools/test_audio_cleanup.gd").settle(self)
	quit(0 if errors.is_empty() else 1)
