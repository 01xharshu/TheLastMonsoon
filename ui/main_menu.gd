extends Control
## Historical title screen with live controls over a clean riverside background plate.

const Style = preload("res://ui/menu_style.gd")
const SettingsPanel = preload("res://ui/settings_panel.gd")
const ARRIVAL = preload("res://assets/ui/backgrounds/monsoon_arrival.png")

var secondary_root: CenterContainer
var column: VBoxContainer
var content_root: Control
var main_panel: VBoxContainer
var page_shade: ColorRect
var continuation: Button
var play_button: Button
var page := "main"
var action_hint: Label
var footer: Label
var transition_cover: ColorRect
var transitioning := false
var background: TextureRect
var menu_time := 0.0
var focus_tweens: Dictionary = {}
const ACTION_HINTS := {
	"Play Game": "Begin Arjun’s journey in India, 1857.",
	"Continue": "Return to your most recent saved journey.",
	"Load Game": "Choose a saved journey to resume.",
	"Settings": "Adjust display, sound and controls.",
	"Quit": "Leave The Last Monsoon.",
}

# ── Lifecycle ────────────────────────────────────────────────
func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Style.make_theme()

	background = TextureRect.new()
	background.texture = ARRIVAL
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	# A soft local scrim keeps the menu legible without obscuring the river.
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.008, 0.014, 0.012, 0.82))
	gradient.set_color(1, Color(0.008, 0.014, 0.012, 0.0))
	var scrim_texture := GradientTexture2D.new()
	scrim_texture.gradient = gradient
	scrim_texture.fill_from = Vector2.ZERO
	scrim_texture.fill_to = Vector2(0.65, 0)
	var scrim := TextureRect.new()
	scrim.texture = scrim_texture
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)

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
	secondary_root = centre
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_root.add_child(centre)

	column = VBoxContainer.new()
	column.custom_minimum_size.x = 480
	column.add_theme_constant_override("separation", 10)
	centre.add_child(column)

	resized.connect(_layout_main_panel)
	_layout_main_panel()
	show_main()
	_build_footer()
	transition_cover = ColorRect.new()
	transition_cover.color = Color(0.008, 0.012, 0.012, 1.0)
	transition_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transition_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(transition_cover)
	var entrance := create_tween()
	entrance.tween_property(transition_cover, "modulate:a", 0.0, 0.65)

func _build_footer() -> void:
	footer = Label.new()
	footer.text = "PRE-ALPHA  ·  THE LAST MONSOON"
	footer.add_theme_font_size_override("font_size", 14)
	footer.add_theme_color_override("font_color", Color(0.78, 0.73, 0.62, 0.8))
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_root.add_child(footer)
	action_hint = Label.new()
	action_hint.add_theme_font_size_override("font_size", 19)
	action_hint.add_theme_color_override("font_color", Style.IVORY)
	action_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_root.add_child(action_hint)
	_layout_main_panel()
	_update_hint("Play Game")

func _process(delta: float) -> void:
	menu_time += delta
	# A slow camera-like push keeps the artwork alive without moving the controls.
	background.pivot_offset = size * 0.5
	background.scale = Vector2.ONE * (1.015 + sin(menu_time * 0.12) * 0.006)

func _update_hint(action: String) -> void:
	if is_instance_valid(action_hint):
		action_hint.text = ACTION_HINTS.get(action, "")

func _begin_journey(slot: int) -> void:
	if transitioning: return
	transitioning = true
	var loading := preload("res://ui/journey_loading.gd").new()
	get_tree().root.add_child(loading)
	var succeeded: bool = await loading.begin(slot)
	if not succeeded and is_inside_tree():
		transitioning = false
		if slot > 0:
			show_slots()
			var message := Style.label("Unable to open the journey. Please try again.", 18)
			column.add_child(message)
			column.move_child(message, 1)
		else:
			show_main()
			action_hint.text = "Unable to open the journey. Please try again."

func _request_new_game() -> void:
	if SaveManager.newest_slot() == 0:
		_begin_journey(0)
		return
	page = "new_game"
	_layout_main_panel()
	main_panel.hide()
	page_shade.show()
	column.show()
	clear_content()
	column.add_child(Style.heading("A New Journey", 36))
	column.add_child(Style.label("Your saved journeys will remain available.", 20))
	column.add_child(Style.button("Begin New Journey", _begin_journey.bind(0)))
	var back := Style.button("Back", show_main)
	column.add_child(back)
	_focus_when_ready.call_deferred(back)

func _build_main_panel() -> void:
	main_panel = VBoxContainer.new()
	main_panel.add_theme_constant_override("separation", 4)
	content_root.add_child(main_panel)

	var title := Label.new()
	title.text = "THE LAST\nMONSOON"
	title.add_theme_font_override("font", Style.MENU_BOLD)
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Style.IVORY)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	title.add_theme_constant_override("shadow_offset_y", 3)
	main_panel.add_child(title)

	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(340, 1)
	rule.color = Color(Style.GOLD.r, Style.GOLD.g, Style.GOLD.b, 0.7)
	main_panel.add_child(rule)

	var subtitle := Label.new()
	subtitle.text = "India  ·  1857"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	subtitle.add_theme_font_size_override("font_size", 23)
	subtitle.add_theme_color_override("font_color", Style.GOLD)
	main_panel.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 26
	main_panel.add_child(spacer)

	play_button = _title_action("Play Game", _request_new_game)
	main_panel.add_child(play_button)
	continuation = _title_action("Continue", func(): _begin_journey(SaveManager.newest_slot()))
	main_panel.add_child(continuation)
	main_panel.add_child(_title_action("Load Game", func(): show_slots()))
	main_panel.add_child(_title_action("Settings", func(): show_settings()))
	main_panel.add_child(_title_action("Quit", func(): SaveManager.quit_game()))
	_focus_when_ready.call_deferred(play_button)

func _title_action(value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(340, 50)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.add_theme_color_override("font_disabled_color", Color(0.55, 0.53, 0.47, 0.7))
	button.add_theme_font_override("font", Style.SERIF)
	button.add_theme_font_size_override("font_size", 27)
	button.add_theme_color_override("font_color", Style.IVORY)
	button.add_theme_color_override("font_hover_color", Style.GOLD)
	button.add_theme_color_override("font_focus_color", Style.GOLD)
	button.add_theme_color_override("font_pressed_color", Style.GOLD)
	var plain := StyleBoxEmpty.new()
	plain.content_margin_left = 18
	plain.content_margin_right = 18
	button.add_theme_stylebox_override("normal", plain)
	button.add_theme_stylebox_override("hover", plain)
	button.add_theme_stylebox_override("pressed", plain)
	button.add_theme_stylebox_override("disabled", plain)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(Style.GOLD.r, Style.GOLD.g, Style.GOLD.b, 0.10)
	focus.content_margin_left = 18
	focus.content_margin_right = 18
	focus.border_color = Style.GOLD
	focus.border_width_left = 3
	focus.border_width_bottom = 0
	button.add_theme_stylebox_override("focus", focus)
	button.focus_entered.connect(func():
		_update_hint(value)
		_animate_action(button, true)
	)
	button.focus_exited.connect(_animate_action.bind(button, false))
	button.mouse_entered.connect(func():
		if not button.disabled:
			button.grab_focus()
	)
	button.pressed.connect(func():
		if transitioning: return
		Style.play_ui_sound(button, Style.UI_BACK if value == "Quit" else Style.UI_CLICK)
		action.call()
	)
	return button

func _animate_action(button: Button, active: bool) -> void:
	if focus_tweens.has(button) and focus_tweens[button].is_valid():
		focus_tweens[button].kill()
	var motion := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion.tween_property(button, "scale", Vector2.ONE * (1.025 if active else 1.0), 0.16)
	focus_tweens[button] = motion

func _layout_main_panel() -> void:
	if not is_instance_valid(main_panel): return
	var scale_factor := minf(size.x / 1600.0, size.y / 900.0)
	main_panel.scale = Vector2.ONE * scale_factor
	main_panel.position = Vector2(size.x * 0.075, (size.y - 540.0 * scale_factor) * 0.5)
	main_panel.custom_minimum_size.x = 400
	if is_instance_valid(footer):
		footer.position = Vector2(size.x * 0.075, size.y - 36)
	if is_instance_valid(action_hint):
		action_hint.position = Vector2(size.x * 0.075, size.y - 76)
		action_hint.visible = page == "main"
		if size.x < 700: action_hint.add_theme_font_size_override("font_size", 14)
		else: action_hint.add_theme_font_size_override("font_size", 19)
	if is_instance_valid(secondary_root):
		secondary_root.pivot_offset = size * 0.5
		secondary_root.scale = Vector2.ONE * minf(1.0, minf(size.x / 600.0, size.y / 780.0))

# ── Pages ────────────────────────────────────────────────────
func clear_content() -> void:
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()

func show_main() -> void:
	page = "main"
	_layout_main_panel()
	clear_content()
	column.hide()
	page_shade.hide()
	main_panel.show()
	continuation.disabled = SaveManager.newest_slot() == 0
	_focus_when_ready.call_deferred(play_button)

func show_slots() -> void:
	page = "slots"
	_layout_main_panel()
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
			func(): _begin_journey(selected)
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
	_layout_main_panel()
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
	if transitioning: return
	if page != "main" and (event.is_action_pressed("ui_cancel") or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B and event.pressed)):
		var settings:=column.find_child("SettingsPanel",true,false)
		if page!="settings" or settings==null or not settings.handle_back():show_main()
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
