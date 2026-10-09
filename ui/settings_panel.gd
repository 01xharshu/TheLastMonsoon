extends VBoxContainer
## Settings panel — redesigned with AAA styling, section headers,
## gold accent sliders, and consistent spacing.

signal back_requested
const Style = preload("res://ui/menu_style.gd")
var device_callbacks: Array[Callable] = []
var waiting_action := ""
var waiting_button: Button
var input_selector: OptionButton

func _ready() -> void:
	add_theme_constant_override("separation", 11)

	# ── Audio ────────────────────────────────────────────────
	add_child(Style.heading("Settings", 38))
	_section("Audio")
	add_slider("Master volume", "master", 0.0, 1.0, 0.01)
	add_slider("Music volume", "music", 0.0, 1.0, 0.01)

	# ── Camera ───────────────────────────────────────────────
	_section("Camera")
	add_slider("Mouse sensitivity", "mouse", 0.3, 2.0, 0.05)
	add_slider("Camera distance", "camera_distance", 1.25, 4.0, 0.05, " m")
	add_slider("Aim camera distance", "aim_camera_distance", 0.5, 2.0, 0.05, " m")
	add_slider("Camera angle", "camera_angle", -10.0, 10.0, 1.0, "°")
	add_slider("Aim camera angle", "aim_camera_angle", -10.0, 10.0, 1.0, "°")

	# ── Controller ───────────────────────────────────────────
	_section("Controller")
	add_input_device_selector()
	add_slider("Controller vibration", "vibration", 0.0, 1.0, 0.05)
	add_toggle("Controller light", "controller_light")
	add_toggle("Gyro aim (optional)", "gyro_aim")
	add_gyro_calibration()
	add_controller_test()

	# ── Display ──────────────────────────────────────────────
	_section("Display")
	add_toggle("Fullscreen", "fullscreen")
	add_toggle("VSync", "vsync")
	_section("Graphics")
	var quality := OptionButton.new()
	for title in ["Low · up to 540p / 40 m shadows", "Medium · up to 720p / 80 m shadows", "High · up to 1080p / 130 m shadows"]: quality.add_item(title)
	quality.selected = int(SaveManager.options.graphics_quality)
	quality.item_selected.connect(func(index: int): SaveManager.set_option("graphics_quality",index))
	add_child(quality)
	_section("Keyboard controls")
	for action in ["move_forward","move_backward","move_left","move_right","jump","interact","toggle_inventory","toggle_view","reload","stow_weapon","identity_scroll"]:
		if not InputMap.has_action(action): continue
		var button := Style.button(binding_label(action),begin_binding.bind(action))
		button.set_meta("action",action)
		add_child(button)


	# ── Back ─────────────────────────────────────────────────
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 10
	add_child(spacer)
	add_child(Style.divider(240.0))
	var spacer2 := Control.new()
	spacer2.custom_minimum_size.y = 6
	add_child(spacer2)
	add_child(Style.button("Back", func(): back_requested.emit()))

# ── Section header ───────────────────────────────────────────
func _section(title: String) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 6
	add_child(spacer)
	var lbl := Style.subtitle(title.to_upper(), 15)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl.add_theme_color_override("font_color", Style.GOLD)
	add_child(lbl)
	add_child(Style.divider(460.0))

# ── Input device selector ────────────────────────────────────
func add_input_device_selector() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var caption := Style.label("Input device", 19)
	caption.custom_minimum_size.x = 200
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(caption)
	var selector := OptionButton.new()
	input_selector = selector
	selector.add_item("Auto", 0)
	selector.add_item("Keyboard + Mouse", 1)
	selector.add_item("PS5 DualSense", 2)
	selector.selected = ["auto", "keyboard_mouse", "controller"].find(str(SaveManager.options.input_device))
	selector.item_selected.connect(func(index: int): SaveManager.set_option("input_device", ["auto", "keyboard_mouse", "controller"][index]))
	row.add_child(selector)
	add_child(row)
	var status := Style.label("Active: " + ("PS5 DualSense" if SaveManager.active_input_device == "controller" else "Keyboard + Mouse"), 15)
	status.add_theme_color_override("font_color", Color(Style.IVORY.r, Style.IVORY.g, Style.IVORY.b, 0.55))
	_connect_input_changed(func(device: String):
		if is_instance_valid(status): status.text = "Active: " + ("PS5 DualSense" if device == "controller" else "Keyboard + Mouse")
	)
	add_child(status)

func focus_first_control() -> void:
	if is_instance_valid(input_selector) and input_selector.is_inside_tree() and input_selector.is_visible_in_tree(): input_selector.grab_focus()

# ── Gyro calibration ─────────────────────────────────────────
func add_gyro_calibration() -> void:
	var button := Style.button("Calibrate gyro · set controller flat", func(): pass)
	button.pressed.connect(func(): _calibrate_gyro(button))
	button.disabled = not ControllerFeedback.can_calibrate_gyro()
	_connect_input_changed(func(_device: String):
		if is_instance_valid(button): button.disabled = not ControllerFeedback.can_calibrate_gyro()
	)
	add_child(button)

func _calibrate_gyro(button: Button) -> void:
	button.disabled = true
	button.text = "CALIBRATING · KEEP CONTROLLER FLAT"
	var success: bool = await ControllerFeedback.calibrate_gyro()
	if not is_instance_valid(button): return
	button.text = "GYRO CALIBRATED" if success else "CALIBRATION UNAVAILABLE · RETRY"
	button.disabled = not ControllerFeedback.can_calibrate_gyro()

# ── Controller test ──────────────────────────────────────────
func add_controller_test() -> void:
	var status := Style.label(ControllerFeedback.capability_summary(), 15)
	status.add_theme_color_override("font_color", Color(Style.IVORY.r, Style.IVORY.g, Style.IVORY.b, 0.55))
	add_child(status)
	var button := Style.button("Test controller vibration", func(): ControllerFeedback.pulse("shot"))
	button.disabled = ControllerFeedback.usable_device() < 0
	add_child(button)
	_connect_input_changed(func(_device: String):
		if is_instance_valid(status): status.text = ControllerFeedback.capability_summary()
		if is_instance_valid(button): button.disabled = ControllerFeedback.usable_device() < 0
	)

# ── Slider widget ────────────────────────────────────────────
func add_slider(title: String, key: String, minimum: float, maximum: float, step: float, unit: String = "%") -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var caption := Style.label(title, 18)
	caption.custom_minimum_size.x = 200
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(caption)

	var slider := HSlider.new()
	slider.custom_minimum_size.x = 180
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = float(SaveManager.options[key])
	row.add_child(slider)

	var amount := Style.label("%.2f%s" % [slider.value, unit] if unit == " m" else "%.0f%%" % (slider.value * 100.0), 16)
	amount.custom_minimum_size.x = 58
	amount.add_theme_color_override("font_color", Style.GOLD)
	row.add_child(amount)

	slider.value_changed.connect(func(value: float):
		SaveManager.set_option(key, value)
		amount.text = "%.2f%s" % [value, unit] if unit == " m" else "%.0f%%" % (value * 100.0)
	)
	add_child(row)

# ── Toggle widget ────────────────────────────────────────────
func add_toggle(title: String, key: String) -> void:
	var toggle := CheckButton.new()
	toggle.text = title
	toggle.button_pressed = bool(SaveManager.options[key])
	toggle.toggled.connect(func(value: bool): SaveManager.set_option(key, value))
	add_child(toggle)

func binding_label(action: String) -> String:
	var key := "—"
	for event in SaveManager._original_input_events.get(action,[]):
		if event is InputEventKey: key = OS.get_keycode_string(event.physical_keycode)
	return action.replace("_"," ").capitalize() + " · " + key

func begin_binding(action: String) -> void:
	waiting_action = action
	for child in get_children():
		if child.get_meta("action","") == action:
			waiting_button = child
			waiting_button.text = "Press a key · Esc cancels"

func _input(event: InputEvent) -> void:
	if waiting_action == "" or not is_visible_in_tree(): return
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode == KEY_ESCAPE:
		waiting_button.text = binding_label(waiting_action)
		waiting_action = ""
	elif SaveManager.bind_key(waiting_action,event.physical_keycode):
		waiting_button.text = binding_label(waiting_action)
		waiting_action = ""
	else:
		waiting_button.text = "Key already used · choose another"
	get_viewport().set_input_as_handled()

func _connect_input_changed(callback: Callable) -> void:
	device_callbacks.append(callback)
	SaveManager.input_device_changed.connect(callback)

func _exit_tree() -> void:
	for callback in device_callbacks:
		if SaveManager.input_device_changed.is_connected(callback):
			SaveManager.input_device_changed.disconnect(callback)
