extends VBoxContainer
signal back_requested
const Style = preload("res://ui/menu_style.gd")
var input_selector: OptionButton

func _ready() -> void:
	add_theme_constant_override("separation",13)
	add_child(Style.label("SETTINGS",38))
	add_slider("Master volume","master",0.0,1.0,0.01)
	add_slider("Music volume","music",0.0,1.0,0.01)
	add_slider("Mouse sensitivity","mouse",0.3,2.0,0.05)
	add_input_device_selector()
	add_slider("Controller vibration","vibration",0.0,1.0,0.05)
	add_toggle("Controller light","controller_light")
	add_toggle("Gyro aim (optional)","gyro_aim")
	add_gyro_calibration()
	add_controller_test()
	add_toggle("Fullscreen","fullscreen")
	add_toggle("VSync","vsync")
	add_child(Style.button("Back",func(): back_requested.emit()))

func add_input_device_selector() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	var caption := Style.label("Input device",19)
	caption.custom_minimum_size.x = 190
	row.add_child(caption)
	var selector := OptionButton.new()
	input_selector = selector
	selector.add_item("Auto",0)
	selector.add_item("Keyboard + Mouse",1)
	selector.add_item("PS5 DualSense",2)
	selector.selected = ["auto","keyboard_mouse","controller"].find(str(SaveManager.options.input_device))
	selector.item_selected.connect(func(index: int): SaveManager.set_option("input_device",["auto","keyboard_mouse","controller"][index]))
	row.add_child(selector)
	add_child(row)
	var status := Style.label("Active: " + ("PS5 DualSense" if SaveManager.active_input_device == "controller" else "Keyboard + Mouse"),16)
	SaveManager.input_device_changed.connect(func(device: String):
		if is_instance_valid(status): status.text = "Active: " + ("PS5 DualSense" if device == "controller" else "Keyboard + Mouse")
	)
	add_child(status)

func focus_first_control() -> void:
	if is_instance_valid(input_selector) and input_selector.is_inside_tree() and input_selector.is_visible_in_tree(): input_selector.grab_focus()

func add_gyro_calibration() -> void:
	var button := Style.button("Calibrate gyro · set controller flat",func(): pass)
	button.pressed.connect(func(): _calibrate_gyro(button))
	button.disabled = not ControllerFeedback.can_calibrate_gyro()
	SaveManager.input_device_changed.connect(func(_device: String):
		if is_instance_valid(button): button.disabled = not ControllerFeedback.can_calibrate_gyro()
	)
	add_child(button)

func _calibrate_gyro(button: Button) -> void:
	button.disabled = true
	button.text = "Calibrating · keep controller flat"
	var success: bool = await ControllerFeedback.calibrate_gyro()
	if not is_instance_valid(button): return
	button.text = "Gyro calibrated" if success else "Calibration unavailable · retry"
	button.disabled = not ControllerFeedback.can_calibrate_gyro()

func add_controller_test() -> void:
	var status := Style.label(ControllerFeedback.capability_summary(),16)
	add_child(status)
	var button := Style.button("Test controller vibration",func(): ControllerFeedback.pulse("shot"))
	button.disabled = ControllerFeedback.usable_device() < 0
	add_child(button)
	SaveManager.input_device_changed.connect(func(_device: String):
		if is_instance_valid(status): status.text = ControllerFeedback.capability_summary()
		if is_instance_valid(button): button.disabled = ControllerFeedback.usable_device() < 0
	)

func add_slider(title: String, key: String, minimum: float, maximum: float, step: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	var caption := Style.label(title,19)
	caption.custom_minimum_size.x = 190
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(caption)
	var slider := HSlider.new()
	slider.custom_minimum_size.x = 170
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = float(SaveManager.options[key])
	row.add_child(slider)
	var amount := Style.label("%.0f%%" % (slider.value*100.0),17)
	amount.custom_minimum_size.x = 55
	row.add_child(amount)
	slider.value_changed.connect(func(value: float):
		SaveManager.set_option(key,value)
		amount.text = "%.0f%%" % (value*100.0)
	)
	add_child(row)

func add_toggle(title: String, key: String) -> void:
	var toggle := CheckButton.new()
	toggle.text = title
	toggle.button_pressed = bool(SaveManager.options[key])
	toggle.toggled.connect(func(value: bool): SaveManager.set_option(key,value))
	add_child(toggle)
