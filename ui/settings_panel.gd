extends VBoxContainer
## Shared category submenus for title and pause settings.

signal back_requested
const Style = preload("res://ui/menu_style.gd")
var device_callbacks: Array[Callable] = []
var waiting_action := ""
var waiting_button: Button
var input_selector: OptionButton

var category := ""
const CATEGORIES := ["Audio", "Camera", "Controller", "Display", "Graphics", "Keyboard controls"]

func _ready() -> void:
	name="SettingsPanel"
	add_theme_constant_override("separation", 7)
	show_category("")

func show_category(title: String) -> void:
	_disconnect_device_callbacks()
	waiting_action="";waiting_button=null;input_selector=null
	for child in get_children():remove_child(child);child.queue_free()
	category=title
	add_child(Style.heading("Settings" if title=="" else title,32))
	if title=="":
		for item in CATEGORIES:add_child(Style.button(item,show_category.bind(item)))
	elif title=="Audio":
		add_slider("Master volume","master",0,1,.01)
		add_slider("Music volume","music",0,1,.01)
		add_slider("Ambient volume","ambient",0,1,.01)
	elif title=="Camera":
		add_slider("Mouse sensitivity","mouse",.3,2,.05)
		add_slider("Camera distance","camera_distance",1.25,4,.05," m")
		add_slider("Aim camera distance","aim_camera_distance",.5,2,.05," m")
		add_slider("Camera angle","camera_angle",-10,10,1,"°")
		add_slider("Aim camera angle","aim_camera_angle",-10,10,1,"°")
	elif title=="Controller":
		add_input_device_selector()
		add_slider("Controller vibration","vibration",0,1,.05)
		add_toggle("Controller light","controller_light")
		add_toggle("Gyro aim (optional)","gyro_aim")
		add_gyro_calibration();add_controller_test()
	elif title=="Display":
		add_toggle("Fullscreen","fullscreen");add_toggle("VSync","vsync")
	elif title=="Graphics":
		var quality:=OptionButton.new()
		for item in ["Low · up to 540p / 40 m shadows","Medium · up to 720p / 80 m shadows","High · up to 1080p / 130 m shadows"]:quality.add_item(item)
		quality.selected=int(SaveManager.options.graphics_quality)
		quality.item_selected.connect(func(index: int):SaveManager.set_option("graphics_quality",index))
		add_child(quality)
	elif title=="Keyboard controls":
		add_child(Style.button("Movement",show_category.bind("Movement")))
		add_child(Style.button("Actions",show_category.bind("Actions")))
	elif title in ["Movement","Actions"]:
		var actions: Array=["move_forward","move_backward","move_left","move_right","jump","toggle_view"] if title=="Movement" else ["interact","toggle_inventory","reload","stow_weapon","identity_scroll"]
		for action in actions:
			if not InputMap.has_action(action):continue
			var button:=Style.button(binding_label(action),begin_binding.bind(action))
			button.set_meta("action",action);add_child(button)
	add_child(Style.divider(240))
	add_child(Style.button("Back",_back))
	var scroll:=get_parent() as ScrollContainer
	if scroll!=null:scroll.scroll_vertical=0
	focus_first_control.call_deferred()

func _back() -> void:
	if not handle_back():back_requested.emit()

func handle_back() -> bool:
	if waiting_action!="":
		if is_instance_valid(waiting_button):waiting_button.text=binding_label(waiting_action)
		waiting_action="";return true
	if category=="":return false
	show_category("Keyboard controls" if category in ["Movement","Actions"] else "")
	return true

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
	for child in find_children("*","Control",true,false):
		if child.focus_mode==Control.FOCUS_ALL and child.is_visible_in_tree():
			child.grab_focus();return

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
	var button := Style.button("Test controller vibration", func(): ControllerFeedback.pulse("shot"))
	button.disabled = ControllerFeedback.usable_device() < 0
	button.tooltip_text=ControllerFeedback.capability_summary()
	add_child(button)
	_connect_input_changed(func(_device: String):
		if is_instance_valid(button):
			button.tooltip_text=ControllerFeedback.capability_summary()
			button.disabled = ControllerFeedback.usable_device() < 0
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
	slider.name=key+"_slider"
	slider.set_meta("setting",key)
	slider.custom_minimum_size.x = 180
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = float(SaveManager.options[key])
	row.add_child(slider)

	var amount := Style.label("%.2f%s" % [slider.value, unit] if unit == " m" else "%.0f°" % slider.value if unit == "°" else "%.0f%%" % (slider.value * 100.0), 16)
	amount.custom_minimum_size.x = 58
	amount.add_theme_color_override("font_color", Style.GOLD)
	row.add_child(amount)

	slider.value_changed.connect(func(value: float):
		SaveManager.set_option(key, value)
		amount.text = "%.2f%s" % [value, unit] if unit == " m" else "%.0f°" % value if unit == "°" else "%.0f%%" % (value * 100.0)
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

func _disconnect_device_callbacks() -> void:
	for callback in device_callbacks:
		if SaveManager.input_device_changed.is_connected(callback):
			SaveManager.input_device_changed.disconnect(callback)

	device_callbacks.clear()

func _exit_tree() -> void:
	_disconnect_device_callbacks()
