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
		require(change_scene_to_file("res://ui/main_menu.tscn") == OK, "Title scene loads")
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
