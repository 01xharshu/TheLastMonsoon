extends Control
const Style = preload("res://ui/menu_style.gd")
const SettingsPanel = preload("res://ui/settings_panel.gd")
var column: VBoxContainer

func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Style.make_theme()
	var background := ColorRect.new()
	background.color = Color(0.035,0.046,0.038)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	column = VBoxContainer.new()
	column.custom_minimum_size.x = 440
	column.add_theme_constant_override("separation",13)
	centre.add_child(column)
	show_main()

func clear_content() -> void:
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()

func show_main() -> void:
	clear_content()
	column.add_child(Style.label("THE LAST MONSOON",52))
	column.add_child(Style.label("INDIA  ·  1857",19))
	column.add_child(Style.button("Play Game",func(): SaveManager.start_new_game()))
	var continuation := Style.button("Continue",func(): SaveManager.start_loaded_game(SaveManager.newest_slot()))
	continuation.disabled = SaveManager.newest_slot()==0
	column.add_child(continuation)
	column.add_child(Style.button("Load Game",func(): show_slots()))
	column.add_child(Style.button("Settings",func(): show_settings()))
	column.add_child(Style.button("Quit",func(): get_tree().quit()))

func show_slots() -> void:
	clear_content()
	column.add_child(Style.label("LOAD GAME",38))
	for slot in range(1,SaveManager.SLOT_COUNT+1):
		var selected := slot
		var button := Style.button(SaveManager.slot_label(selected),func(): SaveManager.start_loaded_game(selected))
		button.disabled = SaveManager.read_slot(selected).is_empty()
		column.add_child(button)
	column.add_child(Style.button("Back",func(): show_main()))

func show_settings() -> void:
	clear_content()
	var settings := SettingsPanel.new()
	settings.back_requested.connect(show_main)
	column.add_child(settings)
