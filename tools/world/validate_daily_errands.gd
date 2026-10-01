extends SceneTree
var world: Node3D
var actor: CharacterBody3D
var jobs: Node
var clock: Node

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	world = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world); current_scene = world
	for frame in 25: await physics_frame
	actor = world.get_node("Player"); jobs = world.get_node("ErrandSystem"); clock = world.get_node("GameTimeSystem")
	actor.set_physics_process(false); clock.clock_paused = true
	actor.get_node("InventoryComponent").items.erase("rupees")
	await _delivery()
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
	await _delivery()
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
	quit()

func _delivery() -> void:
	await _visit("board"); jobs.use_endpoint("board",actor); assert(jobs.accept("merchant_parcel"))
	await _visit("parcel"); jobs.use_endpoint("parcel",actor)
	await _visit("market"); jobs.use_endpoint("market",actor)

func _visit(id: String) -> void:
	actor.global_position = jobs.targets[id].global_position+Vector3(0,0,1.1)
	actor.global_position.y = jobs.floor_levels[id]+.95
	await physics_frame

func _shot(label: String) -> void:
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://docs/world/captures/"+label+".png") == OK)
