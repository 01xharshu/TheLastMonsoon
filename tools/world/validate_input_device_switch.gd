extends SceneTree
## Focused action routing and settings persistence check; no physical pad required.

func _initialize() -> void:
	var manager: Node = load("res://systems/save_manager.gd").new()
	manager.settings_path = "user://input_device_test.cfg"
	root.add_child(manager)
	await process_frame
	manager.options.input_device = "keyboard_mouse"
	manager._select_input_device()
	if not _has_event("attack",InputEventMouseButton) or _has_event("attack",InputEventJoypadMotion):
		_fail("keyboard route")
		return
	manager._set_active_input_device("controller")
	if not _has_event("attack",InputEventJoypadMotion) or _has_event("attack",InputEventMouseButton):
		_fail("controller route")
		return
	for action in ["aim","reload","weapon_wheel","open_map","stow_weapon","context_modifier","next_weapon","identity_scroll"]:
		if not _has_controller_event(action):
			_fail("missing controller action: " + action)
			return
	for pair in [["context_modifier",JOY_BUTTON_LEFT_SHOULDER],["next_weapon",JOY_BUTTON_RIGHT_SHOULDER],["identity_scroll",JOY_BUTTON_TOUCHPAD]]:
		if not _has_button(pair[0],pair[1]):
			_fail("wrong button: " + pair[0])
			return
	var trigger := InputEventJoypadMotion.new()
	trigger.axis = JOY_AXIS_TRIGGER_RIGHT
	trigger.axis_value = 1.0
	if not trigger.is_action_pressed("attack"):
		_fail("right trigger attack dispatch")
		return
	var feedback: Node = load("res://systems/controller_feedback.gd").new()
	root.add_child(feedback)
	feedback.pulse("shot")
	if feedback.usable_device() != -1 or feedback.capability_summary() != "No active controller connected":
		_fail("disconnected feedback fallback")
		return
	manager.options.input_device = "auto"
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_W
	manager._input(key)
	if manager.active_input_device != "keyboard_mouse":
		_fail("automatic keyboard handoff")
		return
	manager.set_option("input_device","keyboard_mouse")
	var saved := ConfigFile.new()
	if saved.load(manager.settings_path) != OK or saved.get_value("settings","input_device","") != "keyboard_mouse":
		_fail("settings persistence")
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(manager.settings_path))
	print("INPUT DEVICE SWITCH: PASS | keyboard and controller action routing, Auto handoff, setting saved")
	quit()

func _has_event(action: String, event_type: Variant) -> bool:
	for event in InputMap.action_get_events(action):
		if is_instance_of(event,event_type): return true
	return false

func _has_controller_event(action: String) -> bool:
	return _has_event(action,InputEventJoypadButton) or _has_event(action,InputEventJoypadMotion)

func _has_button(action: String, button: JoyButton) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index == button: return true
	return false

func _fail(reason: String) -> void:
	push_error("INPUT DEVICE SWITCH: FAIL | " + reason)
	quit(1)
