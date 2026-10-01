extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world: Node3D = load("res://world/suryagarh/suryagarh_world.tscn").instantiate()
	root.add_child(world); current_scene = world
	for frame in 20: await physics_frame
	var actor: CharacterBody3D = world.get_node("Player")
	actor.set_physics_process(false)
	actor.set_process_unhandled_input(false)
	var jobs: Node3D = world.get_node("ErrandSystem")
	var inventory: InventoryComponent = actor.get_node("InventoryComponent")
	var fame: Node = actor.get_node("FameComponent")
	inventory.items.erase("rupees"); inventory.items.erase("roti")
	var initial_fame: int = fame.points
	assert(jobs.targets.size() == 6)
	# Confirm the actual player target finder can reach every endpoint, including NPC bodies.
	for id in jobs.targets:
		await _visit(actor,jobs,id)
		actor.get_node("VisualRoot").global_rotation.y = PI
		if actor._find_interactable() != jobs.targets[id]:
			var query := PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*1.35,jobs.targets[id].global_position)
			query.exclude = [actor.get_rid()]
			var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
			print("ERRAND BLOCKED ",id," player ",actor.global_position," target ",jobs.targets[id].global_position," selected ",actor._find_interactable()," hit ",hit.get("collider"))
			if hit.has("collider"): print(hit.collider.get_path())
			quit(1); return
	actor.global_position = Vector3(-230,9,180)
	jobs.use_endpoint("road",actor)
	assert(not jobs.panel.get_parent().visible, "Remote conversations must fail")
	await _visit(actor,jobs,"board")
	jobs.use_endpoint("board",actor)
	assert(paused and jobs.panel.get_parent().visible)
	assert(inventory.get_item_count("rupees") == 0)
	if DisplayServer.get_name() != "headless": await _shot("errand_board")
	assert(jobs.accept("road_meal")); assert(not paused)
	await _visit(actor,jobs,"road")
	jobs.use_endpoint("road",actor)
	assert(jobs.active == "road_meal" and inventory.get_item_count("rupees") == 0)
	inventory.add_item("roti",1)
	jobs.use_endpoint("road",actor)
	assert(jobs.active.is_empty() and inventory.get_item_count("rupees") == 2 and not inventory.has_item("roti"))
	assert(fame.points == initial_fame + 4)
	jobs.use_endpoint("road",actor); jobs.close_panel()
	assert(inventory.get_item_count("rupees") == 2 and fame.points == initial_fame + 4)
	await _visit(actor,jobs,"office")
	jobs.use_endpoint("office",actor)
	assert(jobs.accept("merchant_parcel"))
	await _visit(actor,jobs,"market")
	jobs.use_endpoint("market",actor); jobs.close_panel()
	assert(jobs.active == "merchant_parcel" and inventory.get_item_count("rupees") == 2)
	await _visit(actor,jobs,"parcel")
	jobs.use_endpoint("parcel",actor)
	assert(jobs.stages.merchant_parcel == "carrying")
	var saves: Node = root.get_node("SaveManager")
	saves.save_root = "user://codex_errand_validation"
	assert(saves.save_game(world,1))
	jobs.restore_state({}); inventory.items.erase("rupees"); fame.points = 0
	saves.pending_slot = 1; saves.apply_pending(world)
	assert(jobs.active == "merchant_parcel" and jobs.stages.merchant_parcel == "carrying")
	assert(inventory.get_item_count("rupees") == 2 and fame.points == initial_fame + 4)
	await _visit(actor,jobs,"market")
	jobs.use_endpoint("market",actor)
	assert(jobs.active.is_empty() and inventory.get_item_count("rupees") == 10)
	jobs.use_endpoint("market",actor)
	assert(jobs.accept("market_sort"))
	await _visit(actor,jobs,"work")
	# Exercise the controller's real held-interaction progression, including early release.
	actor.current_interactable = jobs.targets.work
	actor._begin_interaction_hold(jobs.targets.work,"interact")
	actor.hold_action = "interact"
	Input.action_press("interact")
	actor._advance_interaction_hold(1.0)
	Input.action_release("interact")
	actor._advance_interaction_hold(.01)
	assert(jobs.stages.market_sort == "accepted")
	actor.current_interactable = jobs.targets.work
	actor._begin_interaction_hold(jobs.targets.work,"interact")
	actor.hold_action = "interact"
	Input.action_press("interact")
	for frame in 190:
		actor._advance_interaction_hold(1.0/60.0)
		await physics_frame
	Input.action_release("interact")
	assert(jobs.stages.market_sort == "worked" and inventory.get_item_count("rupees") == 10)
	await _visit(actor,jobs,"market")
	jobs.use_endpoint("market",actor)
	assert(jobs.active.is_empty() and inventory.get_item_count("rupees") == 15)
	print("ERRAND CHECK: completion save")
	assert(saves.save_game(world,1))
	jobs.restore_state({}); saves.pending_slot = 1; saves.apply_pending(world)
	assert(jobs.stages.size() == 3)
	await _visit(actor,jobs,"board")
	jobs.use_endpoint("board",actor)
	assert(not jobs.accept("merchant_parcel")); jobs.close_panel()
	assert(inventory.get_item_count("rupees") == 15)
	# Cancellation and invalid save state cannot make parcels or completed wages reappear.
	jobs.restore_state({}); jobs.use_endpoint("board",actor); assert(jobs.accept("merchant_parcel"))
	await _visit(actor,jobs,"parcel"); jobs.use_endpoint("parcel",actor)
	jobs.cancel(); assert(jobs.active.is_empty() and inventory.get_item_count("rupees") == 15)
	jobs.restore_state({"active":"road_meal","stages":{"road_meal":"carrying","unknown":"completed"}})
	assert(jobs.active.is_empty() and jobs.stages.is_empty())
	print("ERRAND CHECK: progression complete")
	if DisplayServer.get_name() != "headless":
		await _visit(actor,jobs,"board")
		jobs.use_endpoint("board",actor); assert(jobs.accept("merchant_parcel"))
		jobs.open_panel(); await _shot("errand_journal"); jobs._mark_next()
		assert(actor.get_node("UI/WorldMap").waypoint.is_finite())
		var camera := Camera3D.new(); world.add_child(camera)
		camera.global_position = Vector3(-381,10,326)
		camera.look_at(Vector3(-387,8,320)); camera.make_current()
		await _shot("errand_market")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(1)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.save_root))
	print("ERRANDS: PASS | 6 world targets, board/conversations, aid inventory/fame, collect-deliver, interrupted/full work hold, exact wages, cancel, save/resume, duplicate and remote guards")
	quit()

func _visit(actor: CharacterBody3D, jobs: Node, id: String) -> void:
	actor.global_position = jobs.targets[id].global_position + Vector3(0,0,1.1)
	actor.global_position.y = jobs.floor_levels[id] + .9
	actor.velocity = Vector3.ZERO
	await physics_frame

func _shot(label: String) -> void:
	for frame in 4: await process_frame
	RenderingServer.force_draw(false)
	assert(root.get_texture().get_image().save_png("res://docs/world/captures/"+label+".png") == OK)
