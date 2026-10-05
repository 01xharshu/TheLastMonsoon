extends SceneTree
class Probe extends Interactable:
	var checks := 0
	var anchor_delta := Vector3.UP*.65
	func interaction_available() -> bool:
		checks += 1
		return super.interaction_available()
	func interaction_anchor() -> Vector3: return global_position+anchor_delta
var failures: Array[String] = []
func _initialize() -> void: _run.call_deferred()
func check(value: bool, label: String) -> void:
	if not value: failures.append(label)
func _run() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	var actor: CharacterBody3D = world.get_node("Player")
	actor.set_script(load("res://tools/world/runtime_interaction_reference.gd"))
	root.add_child(world)
	current_scene = world
	for frame in 6: await process_frame
	actor.set_physics_process(false)
	actor.set_process(false)
	actor.global_position = Vector3(0,1000,0)
	actor.rotation = Vector3.ZERO
	actor.visual_root.rotation = Vector3.ZERO
	actor.first_person = false
	var camera: Camera3D = actor.get_node("CameraPivot/SpringArm3D/Camera3D")
	camera.global_position = Vector3(0,1001.5,4)
	camera.look_at(Vector3(0,1000.8,0))
	camera.make_current()
	var far: Array[Probe] = []
	for i in 200:
		var probe := Probe.new()
		world.add_child(probe)
		probe.global_position = Vector3(10+i*4,1000,100)
		probe.add_to_group("weapon_pickups")
		far.append(probe)
	var near := Probe.new()
	world.add_child(near)
	near.global_position = Vector3(0,1000,1.5)
	check(actor.baseline_find_interactable()==near and actor._find_interactable()==near,"Near selection")
	for z in [1.0,2.6,2.61,5.0,-1.0]:
		near.global_position.z=z
		check(actor._find_interactable()==actor.baseline_find_interactable(),"Selection/range/alignment parity "+str(z))
	near.global_position.z=1.5
	near.add_to_group("weapon_pickups")
	check(actor._find_interactable()==actor.baseline_find_interactable(),"Weapon screen projection parity")
	near.remove_from_group("weapon_pickups")
	near.hide()
	check(actor._find_interactable()==null,"Unavailable target")
	var door := Probe.new()
	world.add_child(door)
	door.add_to_group("house_doors")
	door.global_position = Vector3(100,1000,0)
	door.anchor_delta = Vector3(-100,0,1.5)
	check(actor._find_interactable()==door and actor.baseline_find_interactable()==door,"Distant door root retains near latch anchor")
	door.hide()
	near.show()
	for probe in far: probe.checks=0
	actor._find_interactable()
	var far_checks := 0
	for probe in far: far_checks+=probe.checks
	check(far_checks==0,"Distant availability eliminated")
	var overlay = actor.interaction_overlay
	overlay.set_physics_process(false)
	overlay.set_target(near)
	for probe in far: probe.checks=0
	overlay._physics_process(.016)
	var overlay_far_checks := 0
	for probe in far: overlay_far_checks+=probe.checks
	check(overlay_far_checks==0,"Overlay distant availability eliminated")
	check(overlay.marker_world_positions.has(near),"Near focused anchor retained (close markers intentionally hidden)")
	var old_runs: Array[int] = []
	var new_runs: Array[int] = []
	for round in 5:
		var start := Time.get_ticks_usec()
		for i in 200: actor.baseline_find_interactable()
		old_runs.append(Time.get_ticks_usec()-start)
		start=Time.get_ticks_usec()
		for i in 200: actor._find_interactable()
		new_runs.append(Time.get_ticks_usec()-start)
	old_runs.sort()
	new_runs.sort()
	var sun = world.get_node("Sun")
	var clock = world.get_node("GameTimeSystem")
	sun.set_process(false)
	clock.set_process(false)
	clock.total_game_minutes=540.0
	sun._update_day_night_lighting()
	var morning: Vector3 = sun.rotation
	clock.total_game_minutes+=.04
	sun.lighting_elapsed=0
	sun._process(.016)
	check(sun.rotation==morning,"Lighting bounded cadence")
	clock.total_game_minutes=1080.0
	sun._process(.001)
	check(sun.rotation!=morning,"Clock skip immediate refresh")
	var evening: Vector3 = sun.rotation
	var elapsed: float = sun.lighting_elapsed
	sun._process(1.0)
	check(sun.rotation==evening and sun.lighting_elapsed==elapsed,"Paused clock skips writes")
	clock.total_game_minutes=1439.9
	sun._update_day_night_lighting()
	clock.total_game_minutes=.05
	sun.lighting_elapsed=0
	sun._process(.1)
	check(is_equal_approx(sun.last_lighting_fraction,clock.get_time_of_day_fraction()),"Midnight wrap follows clock")
	var direct_runs: Array[int] = []
	var throttled_runs: Array[int] = []
	for round in 5:
		clock.total_game_minutes=540
		sun._update_day_night_lighting()
		var start := Time.get_ticks_usec()
		for frame in 6000:
			clock.total_game_minutes+=.04
			sun._update_day_night_lighting()
		direct_runs.append(Time.get_ticks_usec()-start)
		clock.total_game_minutes=540
		sun._update_day_night_lighting()
		sun.lighting_elapsed=0
		start=Time.get_ticks_usec()
		for frame in 6000:
			clock.total_game_minutes+=.04
			sun._process(1.0/60)
		throttled_runs.append(Time.get_ticks_usec()-start)
	direct_runs.sort()
	throttled_runs.sort()
	var direct_us := direct_runs[2]
	var throttled_us := throttled_runs[2]
	check(absf(sun.last_lighting_fraction-clock.get_time_of_day_fraction())<.0002,"Lighting clock lag within interval")
	var report := {"date":Time.get_date_string_from_system(),"status":"PASS" if failures.is_empty() else "FAIL","failures":failures,"selection_200_calls_reference_us":old_runs[2],"selection_200_calls_optimised_us":new_runs[2],"lighting_6000_direct_us":direct_us,"lighting_6000_throttled_us":throttled_us,"far_availability_calls":far_checks,"overlay_far_availability_calls":overlay_far_checks,"scope":"CPU lighting and interaction with 200 synthetic distant probes in live world; no whole-game FPS claim"}
	var file := FileAccess.open("res://docs/world/runtime_optimisation_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("RUNTIME OPTIMISATION ",report)
	quit(0 if failures.is_empty() else 1)
