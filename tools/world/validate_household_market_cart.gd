extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var saves: Node = root.get_node("SaveManager")
	saves.options.fullscreen = false
	saves.options.graphics_quality = 1
	saves.apply_options()
	var world: Node3D = load(saves.WORLD).instantiate()
	root.add_child(world)
	current_scene = world
	var path := "WealthyHouseholds/MerchantHouseholdCoach/HouseholdTravel"
	var deadline := Time.get_ticks_msec()+120000
	while not world.has_node(path) and Time.get_ticks_msec()<deadline:
		await process_frame
	if not world.has_node(path):
		print("HOUSEHOLD MARKET CART FAIL | missing household route")
		await saves.quit_game(1)
		return
	var travel: Node = world.get_node(path)
	var cart: Node3D = travel.coach
	var clock: GameTimeSystem = world.get_node("GameTimeSystem")
	clock.total_game_minutes = 600
	clock.clock_paused = true
	clock._update_readable_time(true)
	world.get_node("Sun")._update_day_night_lighting()
	var player: CharacterBody3D = world.get_node("Player")
	player.set_physics_process(false)
	player.get_node("UI").hide()
	for coach in get_nodes_in_group("household_coach"):
		var other: Node = coach.get_node_or_null("HouseholdTravel")
		if other != null: other.set_physics_process(false)
	for frame in 5: await physics_frame
	var errors: Array[String] = []
	if cart.wheels.size()!=4 or cart.combat.horses.size()!=1 or cart.get_node("DraftTeam").slots.size()!=1:
		errors.append("expected four rolling wheels and one registered horse")
	if cart.get_meta("booking_status","")!="household_reserved" or cart.has_node("CoachmanSeatBoarding"):
		errors.append("merchant cart should be reserved")
	var review := OS.get_environment("TLM_MARKET_CART_REVIEW")
	var captured := false
	var rolling := false
	var worst_palm := 0.0
	var worst_ground_gap := 0.0
	var ground_samples := 0
	var trade_verified := false
	var cloth_sale_verified := false
	var saw_loaded := false
	var saw_unloaded := false
	for frame in 3000:
		await physics_frame
		travel.step(.1)
		if travel.phase == "departing": saw_loaded = saw_loaded or cart.get_meta("cargo_loaded",false)
		if travel.phase == "returning": saw_unloaded = saw_unloaded or not cart.get_meta("cargo_loaded",true)
		if travel.phase in ["departing", "returning"]:
			var hoof_origin: Vector3 = cart.visual_root.get_node("DraftHorseVisual").global_position
			var ray := PhysicsRayQueryParameters3D.create(hoof_origin+Vector3.UP*2.0,hoof_origin-Vector3.UP*3.0,1,cart.boarding._vehicle_exclusions())
			var ground := world.get_world_3d().direct_space_state.intersect_ray(ray)
			if not ground.is_empty():
				ground_samples += 1
				# Skinning samples show the lowest planted hoof surface is 5–11 mm below the horse origin.
				worst_ground_gap = maxf(worst_ground_gap,absf(hoof_origin.y-.007-ground.position.y))
		if travel.phase == "working" and not trade_verified:
			var merchant: Node = travel.residents[0].get_node("HouseholdConversation")
			var inventory: Node = player.get_node("InventoryComponent")
			var original_mango: int = inventory.get_item_count("mango")
			inventory.items.mango = original_mango + 1
			merchant.ledger.request(merchant,player)
			trade_verified = inventory.get_item_count("mango") == original_mango
			if not trade_verified: errors.append("merchant purchase at destination failed")
			var counter: Node = travel.office.get_node("ClothCounter")
			if not review.is_empty():
				var camera: Camera3D = root.get_camera_3d()
				camera.global_position = travel.office.to_global(Vector3(1.4,2.1,2.4))
				camera.look_at(counter.global_position)
				for wait_frame in 10: await process_frame
				await RenderingServer.frame_post_draw
				if root.get_texture().get_image().save_png(review.path_join("counter.png")) != OK:
					errors.append("could not capture cloth counter")
			player.global_position = counter.global_position + Vector3(0,-1.05,1.4)
			player.get_node("VisualRoot").global_rotation.y = PI
			for wait_frame in 3: await physics_frame
			if player.call("_find_interactable") != counter:
				errors.append("cloth counter cannot be selected through normal interaction")
			var record: Dictionary = merchant.ledger._record(merchant.role_id)
			inventory.items.rupees = 3
			var original_cloth: int = inventory.get_item_count("salvaged_cloth")
			counter.interact(player)
			if int(record.get("cloth_sold",0)) != 0 or inventory.get_item_count("rupees") != 3:
				errors.append("insufficient funds changed stock or money")
			inventory.items.rupees = 12
			counter.interact(player)
			if int(record.get("cloth_sold",0)) != 1 or inventory.get_item_count("rupees") != 8 or inventory.get_item_count("salvaged_cloth") != original_cloth+1:
				errors.append("first cloth purchase failed")
			var temp := OS.get_environment("TLM_SAVE_TEST_DIR")
			if temp.is_empty():
				errors.append("temporary save directory missing")
			else:
				var old_root: String = saves.save_root
				var old_pending: int = saves.pending_slot
				saves.save_root = temp
				if not saves.save_game(world,1):
					errors.append("cloth transaction disk save failed")
				else:
					record["cloth_sold"] = 0
					inventory.items.rupees = 99
					saves.pending_slot = 1
					saves.apply_pending(world)
					record = merchant.ledger._record(merchant.role_id)
					if int(record.get("cloth_sold",0)) != 1 or inventory.get_item_count("rupees") != 8:
						errors.append("cloth transaction disk restore failed")
				saves.save_root = old_root
				saves.pending_slot = old_pending
			counter.interact(player)
			counter.interact(player)
			cloth_sale_verified = int(record.get("cloth_sold",0)) == 2 and inventory.get_item_count("rupees") == 4 and inventory.get_item_count("salvaged_cloth") == original_cloth+2
			if not cloth_sale_verified: errors.append("second purchase or sold-out guard failed")
			player.global_position = travel.office.to_global(Vector3(12,0,12))
		if travel.phase == "departing" and travel.distance_travelled>1.5:
			rolling = rolling or (absf(cart.wheels[0].rotation.x)>.05 and absf(cart.wheels[1].rotation.x)>.05)
			for side in ["l","r"]:
				worst_palm = maxf(worst_palm,travel.driver.get_meta("hand_contact_"+side,1.0))
			if not review.is_empty() and not captured:
				captured = true
				var camera := Camera3D.new()
				world.add_child(camera)
				camera.make_current()
				player.global_position = cart.to_global(Vector3(-8,0,8))
				for view in [Vector3(-6.4,2.9,-3.6),Vector3(-5.0,3.3,6.4)]:
					camera.global_position = cart.to_global(view)
					camera.look_at(cart.to_global(Vector3(0,1.25,1.04)))
					for wait_frame in 10: await process_frame
					await RenderingServer.frame_post_draw
					var name := "front.png" if view.z<0 else "rear.png"
					if root.get_texture().get_image().save_png(review.path_join(name))!=OK:
						errors.append("could not write "+name)
		if travel.completed_trips>0: break
	if not rolling or worst_palm>.025:
		errors.append("wheel or palm contact check failed")
	if review.is_empty() and (ground_samples == 0 or worst_ground_gap > .12):
		errors.append("horse ground clearance exceeds 12 cm")
	if review.is_empty():
		var service: Node = travel.residents[0].get_node("HouseholdConversation")
		var ledger: Node = service.ledger
		var record: Dictionary = ledger._record(service.role_id)
		if not saw_loaded or not saw_unloaded or int(record.get("cloth_delivered",0)) != 2:
			errors.append("cloth delivery and empty return failed")
		var saved: Dictionary = ledger.export_state()
		travel._phase("working")
		if int(record.get("cloth_delivered",0)) != 2: errors.append("same-day duplicate delivery")
		ledger.restore_state(saved)
		if int(ledger._record(service.role_id).get("cloth_delivered",0)) != 2: errors.append("delivery state restore failed")
		travel._phase("home")
		travel.step(.01)
		if cart.get_meta("cargo_loaded",true): errors.append("same-day return unexpectedly reloaded")
		clock.total_game_minutes += 1440
		clock._update_readable_time(true)
		travel.step(.01)
		if not cart.get_meta("cargo_loaded",false): errors.append("next-day cargo not available")
	if review.is_empty() and not cloth_sale_verified:
		errors.append("cloth sale not verified")
	if review.is_empty() and not trade_verified:
		errors.append("destination merchant transaction was not exercised")
	if review.is_empty() and (travel.completed_trips<1 or travel.distance_travelled<200):
		errors.append("home–market–home round trip did not complete")
	if not review.is_empty() and not captured:
		errors.append("never reached moving review stage")
	print("HOUSEHOLD MARKET CART ", "PASS" if errors.is_empty() else "FAIL",
		" | phase=",travel.phase," trips=",travel.completed_trips," distance=",travel.distance_travelled,
		" wheel_roll=",rolling," palm_error_m=",worst_palm," horse_ground_gap_m=",worst_ground_gap," ground_samples=",ground_samples," traded=",trade_verified," cloth_sale=",cloth_sale_verified," coach_blocks=",travel.blocked_frames,
		" passenger_state=",travel.journeys[0].state," passenger_blocks=",travel.journeys[0].blocked_frames,
		" errors=",errors)
	await saves.quit_game(0 if errors.is_empty() else 1)
