extends SceneTree
var world: Node3D
var actor: CharacterBody3D
var jobs: Node
var clock: Node

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(240.0,true,false,true).timeout.connect(func():push_error("Daily errand regression timed out");root.get_node("SaveManager").quit_game(2))
	world = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world); current_scene = world
	for frame in 25: await physics_frame
	actor = world.get_node("Player"); jobs = world.get_node("ErrandSystem"); clock = world.get_node("GameTimeSystem")
	# Errands are reachable after the opening releases the player. Its director
	# otherwise continues moving the fixture player while a delivery is tested.
	var opening: Node = world.get_node_or_null("OpeningSequence")
	if opening != null:
		opening.morning(); opening.set_process(false)
		for step in 200:
			opening._process(.25); await process_frame
			if opening.state == "done": break
		assert(opening.state == "done")
	actor.set_physics_process(false); clock.clock_paused = true
	actor.get_node("InventoryComponent").items.erase("rupees")
	if not await _delivery(): return
	assert(actor.inventory.get_item_count("rupees") == 8)
	assert(not jobs.job_available("merchant_parcel"))
	var saves: Node = root.get_node("SaveManager")
	var original_root: String = saves.save_root
	saves.save_root = "user://codex_daily_errands_validation"
	assert(saves.save_game(world,1))
	jobs.restore_state({}); saves.pending_slot = 1; saves.apply_pending(world)
	assert(not jobs.job_available("merchant_parcel") and actor.inventory.get_item_count("rupees") == 8)
	clock.advance_minutes(1440.0-clock.total_game_minutes+1.0)
	assert(jobs.job_available("merchant_parcel"))
	await _visit("board"); jobs.use_endpoint("board",actor)
	if DisplayServer.get_name() != "headless": await _shot("daily_errand_board")
	assert(jobs.accept("merchant_parcel")); jobs.cancel()
	assert(jobs.job_available("merchant_parcel") and actor.inventory.get_item_count("rupees") == 8)
	if not await _delivery(): return
	assert(actor.inventory.get_item_count("rupees") == 16)
	assert(not jobs.job_available("merchant_parcel"))
	# A midnight during an active shift charges the completion day, not acceptance day.
	await _visit("market"); jobs.use_endpoint("market",actor); assert(jobs.accept("market_sort"))
	clock.advance_minutes(1440.0)
	assert(jobs.active == "market_sort" and jobs.next_endpoint() == "work")
	await _visit("work"); jobs.use_endpoint("work",actor)
	await _visit("market"); jobs.use_endpoint("market",actor)
	assert(actor.inventory.get_item_count("rupees") == 21 and not jobs.job_available("market_sort"))
	var paid_day: int = jobs.current_job_day()
	assert(int(jobs.completed_days.market_sort) == paid_day)
	# Old saves remain safe; completed aid never resets or awards reputation again.
	jobs.restore_state({"stages":{"road_meal":"completed","merchant_parcel":"completed"}})
	assert(not jobs.job_available("road_meal") and not jobs.job_available("merchant_parcel"))
	clock.advance_minutes(1440.0)
	assert(not jobs.job_available("road_meal") and jobs.job_available("merchant_parcel"))
	# Keeping payment history prevents replay when the clock goes backward or state is corrupt.
	jobs.restore_state({"active":"merchant_parcel","stages":{"merchant_parcel":"carrying"},"completed_days":{"merchant_parcel":jobs.current_job_day()}})
	assert(jobs.active.is_empty() and not jobs.job_available("merchant_parcel"))
	assert(saves.save_game(world,1))
	jobs.restore_state({}); saves.pending_slot = 1; saves.apply_pending(world)
	assert(not jobs.job_available("merchant_parcel"))
	clock.total_game_minutes -= 1440.0
	assert(not jobs.job_available("merchant_parcel"))
	clock.total_game_minutes += 1440.0
	await _visit("board"); jobs.use_endpoint("board",actor)
	if DisplayServer.get_name() != "headless": await _shot("daily_errand_paid")
	jobs.close_panel()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(1)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.save_root)); saves.save_root = original_root
	print("DAILY ERRANDS: PASS | once/day, tomorrow unlock, two deliveries, cancellation, midnight active work, aid permanence, old-save migration, paid-state save/load and clock rewind guard")
	root.get_node("SaveManager").quit_game()

func _delivery() -> bool:
	var before_pay: int = actor.inventory.get_item_count("rupees")
	await _visit("board"); jobs.use_endpoint("board",actor); assert(jobs.accept("merchant_parcel"))
	await _visit("parcel"); jobs.use_endpoint("parcel",actor)
	await _visit("market"); jobs.use_endpoint("market",actor)
	# Payment follows the receiver's actual approach, carry, return and thanks.
	assert(actor.inventory.get_item_count("rupees") == before_pay)
	assert(jobs.delivery.request == "merchant_parcel" and jobs.delivery.phase == "receiving")
	actor.global_position += Vector3(4,0,0) # Clear the receiver's return lane.
	var deadline := Time.get_ticks_msec()+105000
	while jobs.active == "merchant_parcel" and Time.get_ticks_msec() < deadline:
		await physics_frame
		if jobs.delivery.phase.is_empty(): break
	if jobs.active == "merchant_parcel":
		push_error("Daily parcel handover stalled: phase="+str(jobs.delivery.phase)+" message="+str(jobs.toast.text))
		root.get_node("SaveManager").quit_game(1)
		return false
	return true

func _visit(id: String) -> void:
	actor.global_position = jobs.targets[id].global_position+Vector3(0,0,1.1)
	actor.global_position.y = jobs.floor_levels[id]+.95
	await physics_frame

func _shot(label: String) -> void:
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	var temporary := OS.get_environment("TLM_STORY_TEST_DIR")
	if temporary.is_empty() or not temporary.begins_with(OS.get_environment("TMPDIR")): return
	assert(root.get_texture().get_image().save_png(temporary.path_join(label+".png")) == OK)
