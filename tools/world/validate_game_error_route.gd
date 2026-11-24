extends SceneTree
## Native new-game intro, skip/release and normal controller smoke route.
const Snapshot = preload("res://tools/world/performance_snapshot.gd")
var failed := false
func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
func _initialize() -> void: _run.call_deferred()
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	print("RENDER REVIEW ",label," | viewport ",root.size," scale ",root.scaling_3d_scale)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--review-dir="):
			var directory := argument.trim_prefix("--review-dir=")
			# Only the runner's disposable OS directory may receive review views.
			if not directory.is_absolute_path() or not directory.get_file().begins_with("tlm-performance-"):
				push_error("Review output requires a disposable performance directory")
				return
			var pixels := root.get_texture().get_image()
			pixels.resize(1280,720,Image.INTERPOLATE_LANCZOS)
			check(pixels.save_png(directory.path_join(label+".png"))==OK,"Temporary review view could not be written")
func compare_bag_contact(actor: Node3D, label: String) -> void:
	var bag := actor.get_node("VisualRoot/EquipmentVisuals/WaterBagVisual")
	bag.use_contact_width_bound = true
	check(bag._cloth_contact_required()==bag._cloth_contact_required(true),"Live contact parity failed at "+label)
	var original: Array[int] = []
	var candidate: Array[int] = []
	for round_index in 7:
		for full_scan in ([true,false] if round_index%2==0 else [false,true]):
			var started := Time.get_ticks_usec()
			for repeat in 30: bag._cloth_contact_required(full_scan)
			(original if full_scan else candidate).append(Time.get_ticks_usec()-started)
	original.sort()
	candidate.sort()
	print("CONTACT INIT LIVE WIDTH COST ",JSON.stringify({"label":label,"samples":bag.contact_points.size(),"bones":bag.contact_bones.size(),"original_30_calls_us":original[3],"bounded_30_calls_us":candidate[3],"original_max_30_calls_us":original.back(),"bounded_max_30_calls_us":candidate.back(),"exact_parity":not failed,"scope":"same native scene/pose alternating contact queries; excluded from walking frame sample"}))

func _run() -> void:
	var saves = root.get_node("SaveManager")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--quality="):
			saves.options.graphics_quality = clampi(argument.trim_prefix("--quality=").to_int(),0,2)
	var started := Time.get_ticks_msec()
	print("PERFORMANCE SNAPSHOT before_world ",JSON.stringify(Snapshot.capture()))
	# Use the same staged loader as the title's Begin New Journey callback.
	var loading := preload("res://ui/journey_loading.gd").new()
	root.add_child(loading)
	check(await loading.begin(0),"New Journey loader failed")
	if failed:
		await saves.quit_game(1)
		return
	var loader_timings: Dictionary = loading.timings.duplicate()
	for frame in 3: await process_frame
	print("GAME ERROR ROUTE READY | ",Time.get_ticks_msec()-started," ms | quality ",saves.options.graphics_quality)
	print("PERFORMANCE SNAPSHOT ready ",JSON.stringify(Snapshot.capture())," loader_phases ",JSON.stringify(loader_timings))
	var world: Node3D = current_scene
	var opening = world.get_node("OpeningSequence")
	var actor: CharacterBody3D = world.get_node("Player")
	print("PHYSICS BODY BUDGET | limit ",ProjectSettings.get_setting("physics/jolt_physics_3d/limits/max_bodies"))
	if "--skip-intro" in OS.get_cmdline_user_args():
		var skip := InputEventKey.new()
		skip.keycode = KEY_ESCAPE;skip.pressed = true
		opening._input(skip)
		await process_frame
		opening._input(skip)
	else:
		for moment in [5.0,16.0,27.0]:
			while opening.elapsed < moment: await process_frame
			await capture("intro_"+str(int(moment)))
	while opening.state in ["prologue","cart_passage","night"]: await process_frame
	check(opening.state in ["dawn","rising","departing","done"],"Intro did not reach morning")
	await capture("morning")
	var event := InputEventKey.new()
	event.keycode=KEY_W
	event.pressed=true
	opening._input(event)
	while opening.state != "done": await process_frame
	check(opening.state == "done" and actor.is_physics_processing(),"Intro did not release controls")
	print("PERFORMANCE SNAPSHOT playable ",JSON.stringify(Snapshot.capture()))
	if "--compare-bag-contact" in OS.get_cmdline_user_args(): compare_bag_contact(actor,"playable")
	var live_lod: Node
	var lod_enabled := "--live-tree-lod" in OS.get_cmdline_user_args()
	if "--live-lod-route" in OS.get_cmdline_user_args():
		live_lod = preload("res://world/suryagarh/distant_tree_lod.gd").new()
		live_lod.process_priority = 100
		live_lod.configure(world)
		world.add_child(live_lod)
		live_lod.set_process(lod_enabled)
	var trace_population := "--trace-live-population" in OS.get_cmdline_user_args()
	var city := world.get_node_or_null("CityRoutePopulation")
	var expansion := world.get_node_or_null("PopulationExpansion")
	var routes: Dictionary = {}
	var area := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--area="): area = argument.trim_prefix("--area=")
	for spec in [["village",Vector2(-230,180),Vector2(-310,230)],["civil_lines",Vector2(680,285),Vector2(680,245)],["cantonment",Vector2(500,470),Vector2(500,445)],["forest",Vector2(343,-105),Vector2(360,-103)]]:
		if not area.is_empty() and spec[0] != area: continue
		var at: Vector2 = spec[1]
		var direction: Vector2 = spec[2]-at
		var reverse_crossing: bool = live_lod != null and spec[0] == "forest" and "--reverse-lod-crossing" in OS.get_cmdline_user_args()
		if reverse_crossing:
			# Start beyond the observed outward crossing. Keep the same camera
			# heading and spring-arm offset while walking back across it.
			at += direction.normalized() * 17.44
		actor.global_position=Vector3(at.x,world.layout.height(at.x,at.y)+1.1,at.y)
		actor.velocity=Vector3.ZERO
		actor.get_node("CameraPivot").global_rotation.y = atan2(-direction.x,-direction.y)
		actor.camera_pitch = deg_to_rad(-10.0)
		actor.get_node("CameraPivot").rotation.x = actor.camera_pitch
		var arrival_frames: Array[float] = []
		var arrival_stop := Time.get_ticks_msec()+1000
		while Time.get_ticks_msec()<arrival_stop:
			var tick := Time.get_ticks_usec()
			await process_frame
			arrival_frames.append((Time.get_ticks_usec()-tick)/1000.0)
		arrival_frames.sort()
		print("PERFORMANCE SNAPSHOT entered ",spec[0]," ",JSON.stringify(Snapshot.capture()))
		var before := actor.global_position
		var walk_action := &"move_backward" if reverse_crossing else &"move_forward"
		Input.action_press(walk_action)
		var frames: Array[float] = []
		var refresh_samples: Array = []
		var population_samples: Array = []
		var no_refresh_max_ms := 0.0
		var walk_restores: int = live_lod.near_restores if live_lod != null else 0
		var stop := Time.get_ticks_msec()+3000
		var hard_stop := Time.get_ticks_msec()+20000
		while (Time.get_ticks_msec()<stop or frames.size()<30) and Time.get_ticks_msec()<hard_stop:
			var tick := Time.get_ticks_usec()
			var before_refresh: int = live_lod.refreshes if lod_enabled else 0
			var before_writes: int = live_lod.writes if lod_enabled else 0
			var sample_frame := Engine.get_process_frames()
			await process_frame
			var elapsed_ms := (Time.get_ticks_usec()-tick)/1000.0
			if lod_enabled and live_lod.refreshes != before_refresh:
				refresh_samples.append([frames.size(), elapsed_ms, live_lod.last_refresh_usec, live_lod.writes-before_writes])
			else:
				no_refresh_max_ms = maxf(no_refresh_max_ms, elapsed_ms)
			if trace_population:
				var city_current: bool = city != null and city.population_sample_frame == sample_frame
				var expansion_current: bool = expansion != null and expansion.population_sample_frame == sample_frame
				population_samples.append([elapsed_ms,
					city.population_process_us if city_current else 0,
					city.population_spawn_us if city_current else 0,
					expansion.population_process_us if expansion_current else 0,
					expansion.population_spawn_us if expansion_current else 0,
					expansion.population_discovery_us if expansion_current else 0])
			frames.append(elapsed_ms)
		Input.action_release(walk_action)
		if trace_population:
			print("LIVE POPULATION [frame_ms, city_us, city_spawn_us, expansion_us, expansion_spawn_us, discovery_us] ", JSON.stringify(population_samples))
		if lod_enabled:
			print("LIVE LOD REFRESH SAMPLES [index, frame_ms, refresh_us, writes] ", JSON.stringify(refresh_samples))
			print("LIVE LOD WALK near_restores=", live_lod.near_restores - walk_restores,
				" no_refresh_max_ms=", no_refresh_max_ms)
		if reverse_crossing and lod_enabled:
			check(live_lod.near_restores > walk_restores, "Reverse forest walk did not restore near tree detail")
		check(actor.global_position.distance_to(before)>1.0,"Walking route blocked in "+str(spec[0]))
		var over_budget := 0
		for frame_ms in frames:
			if frame_ms > 33.333: over_budget += 1
		frames.sort()
		routes[spec[0]]={"frames_over_33_333_ms":over_budget,"movement_m":actor.global_position.distance_to(before),"frame_samples":frames.size(),"arrival_frame_max_ms":arrival_frames.back(),"frame_ms_p50":frames[frames.size()/2],"frame_ms_p95":frames[int(frames.size()*.95)],"frame_ms_p99":frames[mini(frames.size()-1,int(frames.size()*.99))],"frame_ms_max":frames.back(),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"cpu_process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"cpu_physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000}
		if "--compare-bag-contact" in OS.get_cmdline_user_args(): compare_bag_contact(actor,"walked_"+str(spec[0]))
		await capture(spec[0])
		if reverse_crossing and lod_enabled and Array(OS.get_cmdline_user_args()).any(func(arg): return arg.begins_with("--review-dir=")):
			# Compare the same stopped camera after the timed walk.
			live_lod.set_process(false)
			for batch in live_lod.batches:
				if is_instance_valid(batch[0]):
					batch[0].lod_bias = batch[2]
			for frame in 3:
				await process_frame
			await capture("forest_original_detail")
		print("PERFORMANCE SNAPSHOT leaving ",spec[0]," ",JSON.stringify(Snapshot.capture()))
	if live_lod != null:
		print("LIVE TREE LOD ", JSON.stringify({"refreshes":live_lod.refreshes,"writes":live_lod.writes,"reduced":live_lod.reduced}))
	var pixels: Vector2i=root.size
	print(JSON.stringify({"status":"FAIL" if failed else "PASS","renderer":RenderingServer.get_current_rendering_method(),"physical_viewport":str(pixels),"scale_3d":root.scaling_3d_scale,"render_3d_pixels":str(Vector2(pixels)*root.scaling_3d_scale),"routes":routes,"limit":"short native smoke route; shared desktop contention; no controlled FPS comparison"}))
	print("GAME ERROR ROUTE: ","FAIL" if failed else "PASS")
	preload("res://tools/test_audio_cleanup.gd").stop(root)
	await preload("res://tools/test_audio_cleanup.gd").settle(self)
	root.get_node("SaveManager").quit_game(1 if failed else 0)
