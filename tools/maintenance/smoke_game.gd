extends SceneTree
## Real startup, menu pages, world movement and isolated save/load smoke checks.
## Run through check_game.py so user:// and any generated files are disposable.
var failed := false

func require(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var saves := root.get_node("SaveManager")
	var world_mode := "--world" in OS.get_cmdline_user_args()
	var started := Time.get_ticks_msec()
	if world_mode:
		saves.start_new_game()
	else:
		var title: Node = await preload("res://tools/maintenance/startup_fixture.gd").open_title(self)
		if title == null:
			saves.quit_game(1)
			return
	for frame in 4:
		await process_frame
	print("SMOKE scene ready in ", (Time.get_ticks_msec() - started) / 1000.0, "s")
	if world_mode:
		var world: Node3D = current_scene
		var actor: CharacterBody3D = world.get_node("Player")
		var opening := world.get_node("OpeningSequence")
		var skip := InputEventKey.new()
		skip.keycode = KEY_ESCAPE
		skip.pressed = true
		opening._input(skip)
		for frame in 2:
			await process_frame
		opening._input(skip)
		for frame in 120:
			if actor.is_physics_processing() and opening.state == "done":
				break
			await physics_frame
		require(actor.is_physics_processing(), "Opening skip releases control")
		for point in [Vector2(-230,180), Vector2(640,235), Vector2(500,465)]:
			actor.global_position = Vector3(point.x, world.layout.height(point.x,point.y) + 1.1, point.y)
			actor.velocity = Vector3.ZERO
			for frame in 8:
				await physics_frame
			Input.action_press("move_forward")
			for frame in 12:
				await physics_frame
			Input.action_release("move_forward")
			require(actor.global_position.is_finite(), "Finite player movement")
		var inventory: Node = actor.get_node("InventoryComponent")
		# Weapon controls require captured input, even when another desktop app was
		# focused during the route. Re-enter that ordinary gameplay context.
		if DisplayServer.get_name() != "headless": root.grab_focus()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		inventory.add_item("enfield", 1)
		var equipment: Node3D = actor.get_node("VisualRoot/CharacterVisual").equipment
		equipment.select_weapon(1)
		Input.action_press("aim")
		for frame in 12:
			await physics_frame
		Input.action_release("aim")
		var rifle: Node = actor.get_node("RifleCombat")
		rifle.rounds = 0
		inventory.add_item(rifle.ammo_id(), 2)
		if not rifle.available() or actor.get_meta("item_use", "") != "":
			print("RIFLE SMOKE CONTEXT ", {"available":rifle.available(), "physics":actor.is_physics_processing(), "swimming":actor.is_swimming, "selected":equipment.selected, "stowed":equipment.stowed, "mouse_mode":Input.mouse_mode, "detention":actor.get_meta("detention_action", ""), "item_use":actor.get_meta("item_use", ""), "paused":paused})
		rifle.start_reload()
		require(rifle.reload_remaining > 0, "Rifle reload starts")
		# Use the actual reload duration, rather than assuming 150 render frames
		# represent enough elapsed gameplay time on every renderer or machine.
		var reload_deadline := Time.get_ticks_msec() + maxi(90000, int((rifle.reload_duration() + 5.0) * 1000.0))
		var reload_frames := 0
		var reload_simulated := 0.0
		while rifle.reload_remaining > 0 and Time.get_ticks_msec() < reload_deadline:
			await process_frame
			reload_frames += 1
			reload_simulated += rifle.get_process_delta_time()
		if rifle.rounds != 1 or rifle.reload_remaining > 0:
			print("RIFLE SMOKE RESULT ", {"rounds":rifle.rounds, "remaining":rifle.reload_remaining, "pending":rifle.pending_rounds, "available":rifle.available(), "physics":actor.is_physics_processing(), "swimming":actor.is_swimming, "selected":equipment.selected, "stowed":equipment.stowed, "mouse_mode":Input.mouse_mode, "detention":actor.get_meta("detention_action", ""), "item_use":actor.get_meta("item_use", ""), "paused":paused})
		print("RIFLE SMOKE TIMING ", {"frames":reload_frames,"simulation_seconds":reload_simulated,"rounds":rifle.rounds,"remaining":rifle.reload_remaining})
		require(rifle.rounds == 1 and rifle.reload_remaining <= 0, "Rifle reload completes | " + str({"rounds":rifle.rounds,"remaining":rifle.reload_remaining,"pending":rifle.pending_rounds,"available":rifle.available(),"process":rifle.is_processing(),"can_process":rifle.can_process(),"selected":equipment.selected,"stowed":equipment.stowed,"mouse_mode":Input.mouse_mode,"physics":actor.is_physics_processing(),"swimming":actor.is_swimming,"detention":actor.get_meta("detention_action",""),"paused":paused,"time_scale":Engine.time_scale}))
		equipment.toggle_stowed()
		require(saves.save_game(world, 1), "Save slot writes")
		require(not saves.read_slot(1).is_empty(), "Save slot reads")
		# Restore in-place, exercising the same apply path without rebuilding the world.
		saves.pending_slot = 1
		saves.apply_pending(world)
		for frame in 3:
			await process_frame
	else:
		var menu: Control = current_scene
		for page in ["show_settings", "show_slots", "show_main"]:
			menu.call(page)
			for frame in 2:
				await process_frame
	print("GAME SMOKE ", "WORLD" if world_mode else "MENU", " ", "FAIL" if failed else "PASS")
	saves.quit_game(1 if failed else 0)
