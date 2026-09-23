extends VBoxContainer
signal back_requested
const Style = preload("res://ui/menu_style.gd")

func _ready() -> void:
	add_theme_constant_override("separation",13)
	add_child(Style.label("SETTINGS",38))
	add_slider("Master volume","master",0.0,1.0,0.01)
	add_slider("Music volume","music",0.0,1.0,0.01)
	add_slider("Mouse sensitivity","mouse",0.3,2.0,0.05)
	add_toggle("Fullscreen","fullscreen")
	add_toggle("VSync","vsync")
	add_child(Style.button("Back",func(): back_requested.emit()))

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
