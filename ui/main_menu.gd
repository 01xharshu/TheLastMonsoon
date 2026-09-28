extends Control
## Historical title screen with live controls over a clean riverside background plate.

const Style = preload("res://ui/menu_style.gd")
const SettingsPanel = preload("res://ui/settings_panel.gd")
const ARRIVAL = preload("res://assets/ui/backgrounds/monsoon_arrival.png")

var column: VBoxContainer
var content_root: Control
var main_panel: VBoxContainer
var page_shade: ColorRect
var continuation: Button
var play_button: Button
var page := "main"

# ── Lifecycle ────────────────────────────────────────────────
func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Style.make_theme()

	var background := TextureRect.new()
	background.texture = ARRIVAL
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	page_shade = ColorRect.new()
	page_shade.color = Color(0.012, 0.017, 0.016, 0.78)
	page_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page_shade.hide()
	add_child(page_shade)

	# Foreground container
	content_root = Control.new()
	content_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content_root)

	_build_main_panel()

	# Centre column
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_root.add_child(centre)

	column = VBoxContainer.new()
	column.custom_minimum_size.x = 480
	column.add_theme_constant_override("separation", 10)
	centre.add_child(column)

	resized.connect(_layout_main_panel)
	_layout_main_panel()
	show_main()

func _build_main_panel() -> void:
	main_panel = VBoxContainer.new()
	main_panel.add_theme_constant_override("separation", 4)
	content_root.add_child(main_panel)

	var title := Label.new()
	title.text = "THE LAST MONSOON"
	title.add_theme_font_override("font", Style.MENU_BOLD)
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Style.IVORY)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("shadow_offset_y", 3)
	main_panel.add_child(title)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(570, 1)
	rule.color = Color(Style.GOLD.r, Style.GOLD.g, Style.GOLD.b, 0.7)
	main_panel.add_child(rule)

	var subtitle := Label.new()
	subtitle.text = "India  ·  1857"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 23)
	subtitle.add_theme_color_override("font_color", Style.GOLD)
	main_panel.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 33
	main_panel.add_child(spacer)

	play_button = _title_action("Play Game", func(): SaveManager.start_new_game())
	main_panel.add_child(play_button)
	continuation = _title_action("Continue", func(): SaveManager.start_loaded_game(SaveManager.newest_slot()))
	main_panel.add_child(continuation)
	main_panel.add_child(_title_action("Load Game", func(): show_slots()))
	main_panel.add_child(_title_action("Settings", func(): show_settings()))
	main_panel.add_child(_title_action("Quit", func(): get_tree().quit()))
	_focus_when_ready.call_deferred(play_button)

func _title_action(value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(340, 54)
	button.add_theme_font_override("font", Style.SERIF)
	button.add_theme_font_size_override("font_size", 27)
	button.add_theme_color_override("font_color", Style.IVORY)
	button.add_theme_color_override("font_hover_color", Style.GOLD)
	button.add_theme_color_override("font_focus_color", Style.GOLD)
	button.add_theme_color_override("font_pressed_color", Style.GOLD)
	var plain := StyleBoxEmpty.new()
	plain.content_margin_left = 14
	button.add_theme_stylebox_override("normal", plain)
	button.add_theme_stylebox_override("hover", plain)
	button.add_theme_stylebox_override("pressed", plain)
	button.add_theme_stylebox_override("disabled", plain)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Style.GOLD
	focus.border_width_left = 3
	focus.border_width_bottom = 1
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(func():
		Style.play_ui_sound(button, Style.UI_BACK if value == "Quit" else Style.UI_CLICK)
		action.call()
	)
	return button

func _layout_main_panel() -> void:
	if not is_instance_valid(main_panel): return
	var scale_factor := minf(size.x / 1600.0, size.y / 900.0)
	main_panel.scale = Vector2.ONE * scale_factor
	main_panel.position = Vector2(size.x * 0.075, size.y * 0.17)
	main_panel.custom_minimum_size.x = 580

# ── Pages ────────────────────────────────────────────────────
func clear_content() -> void:
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()

func show_main() -> void:
	page = "main"
	clear_content()
	column.hide()
	page_shade.hide()
	main_panel.show()
	continuation.disabled = SaveManager.newest_slot() == 0
	_focus_when_ready.call_deferred(play_button)

func show_slots() -> void:
	page = "slots"
	main_panel.hide()
	page_shade.show()
	column.show()
	clear_content()
	column.add_child(Style.heading("Load Game", 42))

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	column.add_child(spacer)

	var first: Button
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		var selected := slot
		var btn := Style.button(
			SaveManager.slot_label(selected),
			func(): SaveManager.start_loaded_game(selected)
		)
		btn.disabled = SaveManager.read_slot(selected).is_empty()
		column.add_child(btn)
		if first == null and not btn.disabled:
			first = btn

	var spacer2 := Control.new()
	spacer2.custom_minimum_size.y = 4
	column.add_child(spacer2)

	var back := Style.button("Back", func(): show_main())
	column.add_child(back)
	_focus_when_ready.call_deferred(first if first else back)

	Style.stagger_children(column, 0.06)

func show_settings() -> void:
	page = "settings"
	main_panel.hide()
	page_shade.show()
	column.show()
	clear_content()
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(500, minf(600.0, get_viewport_rect().size.y - 120.0))
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var settings := SettingsPanel.new()
	settings.back_requested.connect(show_main)
	scroll.add_child(settings)
	column.add_child(scroll)
	settings.focus_first_control.call_deferred()

# ── Input ────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if page != "main" and event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B and event.pressed:
		show_main()
		get_viewport().set_input_as_handled()

# ── Helpers ──────────────────────────────────────────────────
func _focus_when_ready(btn: Button) -> void:
	if is_instance_valid(btn) and btn.is_inside_tree() and btn.is_visible_in_tree():
		btn.grab_focus()

func _add_watermark() -> void:
	var wm := Label.new()
	wm.text = "PRE-ALPHA  ·  BUILD 2026"
	wm.add_theme_font_size_override("font_size", 13)
	wm.add_theme_color_override("font_color", Color(Style.GOLD.r, Style.GOLD.g, Style.GOLD.b, 0.30))
	wm.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	wm.offset_left = 28
	wm.offset_bottom = -18
	wm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_root.add_child(wm)
	Style.fade_in(wm, 1.2, 1.5)
