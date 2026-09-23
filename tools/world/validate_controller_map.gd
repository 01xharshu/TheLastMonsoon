extends SceneTree
## Controller action contract without a physical DualSense. Hardware review remains separate.

func _initialize() -> void:
	var mapped := {
		"move_forward": [JOY_AXIS_LEFT_Y,-1.0],
		"move_backward": [JOY_AXIS_LEFT_Y,1.0],
		"move_left": [JOY_AXIS_LEFT_X,-1.0],
		"move_right": [JOY_AXIS_LEFT_X,1.0],
		"look_left": [JOY_AXIS_RIGHT_X,-1.0],
		"look_right": [JOY_AXIS_RIGHT_X,1.0],
		"look_up": [JOY_AXIS_RIGHT_Y,-1.0],
		"look_down": [JOY_AXIS_RIGHT_Y,1.0],
	}
	for action in mapped:
		var found := false
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadMotion and event.axis == mapped[action][0] and is_equal_approx(event.axis_value,mapped[action][1]):
				found = true
		if not found:
			push_error("CONTROLLER BLOCKED: missing stick mapping for " + action)
			quit(1)
			return
	var buttons := {"jump":JOY_BUTTON_A,"interact":JOY_BUTTON_X,"secondary_interact":JOY_BUTTON_Y,"sprint":JOY_BUTTON_LEFT_STICK,"pause":JOY_BUTTON_START,"toggle_inventory":JOY_BUTTON_BACK,"toggle_view":JOY_BUTTON_RIGHT_STICK}
	for action in buttons:
		var found := false
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton and event.button_index == buttons[action]:
				found = true
		if not found:
			push_error("CONTROLLER BLOCKED: missing button mapping for " + action)
			quit(1)
			return
	print("CONTROLLER MAP: PASS | both sticks, Cross jump, Square interact, Triangle mount, L3 sprint/gallop, Options pause, Create inventory, R3 view")
	quit()
