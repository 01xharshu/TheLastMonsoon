extends SceneTree
## Actual title-to-world handoff. Print only; runner owns disposable saves/logs.
var frames := 0
var previous_usec := 0
var max_gap_usec := 0
var gaps: Array[int] = []
var loading := false
var slow_frames: Array = []
var phase := "Preparing resources"
var failed := false
func _initialize() -> void:
	process_frame.connect(_observe_frame)
	_run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: failed = true; push_error(message)
func _observe_frame() -> void:
	if not loading: return
	var now := Time.get_ticks_usec()
	if previous_usec > 0:
		var gap := now - previous_usec
		max_gap_usec = maxi(max_gap_usec, gap)
		gaps.append(gap)
		if gap > 100000: slow_frames.append({"ms":gap/1000.0,"phase":phase})
	var startup = preload("res://systems/world_startup.gd").current
	phase = startup.stage if startup != null else "Preparing resources"
	previous_usec = now
	frames += 1
func _run() -> void:
	var saves := root.get_node("SaveManager")
	var folder := OS.get_environment("TLM_STARTUP_TEMP")
	check(not folder.is_empty(), "Run through run_startup_check.py for temporary save/log cleanup")
	if failed: saves.quit_game(1); return
	saves.save_root = folder
	# Fix the test render resolution/options in memory; never alter user settings.
	saves.options.fullscreen = false
	saves.options.vsync = false
	saves.options.graphics_quality = 1
	saves.apply_options()
	root.size = Vector2i(1280,720)
	var slot := 0
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--slot="): slot = int(argument.trim_prefix("--slot="))
	change_scene_to_file("res://ui/main_menu.tscn")
	await scene_changed
	var overlay = load("res://ui/journey_loading.gd").new()
	root.add_child(overlay)
	var started := Time.get_ticks_usec()
	loading = true
	var ok: bool = await overlay.begin(slot)
	loading = false
	check(ok and current_scene != null and current_scene.name == "Suryagarh", "Actual world loading failed")
	check(not paused, "World remained paused after loading")
	check(current_scene.visible, "World remained hidden after loading")
	check(preload("res://systems/world_startup.gd").current == null, "Startup session leaked")
	var opening := current_scene.get_node_or_null("OpeningSequence")
	if slot > 0:
		check(opening == null, "Saved load replayed opening")
		var actor: Node3D = current_scene.get_node("Player")
		check(absf(actor.global_position.x + 230.0) < .2 and absf(actor.global_position.z - 180.0) < .2, "Saved position was not restored")
	else:
		check(opening != null and opening.elapsed < .3, "Loading consumed the opening timeline")
	gaps.sort()
	slow_frames.sort_custom(func(a,b): return a.ms > b.ms)
	print("WORLD STARTUP ",JSON.stringify({"status":"FAIL" if failed else "PASS","slot":slot,"seconds":(Time.get_ticks_usec()-started)/1000000.0,"frames":frames,"max_gap_ms":max_gap_usec/1000.0,"p95_gap_ms":gaps[int(gaps.size()*.95)]/1000.0 if not gaps.is_empty() else 0,"checkpoints":current_scene.get_meta("startup_checkpoints",0),"slow_frames":slow_frames.slice(0,5),"driver_cloth_ms":_driver_cloth_ms(current_scene),"driver_cache_hits":_driver_cache_hits(current_scene),"timings":current_scene.get_meta("startup_timings",{})}))
	await saves.quit_game(1 if failed else 0)

func _driver_cloth_ms(world: Node) -> float:
	var total := 0.0
	for node in world.find_children("*", "Node3D", true, false):
		total += float(node.get_meta("startup_cloth_usec",0))/1000.0
	return total

func _driver_cache_hits(world: Node) -> int:
	var count := 0
	for node in world.find_children("*", "Node3D", true, false):
		if node.get_meta("startup_cloth_cache",false): count += 1
	return count
