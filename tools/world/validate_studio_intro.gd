extends SceneTree
## Reusable startup/skip checks. Produces no screenshots, recordings or reports.
const INTRO := preload("res://ui/studio_intro.tscn")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	assert(ProjectSettings.get_setting("application/run/main_scene") == "res://ui/studio_intro.tscn")
	# Check automatic finish using the real timeline, including signature playback.
	var intro = INTRO.instantiate()
	root.add_child(intro)
	current_scene = intro
	assert(is_instance_valid(intro.sound) and intro.atmosphere != null)
	await create_timer(8.6).timeout
	assert(current_scene.name == "MainMenu", "Timed intro did not open title menu")
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	for mode in ["key", "controller", "touch", "mouse"]:
		current_scene.free()
		intro = INTRO.instantiate()
		root.add_child(intro)
		current_scene = intro
		intro.elapsed = 1.0
		var event: InputEvent
		match mode:
			"key":
				event = InputEventKey.new()
				event.keycode = KEY_SPACE
			"controller":
				event = InputEventJoypadButton.new()
				event.button_index = JOY_BUTTON_A
			"touch":
				event = InputEventScreenTouch.new()
			"mouse":
				event = InputEventMouseButton.new()
				event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		intro._unhandled_input(event)
		intro._unhandled_input(event) # Repeated activation must not duplicate transitions.
		await create_timer(0.75).timeout
		assert(current_scene.name == "MainMenu", mode + " skip failed")
	print("STUDIO INTRO PASS: timed startup, signature playback, keyboard/controller/touch/mouse skip, repeated input, menu handoff")
	quit()
