extends Control
## Shared Android/iOS input overlay. --touch-controls enables desktop preview.
const MOVE := ["move_left", "move_right", "move_forward", "move_backward"]
const BUTTONS := [
	["Jump", "jump"], ["Use", "interact"], ["Ride", "secondary_interact"],
	["Run", "sprint"], ["Aim", "aim"], ["Attack", "attack"],
	["Reload", "reload"], ["Crouch", "take_cover"], ["Prone", "toggle_prone"],
	["Weapon", "next_weapon"], ["Stow", "stow_weapon"], ["Water", "drink_water"]]
const MENUS := [["Bag", "toggle_inventory"], ["Map", "open_map"], ["Pause", "pause"]]
var actor: Node
var fingers: Dictionary = {}
var held: Dictionary = {}
var joystick := Vector2.ZERO
var stick_center := Vector2.ZERO
var radius := 60.0
var button_rects: Array[Rect2] = []
var menu_rects: Array[Rect2] = []
var enabled := false

func _ready() -> void:
	actor = get_parent().get_parent()
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	enabled = OS.has_feature("android") or OS.has_feature("ios") or "--touch-controls" in OS.get_cmdline_user_args()
	if "--touch-controls" in OS.get_cmdline_user_args():
		Input.emulate_touch_from_mouse = true
	visible = enabled
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	release_all()
	# Conservative inset, augmented by native screen safe area for notches.
	var inset := Vector2(28, 28)
	if DisplayServer.get_name() != "headless":
		var safe := DisplayServer.get_display_safe_area()
		var screen := DisplayServer.screen_get_size()
		if screen.x > 0 and screen.y > 0:
			inset.x = maxf(inset.x, maxf(safe.position.x, screen.x - safe.end.x) * size.x / screen.x)
			inset.y = maxf(inset.y, maxf(safe.position.y, screen.y - safe.end.y) * size.y / screen.y)
	radius = clampf(size.y * 0.09, 40, 72)
	stick_center = Vector2(inset.x + radius * 1.5, size.y - inset.y - radius * 1.5)
	var cell := Vector2(clampf(size.x * 0.065, 58, 88), clampf(size.y * 0.085, 42, 64))
	button_rects.clear()
	for i in BUTTONS.size():
		button_rects.append(Rect2(Vector2(size.x - inset.x - (3 - i % 3) * (cell.x + 8), size.y - inset.y - (4 - i / 3) * (cell.y + 8)), cell))
	menu_rects.clear()
	for i in MENUS.size():
		menu_rects.append(Rect2(Vector2(size.x - inset.x - (3 - i) * (cell.x + 8), inset.y), cell))
	queue_redraw()

func gameplay_active() -> bool:
	if get_tree().paused or not actor.is_physics_processing(): return false
	if actor.inventory_ui.is_open(): return false
	for key in ["map_open", "weapon_wheel_open", "scroll_open", "telescope_open", "document_busy"]:
		if actor.get_meta(key, false): return false
	for key in ["rest_action", "detention_action", "river_action"]:
		if actor.get_meta(key, "") != "": return false
	return true

func _process(_delta: float) -> void:
	if not enabled: return
	if not gameplay_active() and not held.is_empty(): release_all()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not enabled: return
	if event is InputEventScreenTouch:
		if not event.pressed or event.canceled:
			_end_finger(event.index)
			return
		for i in menu_rects.size():
			if menu_rects[i].has_point(event.position):
				release_all()
				if MENUS[i][1] == "pause" and actor.get_parent().has_node("GameMenu"):
					actor.get_parent().get_node("GameMenu").toggle()
				else:
					pulse(MENUS[i][1])
				get_viewport().set_input_as_handled()
				return
		if not gameplay_active(): return
		for i in button_rects.size():
			if button_rects[i].has_point(event.position):
				fingers[event.index] = BUTTONS[i][1]
				set_action(BUTTONS[i][1], 1.0)
				get_viewport().set_input_as_handled()
				return
		if event.position.distance_to(stick_center) < radius * 1.6 and not fingers.values().has("move"):
			fingers[event.index] = "move"
			move_stick(event.position)
		elif event.position.x > size.x * 0.4 and not fingers.values().has("look"):
			fingers[event.index] = "look"
		else: return
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and fingers.has(event.index):
		if not gameplay_active():
			release_all()
			return
		if fingers[event.index] == "move": move_stick(event.position)
		elif fingers[event.index] == "look": look_drag(event.relative)
		get_viewport().set_input_as_handled()

func look_drag(relative: Vector2) -> void:
	actor.camera_pivot.rotate_y(-relative.x * actor.mouse_sensitivity)
	actor.camera_pitch = clampf(actor.camera_pitch - relative.y * actor.mouse_sensitivity, deg_to_rad(actor.min_camera_angle), deg_to_rad(actor.max_camera_angle))
	actor.camera_pivot.rotation.x = actor.camera_pitch

func move_stick(position: Vector2) -> void:
	joystick = ((position - stick_center) / radius).limit_length()
	if joystick.length() < 0.15: joystick = Vector2.ZERO
	for pair in [["move_left", -joystick.x], ["move_right", joystick.x], ["move_forward", -joystick.y], ["move_backward", joystick.y]]:
		set_action(pair[0], maxf(0, pair[1]))

func set_action(action: String, strength: float) -> void:
	if not InputMap.has_action(action): return
	var was_pressed: bool = held.has(action)
	if strength > 0:
		held[action] = strength
		Input.action_press(action, strength)
	else:
		held.erase(action)
		if not was_pressed: return
		Input.action_release(action)
	if was_pressed == (strength > 0): return
	var event := InputEventAction.new()
	event.action = action
	event.pressed = strength > 0
	event.strength = strength
	Input.parse_input_event.call_deferred(event)

func pulse(action: String) -> void:
	set_action(action, 1)
	# Keep the edge alive through a physics tick.
	get_tree().create_timer(0.08, true).timeout.connect(func(): set_action(action, 0))

func _end_finger(index: int) -> void:
	if not fingers.has(index): return
	var action: String = fingers[index]
	fingers.erase(index)
	if action == "move":
		joystick = Vector2.ZERO
		for movement in MOVE: set_action(movement, 0)
	elif action != "look" and not fingers.values().has(action): set_action(action, 0)

func release_all() -> void:
	for action in held.keys(): set_action(action, 0)
	fingers.clear()
	joystick = Vector2.ZERO

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		release_all()

func _exit_tree() -> void:
	release_all()

func _draw() -> void:
	if not enabled: return
	var font := ThemeDB.fallback_font
	if gameplay_active():
		draw_circle(stick_center, radius, Color(0.08, 0.10, 0.09, 0.55))
		draw_arc(stick_center, radius, 0, TAU, 48, Color(0.85, 0.77, 0.57, 0.8), 2)
		draw_circle(stick_center + joystick * radius, radius * 0.4, Color(0.85, 0.77, 0.57, 0.65))
		for i in BUTTONS.size(): _draw_button(button_rects[i], BUTTONS[i][0], held.has(BUTTONS[i][1]), font)
	for i in MENUS.size(): _draw_button(menu_rects[i], MENUS[i][0], false, font)

func _draw_button(rect: Rect2, label: String, pressed: bool, font: Font) -> void:
	draw_style_box(_button_style(pressed), rect)
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	draw_string(font, rect.get_center() + Vector2(-text_size.x * 0.5, 6), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.96, 0.91, 0.77))

func _button_style(pressed: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.42, 0.34, 0.20, 0.85) if pressed else Color(0.08, 0.10, 0.09, 0.68)
	style.border_color = Color(0.85, 0.77, 0.57, 0.7)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	return style
